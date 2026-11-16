import type { RankDefinition, TitleDefinition } from "./models.js";

export interface ProgressionConfig {
  readonly initialLevel: number;
  readonly initialXp: number;
  readonly characterXpRequired: (level: number) => number;
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
  skillXpMultiplier: 0.5,
  skillXpRounding: "floor",
  ranks: [
    { name: "E", minimumLevel: 1, maximumLevel: 4 },
    { name: "D", minimumLevel: 5, maximumLevel: 9 },
    { name: "C", minimumLevel: 10, maximumLevel: 14 },
    { name: "B", minimumLevel: 15, maximumLevel: 19 },
    { name: "A", minimumLevel: 20, maximumLevel: 24 },
    { name: "S", minimumLevel: 25 },
  ],
  titles: [
    { name: "Shadow Initiate", rank: "E" },
    { name: "Shadow Walker", rank: "D" },
    { name: "Shadow Hunter", rank: "C" },
    { name: "Shadow Commander", rank: "B" },
    { name: "Umbra Mortis", rank: "A" },
    { name: "Shadow Monarch", rank: "S" },
  ],
  skillUnlockInitialLevel: 3,
  skillUnlockInterval: 3,
};

export function validateProgressionConfig(config: ProgressionConfig): void {
  if (config.initialLevel < 1 || config.initialXp < 0) throw new Error("Invalid progression initial state.");
  if (config.skillXpMultiplier < 0) throw new Error("Skill XP multiplier cannot be negative.");
  if (config.skillUnlockInitialLevel < 1 || config.skillUnlockInterval < 1) throw new Error("Invalid skill unlock rules.");
  if (config.ranks.length === 0 || config.ranks.some((rank) => rank.minimumLevel < 1)) throw new Error("At least one valid rank is required.");
  if (config.ranks.some((rank, index) => index > 0 && rank.minimumLevel <= config.ranks[index - 1]!.minimumLevel)) throw new Error("Ranks must be ordered by increasing minimum level.");
  if (config.titles.some((title) => !config.ranks.some((rank) => rank.name === title.rank))) throw new Error("Every title must reference a configured rank.");
}
