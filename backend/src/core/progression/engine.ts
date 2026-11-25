import { randomUUID } from "node:crypto";
import { defaultProgressionConfig, validateProgressionConfig, type ProgressionConfig } from "./config.js";
import type { ProgressionEvent, ProgressionResult, ProgressionSourceType, ProgressionState, QuestCompletion, SkillState } from "./models.js";
import { characterXpReward, normalizeQuestDifficulty, resolveTitle, titlesUnlockedBetweenLevels, unlockTokensAtLevel, xpForLevel } from "./resolvers.js";

export class ProgressionEngine {
  private readonly config: ProgressionConfig;

  constructor(config: ProgressionConfig = defaultProgressionConfig) {
    validateProgressionConfig(config);
    this.config = config;
  }

  createInitialState(characterId: string, skill: Omit<SkillState, "level" | "xp" | "totalXp" | "acquiredAt" | "acquisitionSource" | "status">, now = new Date()): ProgressionState {
    const level = this.config.initialLevel;
    const title = resolveTitle(level, this.config);
    const initialSkill: SkillState = { ...skill, level, xp: 0, totalXp: 0, acquiredAt: now, acquisitionSource: "CHARACTER_CREATION", status: "ACTIVE" };
    return { characterId, level, xp: this.config.initialXp, totalXp: this.config.initialXp, title, titleHistory: [title], skillUnlockTokens: unlockTokensAtLevel(level, this.config), skills: { [skill.id]: initialSkill }, completedQuestIds: new Set() };
  }

  processQuestCompletion(state: ProgressionState, quest: QuestCompletion, now = new Date()): ProgressionResult {
    const difficulty = normalizeQuestDifficulty(quest.difficulty);
    const characterXpGained = characterXpReward(this.config.questBaseCharacterXp[difficulty], state.level, this.config);
    return this.processCompletion(state, { ...quest, difficulty }, characterXpGained, now, "QUEST");
  }

  /** Applies an already-authorized XP award, useful for imports and other progression sources. */
  awardXp(state: ProgressionState, xp: number, relatedEntityId: string, primarySkillId?: string, now = new Date()): ProgressionResult {
    if (!Number.isInteger(xp) || xp < 0) throw new Error("XP award must be a non-negative integer.");
    return this.processCompletion(state, { questId: relatedEntityId, ...(primarySkillId ? { primarySkillId } : {}) }, xp, now, "QUEST");
  }

  awardCompletionBonus(
    state: ProgressionState,
    relatedEntityId: string,
    eventType: "MILESTONE_COMPLETED" | "GOAL_COMPLETED",
    now = new Date(),
  ): ProgressionResult {
    const sourceType = eventType === "MILESTONE_COMPLETED" ? "MILESTONE" : "GOAL";
    const baseXp = sourceType === "MILESTONE"
      ? this.config.milestoneBaseCharacterXp
      : this.config.goalBaseCharacterXp;
    return this.awardCharacterXp(
      state,
      characterXpReward(baseXp, state.level, this.config),
      relatedEntityId,
      eventType,
      now,
    );
  }

  awardCharacterXp(
    state: ProgressionState,
    xp: number,
    relatedEntityId: string,
    eventType: "MILESTONE_COMPLETED" | "GOAL_COMPLETED",
    now = new Date(),
  ): ProgressionResult {
    if (!Number.isInteger(xp) || xp < 0) throw new Error("XP award must be a non-negative integer.");
    if (xp === 0) return this.result(state, { questId: relatedEntityId }, 0, 0, [], [state.title, state.title], [], 0, [], false, now);

    const character = {
      ...this.advance(state.level, state.xp + xp),
      totalXp: state.totalXp + xp,
    };
    const previousTitle = state.title;
    const currentTitle = resolveTitle(character.level, this.config);
    const levelUps = Array.from({ length: character.level - state.level }, (_, index) => state.level + index + 1);
    const events: ProgressionEvent[] = [];
    const event = (type: ProgressionEvent["type"], values: Partial<ProgressionEvent> = {}) => events.push({
      id: randomUUID(),
      characterId: state.characterId,
      type,
      occurredAt: now,
      ...values,
    });
    const sourceType: ProgressionSourceType = eventType === "MILESTONE_COMPLETED" ? "MILESTONE" : "GOAL";
    event("CHARACTER_XP_GAINED", {
      relatedEntityId,
      xpChange: xp,
      previousValue: state.totalXp,
      newValue: character.totalXp,
      metadata: { xpTransaction: { sourceType, sourceId: relatedEntityId, rewardType: "CHARACTER_XP", skillId: null, amount: xp, characterLevelAtAward: state.level } },
    });
    levelUps.forEach((level) => event("CHARACTER_LEVEL_INCREASED", { relatedEntityId, previousValue: level - 1, newValue: level }));
    const newlyUnlockedTitles = this.titlesUnlocked(state.level, character.level, previousTitle, currentTitle);
    let priorTitle = previousTitle;
    newlyUnlockedTitles.forEach((title) => {
      event("TITLE_UNLOCKED", { relatedEntityId, previousValue: priorTitle, newValue: title });
      priorTitle = title;
    });
    event(eventType, { relatedEntityId });

    const nextState: ProgressionState = {
      ...state,
      ...character,
      title: currentTitle,
      titleHistory: newlyUnlockedTitles.length ? [...state.titleHistory, ...newlyUnlockedTitles] : state.titleHistory,
    };
    return this.result(nextState, { questId: relatedEntityId }, xp, 0, levelUps, [previousTitle, currentTitle], newlyUnlockedTitles, 0, events, false, now);
  }

