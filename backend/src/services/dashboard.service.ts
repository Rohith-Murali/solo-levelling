import { AppError } from "../errors/app-error.js";
import { User } from "../models/user.model.js";
import type { CharacterRecord, ProgressionEventRecord } from "../models/user.model.js";
import { characterAvatars } from "./character-catalog.js";

const progressionEventTitles: Record<string, string> = {
  QUEST_COMPLETED: "Quest completed",
  CHARACTER_XP_GAINED: "Character XP gained",
  CHARACTER_LEVEL_INCREASED: "Level increased",
  RANK_PROMOTED: "Rank promoted",
  TITLE_UNLOCKED: "Title unlocked",
  SKILL_ACQUIRED: "Skill acquired",
  SKILL_XP_GAINED: "Skill XP gained",
  SKILL_LEVEL_INCREASED: "Skill level increased",
  SKILL_UNLOCK_TOKEN_EARNED: "Skill unlock token earned",
  MILESTONE_COMPLETED: "Milestone completed",
  GOAL_COMPLETED: "Goal completed",
};

function getLevelProgress(level: number, totalXp: number) {
  const completedLevels = level - 1;
  const xpAtLevelStart =
    completedLevels * 100 + 25 * completedLevels * (completedLevels - 1);

  return {
    currentLevelXp: Math.max(0, totalXp - xpAtLevelStart),
    xpToNextLevel: 100 + 50 * completedLevels,
  };
}

function progressionActivity(
  character: CharacterRecord,
  event: ProgressionEventRecord,
) {
  const quest = character.quests?.find(
    (candidate) => candidate.id === event.relatedEntityId,
  );
  const skill = character.skills?.find(
    (candidate) => candidate.id === event.relatedEntityId,
  );
  const gainedXp =
    event.type === "CHARACTER_XP_GAINED" ||
    event.type === "SKILL_XP_GAINED"
      ? event.xpChange ?? null
      : null;
  const description =
    event.type === "QUEST_COMPLETED"
      ? quest?.title ?? "A quest was completed."
      : event.type === "CHARACTER_XP_GAINED"
        ? `${gainedXp ?? 0} character XP earned.`
        : event.type === "SKILL_XP_GAINED"
          ? `${skill?.name ?? "A skill"} gained ${gainedXp ?? 0} XP.`
          : event.type === "RANK_PROMOTED"
            ? `Rank changed to ${String(event.newValue ?? "a new rank")}.`
            : event.type === "TITLE_UNLOCKED"
              ? `Unlocked ${String(event.newValue ?? "a new title")}.`
              : event.type === "SKILL_ACQUIRED"
                ? `${String((event.newValue as { name?: string } | undefined)?.name ?? "A new skill")} is now available.`
                : progressionEventTitles[event.type] ?? "Progression updated.";

  return {
    id: event.id,
    type: event.type,
    title: progressionEventTitles[event.type] ?? "Progression update",
    description,
    createdAt: event.occurredAt.toISOString(),
    xpGained: gainedXp,
  };
}

function progressionOverview(character: CharacterRecord, now = new Date()) {
  const cutoff = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);
  const recentEvents = (character.progressionEvents ?? []).filter(
    (event) => event.occurredAt >= cutoff,
  );
  const xpByDate = new Map<string, number>();
  for (const event of recentEvents) {
    if (event.type !== "CHARACTER_XP_GAINED" || event.xpChange == null) {
      continue;
    }
    const date = event.occurredAt.toISOString().slice(0, 10);
    xpByDate.set(date, (xpByDate.get(date) ?? 0) + event.xpChange);
  }

  return {
    period: "LAST_30_DAYS",
    characterXpEarned: recentEvents
      .filter((event) => event.type === "CHARACTER_XP_GAINED")
      .reduce((total, event) => total + (event.xpChange ?? 0), 0),
    questsCompleted: recentEvents.filter(
      (event) => event.type === "QUEST_COMPLETED",
    ).length,
    goalsCompleted: recentEvents.filter(
      (event) => event.type === "GOAL_COMPLETED",
    ).length,
    milestonesCompleted: recentEvents.filter(
      (event) => event.type === "MILESTONE_COMPLETED",
    ).length,
    xpTrend: [...xpByDate.entries()]
      .sort(([first], [second]) => first.localeCompare(second))
      .map(([date, xp]) => ({ date, xp })),
  };
}

function toDashboard(character: CharacterRecord) {
  const totalXp = character.totalXp ?? character.xp;
  const characterProgress = getLevelProgress(character.level, totalXp);
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
      totalXp,
      ...characterProgress,
      skillUnlockTokens: character.skillUnlockTokens,
      stats: character.stats ?? { strength: 1, intelligence: 1, vitality: 1, discipline: 1, perception: 1 },
    },
    statistics: {
      completedQuestCount: character.quests?.filter((quest) => quest.completed).length ?? 0,
      activeQuestCount: character.quests?.filter((quest) => !quest.completed).length ?? 0,
      acquiredSkillCount: character.skills?.length || 1,
      achievementCount: 0,
      completedGoalCount: character.goals?.filter((goal) => goal.completed).length ?? 0,
      completedMilestoneCount: character.milestones?.filter((milestone) => milestone.completed).length ?? 0,
    },
    activeQuests: [],
    skills: (character.skills?.length ? character.skills : [character.startingSkill]).map((skill) => ({
      id: skill.id,
      name: skill.name,
      level: skill.level,
      currentLevelXp: skill.xp,
      xpToNextLevel: 100 + 50 * (skill.level - 1),
    })),
    progressionOverview: progressionOverview(character),
    recentActivity: (character.progressionEvents ?? [])
      .slice()
      .sort((first, second) => second.occurredAt.getTime() - first.occurredAt.getTime())
      .map((event) => progressionActivity(character, event)),
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
