import { randomUUID } from "node:crypto";
import { AppError } from "../errors/app-error.js";
import { ProgressionEngine, type ProgressionEvent, type ProgressionState } from "../core/progression/index.js";
import { User } from "../models/user.model.js";
import type { CharacterRecord, CharacterStats, GoalRecord, MilestoneRecord, QuestRecord, SkillRecord } from "../models/user.model.js";
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

function fullSkillRecords(character: CharacterRecord): SkillRecord[] {
  if (character.skills?.length) return character.skills;
  return [{
    id: character.startingSkill.id,
    name: character.startingSkill.name,
    description: "Starting skill",
    category: "STARTING",
    level: character.startingSkill.level,
    xp: character.startingSkill.xp,
    totalXp: character.startingSkill.xp,
    acquiredAt: character.createdAt,
    acquisitionSource: "CHARACTER_CREATION",
    status: "ACTIVE",
  }];
}

function normalizeLegacyMilestones(
  milestones: MilestoneRecord[],
): MilestoneRecord[] {
  return milestones.map((milestone) => ({
    ...milestone,
    description: milestone.description?.trim() ? milestone.description : milestone.title,
  }));
}

function normalizeLegacyGoals(
  character: CharacterRecord,
  milestones: MilestoneRecord[],
  quests: QuestRecord[],
): GoalRecord[] {
  return (character.goals ?? []).map((goal) => {
    const skillId = goal.primarySkillId || goal.milestoneIds
      .flatMap((milestoneId) =>
        milestones.find((milestone) => milestone.id === milestoneId)?.questIds ?? [],
      )
      .map((questId) => quests.find((quest) => quest.id === questId)?.primarySkillId)
      .find((candidate): candidate is string => Boolean(candidate)) || character.startingSkill.id;
    return {
      ...goal,
      primarySkillId: skillId,
      status: goal.status ?? (goal.completed ? "COMPLETED" : "ACTIVE"),
      createdAt: goal.createdAt ?? character.createdAt,
    };
  });
}

const MILESTONE_XP_BONUS = 25;
const GOAL_XP_BONUS = 100;
const STAT_INCREASES: Record<string, number> = { EASY: 1, NORMAL: 2, MEDIUM: 2, HARD: 3, EPIC: 5 };

function normalizedDifficulty(difficulty: string): keyof typeof STAT_INCREASES {
  const value = difficulty.trim().toUpperCase();
  return value === "MEDIUM" ? "NORMAL" : (value as keyof typeof STAT_INCREASES);
}

function applyQuestStats(stats: CharacterStats | undefined, quest: QuestRecord): CharacterStats {
  const next = { ...(stats ?? { strength: 1, intelligence: 1, vitality: 1, discipline: 1, perception: 1 }) };
  const increase = STAT_INCREASES[normalizedDifficulty(quest.difficulty)] ?? 0;
  for (const stat of quest.statContributions ?? []) {
    if (stat in next) next[stat] = (next[stat] ?? 1) + increase;
  }
  return next;
}

