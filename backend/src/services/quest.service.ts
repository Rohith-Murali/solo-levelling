import { AppError } from "../errors/app-error.js";
import { ProgressionEngine, type ProgressionState } from "../core/progression/index.js";
import { User } from "../models/user.model.js";
import type { CharacterRecord, QuestRecord, SkillRecord } from "../models/user.model.js";
import { characterVersionFilter } from "./character-version-filter.js";
import { activateTemplate, questTemplates } from "./quest-catalog.js";

function requireCharacter(user: { character?: CharacterRecord } | null): CharacterRecord {
  if (!user) throw new AppError(401, "INVALID_ACCESS_TOKEN", "Your session is invalid or expired.");
  if (!user.character) throw new AppError(409, "CHARACTER_REQUIRED", "Create a character before managing quests.");
  return user.character;
}

function hasTemplateQuests(character: CharacterRecord, templateId: string): boolean {
  return (character.quests ?? []).some((quest) => quest.sourceTemplateId === templateId);
}

function skillState(character: CharacterRecord): ProgressionState["skills"] {
  const records: SkillRecord[] = character.skills?.length ? character.skills : [{
    ...character.startingSkill, description: "Starting skill", category: "STARTING", totalXp: character.startingSkill.xp,
    acquiredAt: character.createdAt, acquisitionSource: "CHARACTER_CREATION", status: "ACTIVE",
  }];
  return Object.fromEntries(records.map((skill) => [skill.id, {
    ...skill, description: skill.description, category: skill.category, acquiredAt: skill.acquiredAt,
  }])) as ProgressionState["skills"];
}

function progressionState(character: CharacterRecord): ProgressionState {
  return {
    characterId: character.id, level: character.level, xp: character.xp, totalXp: character.totalXp ?? character.xp,
    rank: character.rank, title: character.title ?? "Shadow Initiate", titleHistory: character.titleHistory ?? ["Shadow Initiate"],
    skillUnlockTokens: character.skillUnlockTokens, skills: skillState(character),
    completedQuestIds: new Set((character.quests ?? []).filter((quest) => quest.completed).map((quest) => quest.id)),
  };
}

function currentSkillRecords(state: ProgressionState): SkillRecord[] {
  return Object.values(state.skills).map((skill) => ({
    id: skill.id, name: skill.name, description: skill.description ?? "", category: skill.category ?? "CUSTOM",
    level: skill.level, xp: skill.xp, totalXp: skill.totalXp, acquiredAt: skill.acquiredAt,
    acquisitionSource: skill.acquisitionSource, status: skill.status,
  }));
}

