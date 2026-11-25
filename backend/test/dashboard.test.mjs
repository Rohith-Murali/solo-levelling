import assert from "node:assert/strict";
import test from "node:test";
import request from "supertest";
import { createApp } from "../dist/app.js";
import { User } from "../dist/models/user.model.js";
import { createAccessToken } from "../dist/services/token.service.js";
import { createDashboardService } from "../dist/services/dashboard.service.js";

const jwtSecret = "a".repeat(32);
const userId = "507f1f77bcf86cd799439011";
const app = createApp({ NODE_ENV: "development", corsOrigins: [], JWT_SECRET: jwtSecret });

async function authHeader() {
  const token = await createAccessToken(
    { id: userId, email: "hunter@example.com", hasCharacter: true },
    jwtSecret,
  );
  return { authorization: `Bearer ${token}` };
}

function createCharacter() {
  return {
    id: "character-id",
    name: "Hunter",
    avatarId: "avatar-02",
    rank: "D",
    title: "Shadow Initiate",
    level: 2,
    xp: 0,
    skillUnlockTokens: 3,
    startingSkill: {
      id: "focus",
      name: "Focus",
      level: 1,
      xp: 12,
    },
  };
}

test("dashboard endpoint requires authentication", async () => {
  const response = await request(app).get("/api/dashboard");
  assert.equal(response.status, 401);
});

test("dashboard returns persisted character data and honest empty-history state", async () => {
  const originalFindById = User.findById;

  try {
    User.findById = () => ({
      select: async (projection) => {
        assert.equal(projection, "character");
        return { character: createCharacter() };
      },
    });

    const response = await request(app)
      .get("/api/dashboard")
      .set(await authHeader());

    assert.equal(response.status, 200);
    assert.deepEqual(response.body.data.character, {
      id: "character-id",
      name: "Hunter",
      avatarId: "avatar-02",
      avatarImagePath: "avatars/Avatar 2.png",
      rank: "D",
      title: "Shadow Initiate",
      level: 2,
      totalXp: 100,
      currentLevelXp: 0,
      xpToNextLevel: 150,
      skillUnlockTokens: 3,
      stats: {
        strength: 1,
        intelligence: 1,
        vitality: 1,
        discipline: 1,
        perception: 1,
      },
    });
    assert.equal(response.body.data.skills[0].name, "Focus");
    assert.equal(response.body.data.skills[0].currentLevelXp, 12);
    assert.deepEqual(response.body.data.activeQuests, []);
    assert.deepEqual(response.body.data.recentActivity, []);
    assert.deepEqual(response.body.data.progressionOverview.xpTrend, []);
    assert.equal(response.body.data.progressionOverview.characterXpEarned, 0);
    assert.equal(response.body.data.progressionOverview.questsCompleted, 0);
  } finally {
    User.findById = originalFindById;
  }
});

test("dashboard history and skill progress reflect persisted progression events", async () => {
  const originalFindById = User.findById;
  const occurredAt = new Date();
  const character = {
    ...createCharacter(),
    skills: [
      {
        id: "focus",
        name: "Focus",
        level: 2,
        xp: 25,
        totalXp: 125,
        description: "Train attention.",
        category: "COGNITIVE",
        acquiredAt: occurredAt,
        acquisitionSource: "CHARACTER_CREATION",
        status: "ACTIVE",
      },
    ],
    quests: [
      {
        id: "quest-1",
        title: "Complete a focus session",
        completed: true,
        objectives: [],
      },
    ],
    progressionEvents: [
      {
        id: "event-1",
        type: "QUEST_COMPLETED",
        relatedEntityId: "quest-1",
        occurredAt,
      },
      {
        id: "event-2",
        type: "CHARACTER_XP_GAINED",
        relatedEntityId: "quest-1",
        xpChange: 100,
        metadata: {
          xpTransaction: {
            sourceType: "QUEST",
            sourceId: "quest-1",
            rewardType: "CHARACTER_XP",
            skillId: null,
            amount: 100,
            characterLevelAtAward: 2,
          },
        },
        occurredAt,
      },
      {
        id: "event-3",
        type: "SKILL_XP_GAINED",
        relatedEntityId: "focus",
        xpChange: 50,
        metadata: {
          xpTransaction: {
            sourceType: "QUEST",
            sourceId: "quest-1",
            rewardType: "SKILL_XP",
            skillId: "focus",
            amount: 50,
            characterLevelAtAward: 2,
          },
        },
        occurredAt,
      },
    ],
  };

  try {
    User.findById = () => ({
      select: async () => ({ character }),
    });

    const data = await createDashboardService().getForUser(userId);

    assert.equal(data.progressionOverview.characterXpEarned, 100);
    assert.equal(data.progressionOverview.questsCompleted, 1);
    assert.deepEqual(data.progressionOverview.xpTrend, [
      { date: occurredAt.toISOString().slice(0, 10), xp: 100 },
    ]);
    assert.equal(data.recentActivity.length, 3);
    assert.equal(data.skills[0].currentLevelXp, 25);
    assert.equal(data.skills[0].xpToNextLevel, 150);
    assert.deepEqual(
      data.xpTransactions.map((transaction) => [
        transaction.rewardType,
        transaction.amount,
        transaction.characterLevelAtAward,
      ]),
      [
        ["CHARACTER_XP", 100, 2],
        ["SKILL_XP", 50, 2],
      ],
    );
    assert.equal(data.titleTiers.length, 11);
  } finally {
    User.findById = originalFindById;
  }
});

test("dashboard requires a character and does not fabricate one", async () => {
  const originalFindById = User.findById;

  try {
    User.findById = () => ({
      select: async () => ({ character: undefined }),
    });

    await assert.rejects(
      createDashboardService().getForUser(userId),
      (error) =>
        error.statusCode === 409 && error.code === "CHARACTER_REQUIRED",
    );
  } finally {
    User.findById = originalFindById;
  }
});
