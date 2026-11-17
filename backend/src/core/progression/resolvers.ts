import type { ProgressionConfig } from "./config.js";

export function resolveRank(level: number, config: ProgressionConfig): string {
  const rank = [...config.ranks].reverse().find((candidate) => candidate.minimumLevel <= level);
  if (!rank) throw new Error(`No rank configured for level ${level}.`);
  return rank.name;
}

export function resolveTitle(rank: string, config: ProgressionConfig): string {
  const title = config.titles.find((candidate) => candidate.rank === rank);
  if (!title) throw new Error(`No title configured for rank ${rank}.`);
  return title.name;
}

export function unlockTokensAtLevel(level: number, config: ProgressionConfig): number {
  return level < config.skillUnlockInitialLevel
    ? 0
    : 1 + Math.floor((level - config.skillUnlockInitialLevel) / config.skillUnlockInterval);
}

export function xpForLevel(level: number, config: ProgressionConfig): number {
  if (level < config.initialLevel) throw new Error("Level must be positive.");
  return config.characterXpRequired(level);
}
