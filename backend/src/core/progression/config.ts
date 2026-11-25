import type { QuestDifficulty, RankDefinition, TitleDefinition } from "./models.js";

export interface ProgressionConfig {
  readonly initialLevel: number;
  readonly initialXp: number;
  readonly characterXpRequired: (level: number) => number;
  readonly characterXpMultiplier: (level: number) => number;
  readonly questBaseCharacterXp: Readonly<Record<QuestDifficulty, number>>;
  readonly milestoneBaseCharacterXp: number;
  readonly goalBaseCharacterXp: number;
  readonly skillXpMultiplier: number;
  readonly skillXpRounding: "floor" | "round" | "ceil";
  readonly ranks: readonly RankDefinition[];
  readonly titles: readonly TitleDefinition[];
  readonly skillUnlockInitialLevel: number;
  readonly skillUnlockInterval: number;
}

export const defaultProgressionConfig: ProgressionConfig = {
  initialLevel: 1,
  initialXp: 0,
  characterXpRequired: (level) => 100 + 50 * (level - 1),
  characterXpMultiplier: (level) => Math.sqrt(1 + 0.5 * (level - 1)),
  questBaseCharacterXp: { EASY: 15, NORMAL: 40, HARD: 80, EPIC: 160 },
  milestoneBaseCharacterXp: 80,
  goalBaseCharacterXp: 200,
  skillXpMultiplier: 0.5,
  skillXpRounding: "round",
  ranks: [
    { name: "E", minimumLevel: 1, maximumLevel: 4 },
    { name: "D", minimumLevel: 5, maximumLevel: 9 },
    { name: "C", minimumLevel: 10, maximumLevel: 14 },
    { name: "B", minimumLevel: 15, maximumLevel: 19 },
    { name: "A", minimumLevel: 20, maximumLevel: 24 },
    { name: "S", minimumLevel: 25 },
  ],
  titles: [
    { name: "Shadow Initiate", minimumLevel: 1 },
    { name: "Veil Walker", minimumLevel: 11 },
    { name: "Shadow Seeker", minimumLevel: 21 },
    { name: "Nightblade Disciple", minimumLevel: 31 },
    { name: "Dusk Reclaimer", minimumLevel: 41 },
    { name: "Stygian Ascendant", minimumLevel: 51 },
    { name: "Eternal Eclipse", minimumLevel: 61 },
    { name: "Ashborne Sentinel", minimumLevel: 71 },
    { name: "Umbra Mortis", minimumLevel: 81 },
    { name: "Shadow Sovereign", minimumLevel: 91 },
    { name: "Shadow Monarch", minimumLevel: 100 },
  ],
  skillUnlockInitialLevel: 3,
  skillUnlockInterval: 3,
};

export function validateProgressionConfig(config: ProgressionConfig): void {
  if (config.initialLevel < 1 || config.initialXp < 0) throw new Error("Invalid progression initial state.");
  if (config.skillXpMultiplier < 0) throw new Error("Skill XP multiplier cannot be negative.");
  if (Object.values(config.questBaseCharacterXp).some((xp) => !Number.isInteger(xp) || xp < 0)) throw new Error("Quest XP rewards must be non-negative integers.");
  if (!Number.isInteger(config.milestoneBaseCharacterXp) || config.milestoneBaseCharacterXp < 0) throw new Error("Milestone XP reward must be a non-negative integer.");
  if (!Number.isInteger(config.goalBaseCharacterXp) || config.goalBaseCharacterXp < 0) throw new Error("Goal XP reward must be a non-negative integer.");
  if (config.skillUnlockInitialLevel < 1 || config.skillUnlockInterval < 1) throw new Error("Invalid skill unlock rules.");
  if (config.ranks.length === 0 || config.ranks.some((rank) => rank.minimumLevel < 1)) throw new Error("At least one valid rank is required.");
  if (config.ranks.some((rank, index) => index > 0 && rank.minimumLevel <= config.ranks[index - 1]!.minimumLevel)) throw new Error("Ranks must be ordered by increasing minimum level.");
  if (config.titles.length === 0 || config.titles[0]!.minimumLevel > config.initialLevel) throw new Error("A title must be configured for the initial level.");
  if (config.titles.some((title) => title.minimumLevel < 1)) throw new Error("Title levels must be positive.");
  if (config.titles.some((title, index) => index > 0 && title.minimumLevel <= config.titles[index - 1]!.minimumLevel)) throw new Error("Titles must be ordered by increasing minimum level.");
}
