import { AppError } from "../errors/app-error.js";
import { User } from "../models/user.model.js";
import type { CharacterRecord } from "../models/user.model.js";
import { characterAvatars } from "./character-catalog.js";

function getLevelProgress(level: number, totalXp: number) {
  const completedLevels = level - 1;
  const xpAtLevelStart =
    completedLevels * 100 + 25 * completedLevels * (completedLevels - 1);

  return {
    currentLevelXp: Math.max(0, totalXp - xpAtLevelStart),
    xpToNextLevel: 100 + 50 * completedLevels,
  };
}

function toDashboard(character: CharacterRecord) {
  const characterProgress = getLevelProgress(character.level, character.xp);
  const skillProgress = getLevelProgress(
    character.startingSkill.level,
    character.startingSkill.xp,
  );
  const avatar = characterAvatars.find(
    (item) => item.id === character.avatarId,
  );

  return {
    character: {
      id: character.id,
      name: character.name,
      avatarId: character.avatarId,
      avatarImagePath: avatar?.imagePath ?? null,
      rank: character.rank,
      level: character.level,
      totalXp: character.xp,
      ...characterProgress,
      skillUnlockTokens: character.skillUnlockTokens,
    },
    statistics: {
      completedQuestCount: 0,
      activeQuestCount: 0,
      acquiredSkillCount: 1,
      achievementCount: 0,
      completedGoalCount: 0,
      completedMilestoneCount: 0,
    },
    activeQuests: [],
    skills: [
      {
        id: character.startingSkill.id,
        name: character.startingSkill.name,
        level: character.startingSkill.level,
        ...skillProgress,
      },
    ],
    progressionOverview: {
      period: "LAST_30_DAYS",
      characterXpEarned: null,
      questsCompleted: null,
      goalsCompleted: null,
      milestonesCompleted: null,
      xpTrend: [],
    },
    recentActivity: [],
  };
}

export function createDashboardService() {
  return {
    async getForUser(userId: string) {
      const user = await User.findById(userId).select("character");
      if (!user) {
        throw new AppError(
          401,
          "INVALID_ACCESS_TOKEN",
          "Your session is invalid or expired.",
        );
      }
      if (!user.character) {
        throw new AppError(
          409,
          "CHARACTER_REQUIRED",
          "Create a character before opening the dashboard.",
        );
      }

      return toDashboard(user.character);
    },
  };
}

export type DashboardService = ReturnType<typeof createDashboardService>;