function ensureSkillRecord(character: CharacterRecord, skillId: string, name?: string): CharacterRecord["skills"][number] | undefined {
  const existing = (character.skills ?? []).find((skill) => skill.id === skillId);
  if (existing) return existing;
  const catalog = startingSkills.find((skill) => skill.id === skillId);
  if (catalog) return {
    id: catalog.id,
    name: catalog.name,
    description: catalog.description,
    category: catalog.category ?? "STARTING",
    level: 1,
    xp: 0,
    totalXp: 0,
    acquiredAt: character.createdAt,
    acquisitionSource: "QUEST_CREATION",
    status: "ACTIVE",
  };
  if (name) return {
    id: skillId,
    name,
    description: name,
    category: "CUSTOM",
    level: 1,
    xp: 0,
    totalXp: 0,
    acquiredAt: character.createdAt,
    acquisitionSource: "QUEST_CREATION",
    status: "ACTIVE",
  };
  return undefined;
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

    async createGoal(userId: string, input: { title: string; description: string; primarySkillId?: string; skillName?: string; statContributions?: string[]; milestones?: Array<{ title: string; description?: string; quests?: Array<{ title: string; description?: string; difficulty?: string; statContributions?: string[] }> }> }) {
      const user = await User.findById(userId).select("character");
      const character = requireCharacter(user);
      const plain = toPlainCharacterRecord(character);
      const activeCount = (plain.goals ?? []).filter((goal) => goal.status === "ACTIVE" || (!goal.status && !goal.completed)).length;
      if (activeCount >= 4) throw new AppError(409, "ACTIVE_GOAL_LIMIT", "Maximum 4 active goals are allowed.");

      let primarySkillId = input.primarySkillId?.trim();
      if (!primarySkillId) {
        if (!input.skillName?.trim()) throw new AppError(400, "SKILL_REQUIRED", "Choose or create exactly one associated skill.");
        primarySkillId = `custom-${randomUUID()}`;
      }
      const existingSkill = ensureSkillRecord(plain, primarySkillId, input.skillName);
      if (!existingSkill) throw new AppError(404, "SKILL_NOT_FOUND", "Associated skill not found.");

      const now = new Date();
      const goalId = randomUUID();
      const newMilestones: MilestoneRecord[] = [];
      const newQuests: QuestRecord[] = [];
      for (const milestoneInput of input.milestones ?? []) {
        const milestoneId = randomUUID();
        const quests = (milestoneInput.quests ?? []).map((questInput) => ({
          id: randomUUID(),
          title: questInput.title,
          description: questInput.description ?? "",
          type: "MAIN" as const,
          difficulty: (questInput.difficulty ?? "NORMAL").toUpperCase(),
          primarySkillId,
          goalId,
          milestoneId,
          statContributions: (questInput.statContributions ?? input.statContributions ?? []) as (keyof CharacterStats)[],
          completed: false,
        }));
        newQuests.push(...quests);
        newMilestones.push({ id: milestoneId, title: milestoneInput.title, description: milestoneInput.description?.trim() ? milestoneInput.description : milestoneInput.title, questIds: quests.map((quest) => quest.id), completed: false });
      }
      const goal: GoalRecord = {
        id: goalId,
        title: input.title,
        description: input.description,
        primarySkillId,
        statContributions: (input.statContributions ?? []) as (keyof CharacterStats)[],
        milestoneIds: newMilestones.map((milestone) => milestone.id),
        completed: false,
        status: "ACTIVE",
        createdAt: now,
      };
      const skillRecords = fullSkillRecords(plain);
      const skills = skillRecords.some((skill) => skill.id === primarySkillId)
        ? skillRecords
        : [...skillRecords, existingSkill];
      const nextCharacter: CharacterRecord = {
        ...plain,
        goals: [...(plain.goals ?? []), goal],
        milestones: [...(plain.milestones ?? []), ...newMilestones],
        quests: [...(plain.quests ?? []), ...newQuests],
        skills: skills as SkillRecord[],
        version: (character.version ?? 0) + 1,
        updatedAt: now,
      };
      const updated = await User.findOneAndUpdate({ _id: userId, ...characterVersionFilter(character.version) }, { $set: { character: nextCharacter } }, { new: true, runValidators: true });
      if (!updated) throw new AppError(409, "CONCURRENT_UPDATE", "The character changed. Please retry.");
      return { goal, milestones: newMilestones, quests: newQuests };
    },

    async updateGoal(userId: string, goalId: string, input: { title?: string; description?: string; primarySkillId?: string; statContributions?: string[] }) {
      const user = await User.findById(userId).select("character");
      const character = requireCharacter(user);
      const goal = (character.goals ?? []).find((candidate) => candidate.id === goalId);
      if (!goal) throw new AppError(404, "GOAL_NOT_FOUND", "Goal not found.");
      if (input.primarySkillId && !ensureSkillRecord(toPlainCharacterRecord(character), input.primarySkillId)) throw new AppError(404, "SKILL_NOT_FOUND", "Associated skill not found.");
      const plain = toPlainCharacterRecord(character);
      const goals = plain.goals.map((candidate) => candidate.id === goalId
        ? {
            ...candidate,
            ...(input.title !== undefined ? { title: input.title } : {}),
            ...(input.description !== undefined ? { description: input.description } : {}),
            ...(input.primarySkillId !== undefined ? { primarySkillId: input.primarySkillId } : {}),
            ...(input.statContributions !== undefined ? { statContributions: input.statContributions as (keyof CharacterStats)[] } : {}),
          }
        : candidate);
      const updated = await User.findOneAndUpdate(
        { _id: userId, ...characterVersionFilter(character.version) },
        { $set: { "character.goals": goals, "character.version": (character.version ?? 0) + 1, "character.updatedAt": new Date() } },
        { new: true, runValidators: true },
      );
      if (!updated) throw new AppError(409, "CONCURRENT_UPDATE", "The character changed. Please retry.");
      return goals.find((candidate) => candidate.id === goalId);
    },

    async deleteGoal(userId: string, goalId: string) {
      const user = await User.findById(userId).select("character");
      const character = requireCharacter(user);
      const goal = (character.goals ?? []).find((candidate) => candidate.id === goalId);
      if (!goal) throw new AppError(404, "GOAL_NOT_FOUND", "Goal not found.");
      const plain = toPlainCharacterRecord(character);
      const milestoneIds = new Set(goal.milestoneIds);
      const goals = plain.goals.filter((candidate) => candidate.id !== goalId);
      const milestones = (plain.milestones ?? []).filter((candidate) => !milestoneIds.has(candidate.id));
      const quests = (plain.quests ?? []).filter((candidate) => candidate.goalId !== goalId);
      const updated = await User.findOneAndUpdate(
        { _id: userId, ...characterVersionFilter(character.version) },
        { $set: { "character.goals": goals, "character.milestones": milestones, "character.quests": quests, "character.version": (character.version ?? 0) + 1, "character.updatedAt": new Date() } },
        { new: true, runValidators: true },
      );
      if (!updated) throw new AppError(409, "CONCURRENT_UPDATE", "The character changed. Please retry.");
      return goal;
    },

    async createMilestone(userId: string, goalId: string, input: { title: string; description?: string; quests?: Array<{ title: string; description?: string; difficulty?: string; statContributions?: string[] }> }) {
      const user = await User.findById(userId).select("character");
      const character = requireCharacter(user);
      const goal = (character.goals ?? []).find((candidate) => candidate.id === goalId);
      if (!goal) throw new AppError(404, "GOAL_NOT_FOUND", "Goal not found.");
      const plain = toPlainCharacterRecord(character);
      const milestoneId = randomUUID();
      const quests: QuestRecord[] = (input.quests ?? []).map((quest) => ({
        id: randomUUID(),
        title: quest.title,
        description: quest.description ?? "",
        type: "MAIN",
        difficulty: (quest.difficulty ?? "NORMAL").toUpperCase(),
        primarySkillId: goal.primarySkillId,
        goalId,
        milestoneId,
        statContributions: (quest.statContributions ?? []) as (keyof CharacterStats)[],
        completed: false,
      }));
      const milestone: MilestoneRecord = { id: milestoneId, title: input.title, description: input.description?.trim() ? input.description : input.title, questIds: quests.map((quest) => quest.id), completed: false };
      const nextGoals = plain.goals.map((candidate) => {
        if (candidate.id !== goalId) return candidate;
        const { completedAt: _completedAt, ...activeGoal } = candidate;
        return { ...activeGoal, milestoneIds: [...candidate.milestoneIds, milestoneId], completed: false, status: "ACTIVE" as const };
      });
      const nextCharacter: CharacterRecord = { ...plain, goals: nextGoals, milestones: [...(plain.milestones ?? []), milestone], quests: [...(plain.quests ?? []), ...quests], version: (character.version ?? 0) + 1, updatedAt: new Date() };
      const updated = await User.findOneAndUpdate({ _id: userId, ...characterVersionFilter(character.version) }, { $set: { character: nextCharacter } }, { new: true, runValidators: true });
      if (!updated) throw new AppError(409, "CONCURRENT_UPDATE", "The character changed. Please retry.");
      return { milestone, quests };
    },

    async updateMilestone(userId: string, goalId: string, milestoneId: string, input: { title?: string; description?: string }) {
      const user = await User.findById(userId).select("character");
      const character = requireCharacter(user);
      const goal = (character.goals ?? []).find((candidate) => candidate.id === goalId);
      if (!goal) throw new AppError(404, "GOAL_NOT_FOUND", "Goal not found.");
      if (!goal.milestoneIds.includes(milestoneId)) throw new AppError(404, "MILESTONE_NOT_FOUND", "Milestone not found.");
      const plain = toPlainCharacterRecord(character);
      const milestones = (plain.milestones ?? []).map((candidate) => candidate.id === milestoneId
        ? {
            ...candidate,
            ...(input.title !== undefined ? { title: input.title } : {}),
            ...(input.description !== undefined ? { description: input.description } : {}),
          }
        : candidate);
      const updated = await User.findOneAndUpdate(
        { _id: userId, ...characterVersionFilter(character.version) },
        { $set: { "character.milestones": milestones, "character.version": (character.version ?? 0) + 1, "character.updatedAt": new Date() } },
        { new: true, runValidators: true },
      );
      if (!updated) throw new AppError(409, "CONCURRENT_UPDATE", "The character changed. Please retry.");
      return milestones.find((candidate) => candidate.id === milestoneId);
    },

    async deleteMilestone(userId: string, goalId: string, milestoneId: string) {
      const user = await User.findById(userId).select("character");
      const character = requireCharacter(user);
      const goal = (character.goals ?? []).find((candidate) => candidate.id === goalId);
      if (!goal) throw new AppError(404, "GOAL_NOT_FOUND", "Goal not found.");
      if (!goal.milestoneIds.includes(milestoneId)) throw new AppError(404, "MILESTONE_NOT_FOUND", "Milestone not found.");
      const plain = toPlainCharacterRecord(character);
      const milestone = (plain.milestones ?? []).find((candidate) => candidate.id === milestoneId);
      const milestones = (plain.milestones ?? []).filter((candidate) => candidate.id !== milestoneId);
      const goals = plain.goals.map((candidate) => candidate.id === goalId
        ? { ...candidate, milestoneIds: candidate.milestoneIds.filter((id) => id !== milestoneId) }
        : candidate);
      const quests = (plain.quests ?? []).map((candidate) => candidate.milestoneId === milestoneId
        ? { ...candidate, milestoneId: undefined }
        : candidate);
      const updated = await User.findOneAndUpdate(
        { _id: userId, ...characterVersionFilter(character.version) },
        { $set: { "character.goals": goals, "character.milestones": milestones, "character.quests": quests, "character.version": (character.version ?? 0) + 1, "character.updatedAt": new Date() } },
        { new: true, runValidators: true },
      );
      if (!updated) throw new AppError(409, "CONCURRENT_UPDATE", "The character changed. Please retry.");
      return milestone;
    },

    async createGoalQuest(userId: string, goalId: string, input: { title: string; description?: string; difficulty?: string; milestoneId?: string; statContributions?: string[] }) {
      const user = await User.findById(userId).select("character");
      const character = requireCharacter(user);
      const goal = (character.goals ?? []).find((candidate) => candidate.id === goalId);
      if (!goal) throw new AppError(404, "GOAL_NOT_FOUND", "Goal not found.");
      if (input.milestoneId && !goal.milestoneIds.includes(input.milestoneId)) {
        throw new AppError(404, "MILESTONE_NOT_FOUND", "Milestone not found.");
      }
      const plain = toPlainCharacterRecord(character);
      const quest: QuestRecord = {
        id: randomUUID(),
        title: input.title,
        description: input.description ?? "",
        type: "MAIN",
        difficulty: (input.difficulty ?? "NORMAL").toUpperCase(),
        primarySkillId: goal.primarySkillId,
        goalId,
        ...(input.milestoneId ? { milestoneId: input.milestoneId } : {}),
        statContributions: (input.statContributions ?? goal.statContributions ?? []) as (keyof CharacterStats)[],
        completed: false,
      };
      const milestones = (plain.milestones ?? []).map((candidate) => input.milestoneId === candidate.id
        ? { ...candidate, questIds: [...candidate.questIds, quest.id], completed: false, completedAt: undefined }
        : candidate);
      const goals = plain.goals.map((candidate) => {
        if (candidate.id !== goalId) return candidate;
        const { completedAt: _completedAt, ...activeGoal } = candidate;
        return { ...activeGoal, completed: false, status: "ACTIVE" as const };
      });
      const updated = await User.findOneAndUpdate(
        { _id: userId, ...characterVersionFilter(character.version) },
        { $set: { "character.goals": goals, "character.quests": [...(plain.quests ?? []), quest], "character.milestones": milestones, "character.version": (character.version ?? 0) + 1, "character.updatedAt": new Date() } },
        { new: true, runValidators: true },
      );
      if (!updated) throw new AppError(409, "CONCURRENT_UPDATE", "The character changed. Please retry.");
      return quest;
    },

    async updateGoalQuest(userId: string, goalId: string, questId: string, input: { title?: string; description?: string; difficulty?: string; milestoneId?: string | null; statContributions?: string[] }) {
      const user = await User.findById(userId).select("character");
      const character = requireCharacter(user);
      const goal = (character.goals ?? []).find((candidate) => candidate.id === goalId);
      if (!goal) throw new AppError(404, "GOAL_NOT_FOUND", "Goal not found.");
      const plain = toPlainCharacterRecord(character);
      const quest = (plain.quests ?? []).find((candidate) => candidate.id === questId && candidate.goalId === goalId);
      if (!quest) throw new AppError(404, "QUEST_NOT_FOUND", "Quest not found.");
      if (input.milestoneId && !goal.milestoneIds.includes(input.milestoneId)) {
        throw new AppError(404, "MILESTONE_NOT_FOUND", "Milestone not found.");
      }
      const quests = (plain.quests ?? []).map((candidate) => candidate.id === questId
        ? {
            ...candidate,
            ...(input.title !== undefined ? { title: input.title } : {}),
            ...(input.description !== undefined ? { description: input.description } : {}),
            ...(input.difficulty !== undefined ? { difficulty: input.difficulty } : {}),
            ...(input.milestoneId !== undefined
              ? input.milestoneId === null
                ? { milestoneId: undefined }
                : { milestoneId: input.milestoneId }
              : {}),
            ...(input.statContributions !== undefined
              ? { statContributions: input.statContributions as (keyof CharacterStats)[] }
              : {}),
          }
        : candidate);
      const milestones = (plain.milestones ?? []).map((candidate) => {
        if (input.milestoneId === undefined) return candidate;
        const shouldContain = input.milestoneId === candidate.id;
        const questIds = shouldContain
          ? candidate.questIds.includes(questId) ? candidate.questIds : [...candidate.questIds, questId]
          : candidate.questIds.filter((id) => id !== questId);
        return { ...candidate, questIds };
      });
      const updated = await User.findOneAndUpdate(
        { _id: userId, ...characterVersionFilter(character.version) },
        { $set: { "character.quests": quests, "character.milestones": milestones, "character.version": (character.version ?? 0) + 1, "character.updatedAt": new Date() } },
        { new: true, runValidators: true },
      );
      if (!updated) throw new AppError(409, "CONCURRENT_UPDATE", "The character changed. Please retry.");
      return quests.find((candidate) => candidate.id === questId);
    },

    async deleteGoalQuest(userId: string, goalId: string, questId: string) {
      const user = await User.findById(userId).select("character");
      const character = requireCharacter(user);
      const goal = (character.goals ?? []).find((candidate) => candidate.id === goalId);
      if (!goal) throw new AppError(404, "GOAL_NOT_FOUND", "Goal not found.");
      const plain = toPlainCharacterRecord(character);
      const quest = (plain.quests ?? []).find((candidate) => candidate.id === questId && candidate.goalId === goalId);
      if (!quest) throw new AppError(404, "QUEST_NOT_FOUND", "Quest not found.");
      const quests = (plain.quests ?? []).filter((candidate) => candidate.id !== questId);
      const milestones = (plain.milestones ?? []).map((candidate) => ({
        ...candidate,
        questIds: candidate.questIds.filter((id) => id !== questId),
      }));
      const updated = await User.findOneAndUpdate(
        { _id: userId, ...characterVersionFilter(character.version) },
        { $set: { "character.quests": quests, "character.milestones": milestones, "character.version": (character.version ?? 0) + 1, "character.updatedAt": new Date() } },
        { new: true, runValidators: true },
      );
      if (!updated) throw new AppError(409, "CONCURRENT_UPDATE", "The character changed. Please retry.");
      return quest;
    },

    async createSideQuest(userId: string, input: { title: string; description?: string; difficulty?: string; primarySkillId?: string; skillName?: string; statContributions?: string[] }) {
      const user = await User.findById(userId).select("character");
      const character = requireCharacter(user);
      const plain = toPlainCharacterRecord(character);
      let skillId = input.primarySkillId?.trim();
      if (!skillId) {
        if (!input.skillName?.trim()) throw new AppError(400, "SKILL_REQUIRED", "Choose or create exactly one associated skill.");
        skillId = `custom-${randomUUID()}`;
      }
      const skill = ensureSkillRecord(plain, skillId, input.skillName);
      if (!skill) throw new AppError(404, "SKILL_NOT_FOUND", "Associated skill not found.");
      const quest: QuestRecord = {
        id: randomUUID(),
        title: input.title,
        description: input.description ?? "",
        type: "SIDE",
        difficulty: (input.difficulty ?? "NORMAL").toUpperCase(),
        primarySkillId: skillId,
        statContributions: (input.statContributions ?? []) as (keyof CharacterStats)[],
        completed: false,
      };
      const skillRecords = fullSkillRecords(plain);
      const skills = skillRecords.some((candidate) => candidate.id === skillId)
        ? skillRecords
        : [...skillRecords, skill];
      const nextCharacter: CharacterRecord = { ...plain, quests: [...(plain.quests ?? []), quest], skills: skills as SkillRecord[], version: (character.version ?? 0) + 1, updatedAt: new Date() };
      const updated = await User.findOneAndUpdate({ _id: userId, ...characterVersionFilter(character.version) }, { $set: { character: nextCharacter } }, { new: true, runValidators: true });
      if (!updated) throw new AppError(409, "CONCURRENT_UPDATE", "The character changed. Please retry.");
      return quest;
    },

    async archiveGoal(userId: string, goalId: string) {
      const user = await User.findById(userId).select("character");
      const character = requireCharacter(user);
      const goal = (character.goals ?? []).find((candidate) => candidate.id === goalId);
      if (!goal) throw new AppError(404, "GOAL_NOT_FOUND", "Goal not found.");
      const plain = toPlainCharacterRecord(character);
      const goals = plain.goals.map((candidate) => candidate.id === goalId ? { ...candidate, status: "ARCHIVED" as const, archivedAt: new Date() } : candidate);
      const updated = await User.findOneAndUpdate({ _id: userId, ...characterVersionFilter(character.version) }, { $set: { "character.goals": goals, "character.version": (character.version ?? 0) + 1, "character.updatedAt": new Date() } }, { new: true, runValidators: true });
      if (!updated) throw new AppError(409, "CONCURRENT_UPDATE", "The character changed. Please retry.");
      return goals.find((candidate) => candidate.id === goalId);
    },

    async list(userId: string) {
      const user = await User.findById(userId).select("character");
      const character = requireCharacter(user);
      const plainCharacter = toPlainCharacterRecord(character);
      const quests = plainCharacter.quests ?? [];
      await User.updateOne({ _id: userId }, { $unset: { "character.quests.$[].objectives": "" } });
      return { goals: plainCharacter.goals ?? [], milestones: plainCharacter.milestones ?? [], quests };
    },

    async completeMilestone(userId: string, goalId: string, milestoneId: string) {
      const user = await User.findById(userId).select("character");
      const character = requireCharacter(user);
      const plain = toPlainCharacterRecord(character);
      const goal = (plain.goals ?? []).find((candidate) => candidate.id === goalId);
      const milestone = (plain.milestones ?? []).find((candidate) => candidate.id === milestoneId);
      if (!goal) throw new AppError(404, "GOAL_NOT_FOUND", "Goal not found.");
      if (!milestone || !goal.milestoneIds.includes(milestoneId)) throw new AppError(404, "MILESTONE_NOT_FOUND", "Milestone not found.");
      if (milestone.completed) return milestone;
      const quests = plain.quests ?? [];
      const associatedQuests = quests.filter((quest) => quest.milestoneId === milestoneId);
      const milestoneQuests = associatedQuests.length > 0
        ? associatedQuests
        : milestone.questIds
            .map((id) => quests.find((quest) => quest.id === id))
            .filter((quest): quest is QuestRecord => Boolean(quest));
      if (milestoneQuests.length === 0 || !milestoneQuests.every((quest) => quest.completed === true)) {
        throw new AppError(409, "MILESTONE_NOT_READY", "Complete all milestone quests first.");
      }
      const completedAt = new Date();
      const bonus = engine.awardCharacterXp(progressionState(character), MILESTONE_XP_BONUS, milestoneId, "MILESTONE_COMPLETED", completedAt);
      const nextMilestones = (plain.milestones ?? []).map((candidate) => candidate.id === milestoneId ? { ...candidate, completed: true, completedAt } : candidate);
      const nextCharacter: CharacterRecord = { ...plain, level: bonus.state.level, xp: bonus.state.xp, totalXp: bonus.state.totalXp, rank: bonus.state.rank, title: bonus.state.title, titleHistory: [...bonus.state.titleHistory], skillUnlockTokens: bonus.state.skillUnlockTokens, skills: currentSkillRecords(bonus.state), startingSkill: { ...plain.startingSkill, level: bonus.state.skills[plain.startingSkill.id]?.level ?? plain.startingSkill.level, xp: bonus.state.skills[plain.startingSkill.id]?.xp ?? plain.startingSkill.xp }, milestones: nextMilestones, progressionEvents: [...(plain.progressionEvents ?? []), ...bonus.events], version: (character.version ?? 0) + 1, updatedAt: completedAt };
      const updated = await User.findOneAndUpdate({ _id: userId, ...characterVersionFilter(character.version) }, { $set: { character: nextCharacter } }, { new: true, runValidators: true });
      if (!updated) throw new AppError(409, "CONCURRENT_UPDATE", "The character changed. Please retry.");
      return nextMilestones.find((candidate) => candidate.id === milestoneId);
    },

    async completeGoal(userId: string, goalId: string) {
      const user = await User.findById(userId).select("character");
      const character = requireCharacter(user);
      const plain = toPlainCharacterRecord(character);
      const goal = (plain.goals ?? []).find((candidate) => candidate.id === goalId);
      if (!goal) throw new AppError(404, "GOAL_NOT_FOUND", "Goal not found.");
      if (goal.completed) return goal;
      const milestones = plain.milestones ?? [];
      if (goal.milestoneIds.length === 0 || !goal.milestoneIds.every((id) => milestones.find((milestone) => milestone.id === id)?.completed === true)) {
        throw new AppError(409, "GOAL_NOT_READY", "Complete all goal milestones first.");
      }
      const completedAt = new Date();
      const bonus = engine.awardCharacterXp(progressionState(character), GOAL_XP_BONUS, goalId, "GOAL_COMPLETED", completedAt);
      const nextGoals = (plain.goals ?? []).map((candidate) => candidate.id === goalId ? { ...candidate, completed: true, status: "COMPLETED" as const, completedAt } : candidate);
      const nextCharacter: CharacterRecord = { ...plain, level: bonus.state.level, xp: bonus.state.xp, totalXp: bonus.state.totalXp, rank: bonus.state.rank, title: bonus.state.title, titleHistory: [...bonus.state.titleHistory], skillUnlockTokens: bonus.state.skillUnlockTokens, skills: currentSkillRecords(bonus.state), startingSkill: { ...plain.startingSkill, level: bonus.state.skills[plain.startingSkill.id]?.level ?? plain.startingSkill.level, xp: bonus.state.skills[plain.startingSkill.id]?.xp ?? plain.startingSkill.xp }, goals: nextGoals, progressionEvents: [...(plain.progressionEvents ?? []), ...bonus.events], version: (character.version ?? 0) + 1, updatedAt: completedAt };
      const updated = await User.findOneAndUpdate({ _id: userId, ...characterVersionFilter(character.version) }, { $set: { character: nextCharacter } }, { new: true, runValidators: true });
      if (!updated) throw new AppError(409, "CONCURRENT_UPDATE", "The character changed. Please retry.");
      return nextGoals.find((candidate) => candidate.id === goalId);
    },

    async complete(userId: string, questId: string) {
      const user = await User.findById(userId).select("character");
      const character = requireCharacter(user);
      const quest = (character.quests ?? []).find((candidate) => candidate.id === questId);
      if (!quest) throw new AppError(404, "QUEST_NOT_FOUND", "Quest not found.");
      if (quest.completed) return { alreadyCompleted: true, quest, progression: null };
      const result = engine.processQuestCompletion(progressionState(character), { questId, ...(quest.primarySkillId ? { primarySkillId: quest.primarySkillId } : {}) });
      const completedAt = new Date();
      const plainCharacter = toPlainCharacterRecord(character);
      const quests = (plainCharacter.quests ?? []).map((candidate) => candidate.id === questId ? { ...candidate, completed: true, completedAt } : candidate);
      let progressionStateAfterQuest = result.state;
      let progressionEvents = [...(plainCharacter.progressionEvents ?? []), ...result.events];
      let milestones = normalizeLegacyMilestones(plainCharacter.milestones ?? []);
      let goals = normalizeLegacyGoals(plainCharacter, milestones, quests);
      const stats = applyQuestStats(plainCharacter.stats, quest);

      // Completing quests does not complete their milestone or goal. Those
      // transitions are explicit actions so their rewards are only awarded
      // after the user confirms the corresponding completion.

      const nextCharacter: CharacterRecord = { ...plainCharacter, level: progressionStateAfterQuest.level, xp: progressionStateAfterQuest.xp, totalXp: progressionStateAfterQuest.totalXp, rank: progressionStateAfterQuest.rank, title: progressionStateAfterQuest.title, titleHistory: [...progressionStateAfterQuest.titleHistory], skillUnlockTokens: progressionStateAfterQuest.skillUnlockTokens, skills: currentSkillRecords(progressionStateAfterQuest), startingSkill: { ...plainCharacter.startingSkill, level: progressionStateAfterQuest.skills[plainCharacter.startingSkill.id]?.level ?? plainCharacter.startingSkill.level, xp: progressionStateAfterQuest.skills[plainCharacter.startingSkill.id]?.xp ?? plainCharacter.startingSkill.xp }, stats, quests, milestones, goals, progressionEvents, version: (character.version ?? 0) + 1, updatedAt: completedAt };
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
