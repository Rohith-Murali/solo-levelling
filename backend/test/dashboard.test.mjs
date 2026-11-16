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
    level: 2,
    xp: 100,
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
      level: 2,
      totalXp: 100,
      currentLevelXp: 0,
      xpToNextLevel: 150,
      skillUnlockTokens: 3,
    });
    assert.equal(response.body.data.skills[0].name, "Focus");
    assert.equal(response.body.data.skills[0].currentLevelXp, 12);
    assert.deepEqual(response.body.data.activeQuests, []);
    assert.deepEqual(response.body.data.recentActivity, []);
    assert.deepEqual(response.body.data.progressionOverview.xpTrend, []);
    assert.equal(
      response.body.data.progressionOverview.characterXpEarned,
      null,
    );
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
