import { AppError } from "../errors/app-error.js";
import { defaultProgressionConfig } from "../core/progression/config.js";
import type { XpTransaction } from "../core/progression/models.js";
import { xpForLevel } from "../core/progression/resolvers.js";
import { resolveTitle } from "../core/progression/resolvers.js";
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

function getLevelProgress(level: number, currentLevelXp: number) {
  return {
    currentLevelXp,
    xpToNextLevel: xpForLevel(level, defaultProgressionConfig),
  };
}

function isXpTransaction(value: unknown): value is XpTransaction {
  if (typeof value !== "object" || value === null) return false;
  const transaction = value as Record<string, unknown>;
  return (
    (transaction.sourceType === "QUEST" ||
      transaction.sourceType === "MILESTONE" ||
      transaction.sourceType === "GOAL") &&
    typeof transaction.sourceId === "string" &&
    (transaction.rewardType === "CHARACTER_XP" ||
      transaction.rewardType === "SKILL_XP") &&
    (transaction.skillId === null || typeof transaction.skillId === "string") &&
    typeof transaction.amount === "number" &&
    typeof transaction.characterLevelAtAward === "number"
  );
}

function xpTransactions(character: CharacterRecord) {
  return (character.progressionEvents ?? [])
    .flatMap((event) => {
      const transaction = event.metadata?.xpTransaction;
      if (!isXpTransaction(transaction)) return [];
      return [{
        id: event.id,
        ...transaction,
        createdAt: event.occurredAt.toISOString(),
      }];
    })
    .sort((first, second) => second.createdAt.localeCompare(first.createdAt));
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
    relatedEntityId: event.relatedEntityId ?? null,
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
  const characterProgress = getLevelProgress(character.level, character.xp);
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
      title: character.title ?? resolveTitle(character.level),
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
    titleTiers: defaultProgressionConfig.titles.map((title, index, titles) => ({
      name: title.name,
      minimumLevel: title.minimumLevel,
      maximumLevel: titles[index + 1]?.minimumLevel
        ? titles[index + 1]!.minimumLevel - 1
        : null,
    })),
    xpTransactions: xpTransactions(character),
    skills: (character.skills?.length ? character.skills : [character.startingSkill]).map((skill) => ({
      id: skill.id,
      name: skill.name,
      level: skill.level,
      currentLevelXp: skill.xp,
      totalXp: "totalXp" in skill ? skill.totalXp : skill.xp,
      xpToNextLevel: xpForLevel(skill.level, defaultProgressionConfig),
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
