export type ProgressionEventType =
  | "QUEST_COMPLETED"
  | "CHARACTER_XP_GAINED"
  | "CHARACTER_LEVEL_INCREASED"
  | "RANK_PROMOTED"
  | "TITLE_UNLOCKED"
  | "SKILL_XP_GAINED"
  | "SKILL_LEVEL_INCREASED"
  | "SKILL_UNLOCK_TOKEN_EARNED"
  | "SKILL_ACQUIRED"
  | "GOAL_COMPLETED"
  | "MILESTONE_COMPLETED";

export type ProgressionSourceType = "QUEST" | "MILESTONE" | "GOAL";
export type ProgressionRewardType = "CHARACTER_XP" | "SKILL_XP";
export type QuestDifficulty = "EASY" | "NORMAL" | "HARD" | "EPIC";

export interface XpTransaction {
  readonly sourceType: ProgressionSourceType;
  readonly sourceId: string;
  readonly rewardType: ProgressionRewardType;
  readonly skillId: string | null;
  readonly amount: number;
  readonly characterLevelAtAward: number;
}

export interface RankDefinition {
  readonly name: string;
  readonly minimumLevel: number;
  readonly maximumLevel?: number;
}

export interface TitleDefinition {
  readonly name: string;
  readonly minimumLevel: number;
  readonly display?: Readonly<Record<string, string>>;
}

export interface UnlockDefinition {
  readonly id: string;
  readonly name: string;
  readonly description: string;
  readonly category?: string;
}

export interface SkillState {
  readonly id: string;
  readonly name: string;
  readonly description?: string;
  readonly category?: string;
  readonly level: number;
  /** XP held at the current level, after carryover. */
  readonly xp: number;
  readonly totalXp: number;
  readonly acquiredAt: Date;
  readonly acquisitionSource: string;
  readonly status: "ACTIVE" | "INACTIVE";
}

export interface ProgressionState {
  readonly characterId: string;
  readonly level: number;
  /** XP held at the current level, after carryover. */
  readonly xp: number;
  readonly totalXp: number;
  readonly rank: string;
  readonly title: string;
  readonly titleHistory: readonly string[];
  readonly skillUnlockTokens: number;
  readonly skills: Readonly<Record<string, SkillState>>;
  readonly completedQuestIds: ReadonlySet<string>;
}

export interface QuestCompletion {
  readonly questId: string;
  readonly difficulty?: string;
  readonly primarySkillId?: string;
  readonly completedGoal?: boolean;
  readonly completedMilestone?: boolean;
}

export interface ProgressionEvent {
  readonly id: string;
  readonly characterId: string;
  readonly type: ProgressionEventType;
  readonly relatedEntityId?: string;
  readonly xpChange?: number;
  readonly previousValue?: unknown;
  readonly newValue?: unknown;
  readonly occurredAt: Date;
  readonly metadata?: Readonly<Record<string, unknown>> & { readonly xpTransaction?: XpTransaction };
}

export interface ProgressionResult {
  readonly state: ProgressionState;
  readonly alreadyCompleted: boolean;
  readonly characterXpGained: number;
  readonly characterTotalXp: number;
  readonly previousCharacterLevel: number;
  readonly currentCharacterLevel: number;
  readonly characterLevelUps: readonly number[];
  readonly previousRank: string;
  readonly currentRank: string;
  readonly previousTitle: string;
  readonly currentTitle: string;
  readonly newlyUnlockedTitles: readonly string[];
  readonly skillId?: string;
  readonly skillXpGained: number;
  readonly skillCurrentLevel?: number;
  readonly skillLevelUps: readonly number[];
  readonly newlyEarnedUnlockTokens: number;
  readonly events: readonly ProgressionEvent[];
}
