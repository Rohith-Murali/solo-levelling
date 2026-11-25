import { defaultProgressionConfig, type ProgressionConfig } from "./config.js";
import type { QuestDifficulty } from "./models.js";

export function resolveTitle(level: number, config: ProgressionConfig = defaultProgressionConfig): string {
  const title = [...config.titles].reverse().find((candidate) => candidate.minimumLevel <= level);
  if (!title) throw new Error(`No title configured for level ${level}.`);
  return title.name;
}

export function titlesUnlockedBetweenLevels(previousLevel: number, currentLevel: number, config: ProgressionConfig): string[] {
  return config.titles
    .filter((title) => title.minimumLevel > previousLevel && title.minimumLevel <= currentLevel)
    .map((title) => title.name);
}

export function normalizeQuestDifficulty(difficulty = "NORMAL"): QuestDifficulty {
  const normalized = difficulty.trim().toUpperCase();
  if (normalized === "MEDIUM") return "NORMAL";
  if (normalized === "EASY" || normalized === "NORMAL" || normalized === "HARD" || normalized === "EPIC") {
    return normalized;
  }
  throw new Error(`Unsupported quest difficulty: ${difficulty}.`);
}

export function characterXpReward(baseXp: number, level: number, config: ProgressionConfig = defaultProgressionConfig): number {
  return Math.round(baseXp * config.characterXpMultiplier(level));
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