  private processCompletion(state: ProgressionState, quest: QuestCompletion, characterXpGained: number, now: Date, sourceType: ProgressionSourceType): ProgressionResult {
    if (state.completedQuestIds.has(quest.questId)) return this.result(state, quest, 0, 0, [], [state.title, state.title], [], 0, [], true, now);
    const skill = quest.primarySkillId ? state.skills[quest.primarySkillId] : undefined;
    const skillXpGained = skill ? this.round(characterXpGained * this.config.skillXpMultiplier) : 0;
    const character = {
      ...this.advance(state.level, state.xp + characterXpGained),
      totalXp: state.totalXp + characterXpGained,
    };
    const previousTitle = state.title;
    const currentTitle = resolveTitle(character.level, this.config);
    const previousTokens = unlockTokensAtLevel(state.level, this.config);
    const currentTokens = unlockTokensAtLevel(character.level, this.config);
    const newlyEarnedUnlockTokens = Math.max(0, currentTokens - previousTokens);
    const levelUps = Array.from({ length: character.level - state.level }, (_, index) => state.level + index + 1);
    const newSkill = skill ? this.advanceSkill(skill, skillXpGained) : undefined;
    const events: ProgressionEvent[] = [];
    const event = (type: ProgressionEvent["type"], values: Partial<ProgressionEvent> = {}) => events.push({ id: randomUUID(), characterId: state.characterId, type, occurredAt: now, ...values });
    event("QUEST_COMPLETED", { relatedEntityId: quest.questId });
    event("CHARACTER_XP_GAINED", {
      relatedEntityId: quest.questId,
      xpChange: characterXpGained,
      previousValue: state.totalXp,
      newValue: character.totalXp,
      metadata: { xpTransaction: { sourceType, sourceId: quest.questId, rewardType: "CHARACTER_XP", skillId: null, amount: characterXpGained, characterLevelAtAward: state.level } },
    });
    levelUps.forEach((level) => event("CHARACTER_LEVEL_INCREASED", { relatedEntityId: quest.questId, previousValue: level - 1, newValue: level }));
    const newlyUnlockedTitles = this.titlesUnlocked(state.level, character.level, previousTitle, currentTitle);
    let priorTitle = previousTitle;
    newlyUnlockedTitles.forEach((title) => {
      event("TITLE_UNLOCKED", { previousValue: priorTitle, newValue: title });
      priorTitle = title;
    });
    if (newSkill) {
      event("SKILL_XP_GAINED", {
        relatedEntityId: newSkill.id,
        xpChange: skillXpGained,
        previousValue: skill?.totalXp,
        newValue: newSkill.totalXp,
        metadata: { xpTransaction: { sourceType, sourceId: quest.questId, rewardType: "SKILL_XP", skillId: newSkill.id, amount: skillXpGained, characterLevelAtAward: state.level } },
      });
      for (let level = (skill?.level ?? newSkill.level) + 1; level <= newSkill.level; level++) event("SKILL_LEVEL_INCREASED", { relatedEntityId: newSkill.id, previousValue: level - 1, newValue: level });
    }
    if (newlyEarnedUnlockTokens > 0) event("SKILL_UNLOCK_TOKEN_EARNED", { xpChange: newlyEarnedUnlockTokens, previousValue: previousTokens, newValue: currentTokens });
    if (quest.completedMilestone) event("MILESTONE_COMPLETED", { relatedEntityId: quest.questId });
    if (quest.completedGoal) event("GOAL_COMPLETED", { relatedEntityId: quest.questId });
    const nextState: ProgressionState = { ...state, ...character, title: currentTitle, titleHistory: newlyUnlockedTitles.length ? [...state.titleHistory, ...newlyUnlockedTitles] : state.titleHistory, skillUnlockTokens: state.skillUnlockTokens + newlyEarnedUnlockTokens, skills: newSkill ? { ...state.skills, [newSkill.id]: newSkill } : state.skills, completedQuestIds: new Set([...state.completedQuestIds, quest.questId]) };
    return this.result(nextState, quest, characterXpGained, skillXpGained, levelUps, [previousTitle, currentTitle], newlyUnlockedTitles, newlyEarnedUnlockTokens, events, false, now, newSkill, skill ? Array.from({ length: newSkill!.level - skill.level }, (_, index) => skill!.level + index + 1) : []);
  }

