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

export interface RankDefinition {
  readonly name: string;
  readonly minimumLevel: number;
  readonly maximumLevel?: number;
}

export interface TitleDefinition {
  readonly name: string;
  readonly rank: string;
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
  readonly primarySkillId?: string;
  readonly requiredObjectiveCount?: number;
  readonly completedObjectiveCount?: number;
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
  readonly metadata?: Readonly<Record<string, unknown>>;
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
