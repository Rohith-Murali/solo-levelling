import { AppError } from "../errors/app-error.js";
import { ProgressionEngine, type ProgressionEvent, type ProgressionState } from "../core/progression/index.js";
import { User } from "../models/user.model.js";
import type { CharacterRecord, QuestRecord, SkillRecord } from "../models/user.model.js";
import { toPlainCharacterRecord } from "./character-record.js";
import { characterVersionFilter } from "./character-version-filter.js";
import { activateTemplate, questTemplates } from "./quest-catalog.js";
import { startingSkills } from "./character-catalog.js";

function requireCharacter(user: { character?: CharacterRecord } | null): CharacterRecord {
  if (!user) throw new AppError(401, "INVALID_ACCESS_TOKEN", "Your session is invalid or expired.");
  if (!user.character) throw new AppError(409, "CHARACTER_REQUIRED", "Create a character before managing quests.");
  return user.character;
}

function hasTemplateQuests(character: CharacterRecord, templateId: string): boolean {
  return (character.quests ?? []).some((quest) => quest.sourceTemplateId === templateId);
}

function skillState(character: CharacterRecord): ProgressionState["skills"] {
  const plainCharacter = toPlainCharacterRecord(character);
  const records: SkillRecord[] = plainCharacter.skills?.length ? plainCharacter.skills : [{
    ...plainCharacter.startingSkill, description: "Starting skill", category: "STARTING", totalXp: plainCharacter.startingSkill.xp,
    acquiredAt: plainCharacter.createdAt, acquisitionSource: "CHARACTER_CREATION", status: "ACTIVE",
  }];
  return Object.fromEntries(records.map((skill) => [skill.id, {
    ...skill, description: skill.description, category: skill.category, acquiredAt: skill.acquiredAt,
  }])) as ProgressionState["skills"];
}

function progressionState(character: CharacterRecord): ProgressionState {
  const plainCharacter = toPlainCharacterRecord(character);
  return {
    characterId: plainCharacter.id, level: plainCharacter.level, xp: plainCharacter.xp, totalXp: plainCharacter.totalXp ?? plainCharacter.xp,
    rank: plainCharacter.rank, title: plainCharacter.title ?? "Shadow Initiate", titleHistory: plainCharacter.titleHistory ?? ["Shadow Initiate"],
    skillUnlockTokens: plainCharacter.skillUnlockTokens, skills: skillState(plainCharacter),
    completedQuestIds: new Set((plainCharacter.quests ?? []).filter((quest) => quest.completed).map((quest) => quest.id)),
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
      const plainCharacter = toPlainCharacterRecord(character);
      const alreadyActive = hasTemplateQuests(character, templateId);
      const activated = alreadyActive ? undefined : activateTemplate(templateId);
      const templateQuests = activated?.quests ??
        (plainCharacter.quests ?? []).filter((quest) => quest.sourceTemplateId === templateId);
      const progression = progressionState(plainCharacter);
      const skillEvents: ProgressionEvent[] = [];
      const templateSkillIds = new Set(templateQuests.map((quest) => quest.primarySkillId).filter((skillId): skillId is string => skillId !== undefined));
      let nextProgression = progression;
      for (const skillId of templateSkillIds) {
        if (nextProgression.skills[skillId]) continue;
        const skill = startingSkills.find((candidate) => candidate.id === skillId);
        if (!skill) {
          throw new AppError(500, "TEMPLATE_SKILL_NOT_FOUND", "A skill required by this quest template is unavailable.");
        }
        const granted = engine.grantSkill(nextProgression, skill, "QUEST_TEMPLATE");
        nextProgression = granted.state;
        skillEvents.push(granted.event);
      }
      if (alreadyActive && skillEvents.length === 0) return { alreadyActive: true };
      const nextCharacter = {
        ...plainCharacter,
        goals: activated ? [...(plainCharacter.goals ?? []), activated.goal] : plainCharacter.goals,
        milestones: activated ? [...(plainCharacter.milestones ?? []), ...activated.milestones] : plainCharacter.milestones,
        quests: activated ? [...(plainCharacter.quests ?? []), ...activated.quests] : plainCharacter.quests,
        skills: currentSkillRecords(nextProgression),
        skillUnlockTokens: nextProgression.skillUnlockTokens,
        progressionEvents: [...(plainCharacter.progressionEvents ?? []), ...skillEvents],
        version: (character.version ?? 0) + 1,
        updatedAt: new Date(),
      };
      const updated = await User.findOneAndUpdate({ _id: userId, ...characterVersionFilter(character.version) }, { $set: { character: nextCharacter } }, { new: true, runValidators: true });
      if (!updated) {
        const latestUser = await User.findById(userId).select("character");
        if (latestUser?.character && hasTemplateQuests(latestUser.character, templateId)) {
          return { alreadyActive: true };
        }
        throw new AppError(409, "CONCURRENT_UPDATE", "The character changed. Please retry.");
      }
      return activated
        ? { alreadyActive: false, goal: activated.goal, milestones: activated.milestones, quests: activated.quests }
        : { alreadyActive: true, acquiredSkills: currentSkillRecords(nextProgression).filter((skill) => skillEvents.some((event) => event.relatedEntityId === skill.id)) };
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
      const plainCharacter = toPlainCharacterRecord(character);
      const updated = await User.findOneAndUpdate({ _id: userId, ...characterVersionFilter(character.version), "character.quests": { $elemMatch: { id: questId, completed: false } } }, { $set: { "character.quests": plainCharacter.quests, "character.version": (character.version ?? 0) + 1, "character.updatedAt": new Date() } }, { new: true, runValidators: true });
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
      const plainCharacter = toPlainCharacterRecord(character);
      const quests = (plainCharacter.quests ?? []).map((candidate) => candidate.id === questId ? { ...candidate, completed: true, completedAt } : candidate);
      const milestones = (plainCharacter.milestones ?? []).map((milestone) => ({ ...milestone, completed: milestone.questIds.every((id) => quests.find((candidate) => candidate.id === id)?.completed === true) }));
      const goals = (plainCharacter.goals ?? []).map((goal) => ({ ...goal, completed: goal.milestoneIds.every((id) => milestones.find((milestone) => milestone.id === id)?.completed === true) }));
      const progressionEvents = [...(plainCharacter.progressionEvents ?? []), ...result.events];
      const nextCharacter: CharacterRecord = { ...plainCharacter, level: result.state.level, xp: result.state.xp, totalXp: result.state.totalXp, rank: result.state.rank, title: result.state.title, titleHistory: [...result.state.titleHistory], skillUnlockTokens: result.state.skillUnlockTokens, skills: currentSkillRecords(result.state), startingSkill: { ...plainCharacter.startingSkill, level: result.state.skills[plainCharacter.startingSkill.id]?.level ?? plainCharacter.startingSkill.level, xp: result.state.skills[plainCharacter.startingSkill.id]?.xp ?? plainCharacter.startingSkill.xp }, quests, milestones, goals, progressionEvents, version: (character.version ?? 0) + 1, updatedAt: completedAt };
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