  grantSkill(state: ProgressionState, skill: Omit<SkillState, "level" | "xp" | "totalXp" | "acquiredAt" | "acquisitionSource" | "status">, acquisitionSource: string, now = new Date()): { state: ProgressionState; event: ProgressionEvent } {
    if (state.skills[skill.id]) throw new Error("Skill has already been acquired.");
    const acquired: SkillState = { ...skill, level: 1, xp: 0, totalXp: 0, acquiredAt: now, acquisitionSource, status: "ACTIVE" };
    return { state: { ...state, skills: { ...state.skills, [skill.id]: acquired } }, event: { id: randomUUID(), characterId: state.characterId, type: "SKILL_ACQUIRED", relatedEntityId: skill.id, previousValue: null, newValue: acquired, occurredAt: now } };
  }

  acquireSkill(state: ProgressionState, skill: Omit<SkillState, "level" | "xp" | "totalXp" | "acquiredAt" | "acquisitionSource" | "status">, now = new Date()): { state: ProgressionState; event: ProgressionEvent } {
    if (state.skillUnlockTokens < 1) throw new Error("No skill unlock tokens available.");
    const acquired = this.grantSkill(state, skill, "SKILL_UNLOCK", now);
    return { state: { ...acquired.state, skillUnlockTokens: state.skillUnlockTokens - 1 }, event: acquired.event };
  }

  private advance(level: number, xp: number): { level: number; xp: number; totalXp: number } { let nextLevel = level; let remaining = xp; while (remaining >= xpForLevel(nextLevel, this.config)) { remaining -= xpForLevel(nextLevel, this.config); nextLevel++; } return { level: nextLevel, xp: remaining, totalXp: xp }; }
  private titlesUnlocked(previousLevel: number, currentLevel: number, previousTitle: string, currentTitle: string): string[] {
    const unlocked = titlesUnlockedBetweenLevels(previousLevel, currentLevel, this.config);
    return unlocked.length > 0 || previousTitle === currentTitle ? unlocked : [currentTitle];
  }
  private advanceSkill(skill: SkillState, gained: number): SkillState { const advanced = this.advance(skill.level, skill.xp + gained); return { ...skill, ...advanced, totalXp: skill.totalXp + gained }; }
  private round(value: number): number { return this.config.skillXpRounding === "ceil" ? Math.ceil(value) : this.config.skillXpRounding === "round" ? Math.round(value) : Math.floor(value); }
  private result(state: ProgressionState, quest: QuestCompletion, characterXpGained: number, skillXpGained: number, characterLevelUps: readonly number[], titles: readonly string[], newlyUnlockedTitles: readonly string[], newlyEarnedUnlockTokens: number, events: readonly ProgressionEvent[], alreadyCompleted: boolean, _now: Date, skill?: SkillState, skillLevelUps: readonly number[] = []): ProgressionResult {
    return {
      state,
      alreadyCompleted,
      characterXpGained,
      characterTotalXp: state.totalXp,
      previousCharacterLevel: state.level - characterLevelUps.length,
      currentCharacterLevel: state.level,
      characterLevelUps,
      previousTitle: titles[0] ?? state.title,
      currentTitle: titles[1] ?? state.title,
      newlyUnlockedTitles,
      ...(quest.primarySkillId ? { skillId: quest.primarySkillId } : {}),
      skillXpGained,
      ...(skill ? { skillCurrentLevel: skill.level } : {}),
      skillLevelUps,
      newlyEarnedUnlockTokens,
      events,
    };
  }
}