export function createQuestService() {
  const engine = new ProgressionEngine();
  return {
    async templates(userId: string) {
      const user = await User.findById(userId).select("character");
      const character = requireCharacter(user);
      return questTemplates.filter((template) => template.minimumLevel <= character.level).map(({ id, name, description, minimumLevel, goal, milestones }) => ({ id, name, description, minimumLevel, goal, milestoneCount: milestones.length, questCount: milestones.reduce((count, milestone) => count + milestone.quests.length, 0) }));
    },

    async activateTemplate(userId: string, templateId: string) {
      const user = await User.findById(userId).select("character");
      const character = requireCharacter(user);
      const source = questTemplates.find((template) => template.id === templateId);
      if (!source) throw new AppError(404, "TEMPLATE_NOT_FOUND", "Quest template not found.");
      if (character.level < source.minimumLevel) throw new AppError(403, "TEMPLATE_LOCKED", "This quest template is not unlocked yet.");
      if (hasTemplateQuests(character, templateId)) return { alreadyActive: true };
      const activated = activateTemplate(templateId)!;
      const nextCharacter = { ...character, goals: [...(character.goals ?? []), activated.goal], milestones: [...(character.milestones ?? []), ...activated.milestones], quests: [...(character.quests ?? []), ...activated.quests], version: (character.version ?? 0) + 1, updatedAt: new Date() };
      const updated = await User.findOneAndUpdate({ _id: userId, ...characterVersionFilter(character.version) }, { $set: { character: nextCharacter } }, { new: true, runValidators: true });
      if (!updated) {
        const latestUser = await User.findById(userId).select("character");
        if (latestUser?.character && hasTemplateQuests(latestUser.character, templateId)) {
          return { alreadyActive: true };
        }
        throw new AppError(409, "CONCURRENT_UPDATE", "The character changed. Please retry.");
      }
      return { alreadyActive: false, goal: activated.goal, milestones: activated.milestones, quests: activated.quests };
    },

    async list(userId: string) {
      const user = await User.findById(userId).select("character");
      const character = requireCharacter(user);
      return { goals: character.goals ?? [], milestones: character.milestones ?? [], quests: character.quests ?? [] };
    },

    async completeObjective(userId: string, questId: string, objectiveId: string) {
      const user = await User.findById(userId).select("character");
      const character = requireCharacter(user);
      const quest = (character.quests ?? []).find((candidate) => candidate.id === questId);
      const objective = quest?.objectives.find((candidate) => candidate.id === objectiveId);
      if (!quest || !objective) throw new AppError(404, "OBJECTIVE_NOT_FOUND", "Quest objective not found.");
      if (quest.completed || objective.completed) return quest;
      objective.completed = true;
      const updated = await User.findOneAndUpdate({ _id: userId, ...characterVersionFilter(character.version), "character.quests": { $elemMatch: { id: questId, completed: false } } }, { $set: { "character.quests": character.quests, "character.version": (character.version ?? 0) + 1, "character.updatedAt": new Date() } }, { new: true, runValidators: true });
      if (!updated) {
        const latestUser = await User.findById(userId).select("character");
        const latestQuest = latestUser?.character?.quests?.find(
          (candidate) => candidate.id === questId,
        );
        if (
          latestQuest?.completed ||
          latestQuest?.objectives.some(
            (candidate) => candidate.id === objectiveId && candidate.completed,
          )
        ) {
          return latestQuest;
        }
        throw new AppError(409, "CONCURRENT_UPDATE", "The quest changed. Please retry.");
      }
      return quest;
    },

    async complete(userId: string, questId: string) {
      const user = await User.findById(userId).select("character");
      const character = requireCharacter(user);
      const quest = (character.quests ?? []).find((candidate) => candidate.id === questId);
      if (!quest) throw new AppError(404, "QUEST_NOT_FOUND", "Quest not found.");
      if (quest.completed) return { alreadyCompleted: true, quest, progression: null };
      const completedObjectives = quest.objectives.filter((objective) => objective.completed).length;
      if (completedObjectives < quest.objectives.length) {
        throw new AppError(
          409,
          "OBJECTIVES_INCOMPLETE",
          "Complete all quest objectives before completing this quest.",
        );
      }
      const result = engine.processQuestCompletion(progressionState(character), { questId, ...(quest.primarySkillId ? { primarySkillId: quest.primarySkillId } : {}), requiredObjectiveCount: quest.objectives.length, completedObjectiveCount: completedObjectives });
      const completedAt = new Date();
      const quests = (character.quests ?? []).map((candidate) => candidate.id === questId ? { ...candidate, completed: true, completedAt } : candidate);
      const milestones = (character.milestones ?? []).map((milestone) => ({ ...milestone, completed: milestone.questIds.every((id) => quests.find((candidate) => candidate.id === id)?.completed === true) }));
      const goals = (character.goals ?? []).map((goal) => ({ ...goal, completed: goal.milestoneIds.every((id) => milestones.find((milestone) => milestone.id === id)?.completed === true) }));
      const progressionEvents = [...(character.progressionEvents ?? []), ...result.events];
      const nextCharacter: CharacterRecord = { ...character, level: result.state.level, xp: result.state.xp, totalXp: result.state.totalXp, rank: result.state.rank, title: result.state.title, titleHistory: [...result.state.titleHistory], skillUnlockTokens: result.state.skillUnlockTokens, skills: currentSkillRecords(result.state), startingSkill: { ...character.startingSkill, level: result.state.skills[character.startingSkill.id]?.level ?? character.startingSkill.level, xp: result.state.skills[character.startingSkill.id]?.xp ?? character.startingSkill.xp }, quests, milestones, goals, progressionEvents, version: (character.version ?? 0) + 1, updatedAt: completedAt };
      const updated = await User.findOneAndUpdate({ _id: userId, ...characterVersionFilter(character.version), "character.quests": { $elemMatch: { id: questId, completed: false } } }, { $set: { character: nextCharacter } }, { new: true, runValidators: true });
      if (!updated) {
        const latestUser = await User.findById(userId).select("character");
        const latestQuest = latestUser?.character?.quests?.find(
          (candidate) => candidate.id === questId,
        );
        if (latestQuest?.completed) {
          return {
            alreadyCompleted: true,
            quest: latestQuest,
            progression: null,
          };
        }
        throw new AppError(409, "CONCURRENT_UPDATE", "The quest changed. Please retry.");
      }
      return { alreadyCompleted: false, quest: quests.find((candidate) => candidate.id === questId), progression: result };
    },
  };
}

export type QuestService = ReturnType<typeof createQuestService>;
