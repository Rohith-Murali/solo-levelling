import assert from "node:assert/strict";
import test from "node:test";
import request from "supertest";
import { createApp } from "../dist/app.js";
import { User } from "../dist/models/user.model.js";
import { createAccessToken } from "../dist/services/token.service.js";
import { createCharacterService } from "../dist/services/character.service.js";
import { createCharacterBodySchema } from "../dist/validators/character.validators.js";

const jwtSecret = "a".repeat(32);
const userId = "507f1f77bcf86cd799439011";
const app = createApp({ NODE_ENV: "development", corsOrigins: [], JWT_SECRET: jwtSecret });
const authorization = async () => ({
  authorization: `Bearer ${await createAccessToken(
    { id: userId, email: "hunter@example.com", hasCharacter: false },
    jwtSecret,
  )}`,
});

test("character options require authentication and return supported choices", async () => {
  const unauthenticated = await request(app).get("/api/characters/options");
  assert.equal(unauthenticated.status, 401);

  const response = await request(app)
    .get("/api/characters/options")
    .set(await authorization());
  assert.equal(response.status, 200);
  assert.deepEqual(
    response.body.data.avatars.map((avatar) => avatar.imagePath),
    ["avatars/Avatar 1.png", "avatars/Avatar 2.png", "avatars/Avatar 3.png"],
  );
  assert.equal(response.body.data.startingSkills.length, 7);
  assert.deepEqual(response.body.data.initialProgression, {
    level: 1,
    xp: 0,
    rank: "E",
    skillUnlockTokens: 0,
    skillLevel: 1,
    skillXp: 0,
  });
});

test("character creation validates choices and rejects client progression", async () => {
  const headers = await authorization();
  const invalidAvatar = await request(app)
    .post("/api/characters")
    .set(headers)
    .send({
      name: "Hunter",
      avatarId: "custom-avatar",
      startingSkillId: "programming",
    });
  assert.equal(invalidAvatar.status, 400);

  const clientProgression = createCharacterBodySchema.safeParse({
    name: "Hunter",
    avatarId: "avatar-01",
    startingSkillId: "programming",
    level: 99,
    xp: 100000,
  });
  assert.equal(clientProgression.success, false);
});

test("character is persisted in one account update with server-owned progression", async () => {
  const originalFindOneAndUpdate = User.findOneAndUpdate;
  const originalFindById = User.findById;
  let updateFilter;
  let updateDocument;

  try {
    User.findOneAndUpdate = async (filter, update) => {
      updateFilter = filter;
      updateDocument = update;
      return { id: userId };
    };

    const character = await createCharacterService().create(
      userId,
      "  Hunter  ",
      "avatar-01",
      "programming",
    );

    assert.equal(updateFilter._id, userId);
    assert.deepEqual(updateFilter.character, { $exists: false });
    assert.deepEqual(updateDocument.$set.character, character);
    assert.equal(character.name, "Hunter");
    assert.equal(character.level, 1);
    assert.equal(character.xp, 0);
    assert.equal(character.rank, "E");
    assert.equal(character.title, "Shadow Initiate");
    assert.deepEqual(character.titleHistory, ["Shadow Initiate"]);
    assert.equal(character.skillUnlockTokens, 0);
    assert.deepEqual(character.startingSkill, {
      id: "programming",
      name: "Programming",
      level: 1,
      xp: 0,
    });
    assert.ok(character.createdAt instanceof Date);
    assert.equal(character.updatedAt, character.createdAt);

    User.findOneAndUpdate = async () => null;
    User.findById = () => ({
      select: async () => ({ character }),
    });
    await assert.rejects(
      createCharacterService().create(
        userId,
        "Another",
        "avatar-01",
        "focus",
      ),
      (error) => error.statusCode === 409 && error.code === "CHARACTER_ALREADY_EXISTS",
    );
  } finally {
    User.findOneAndUpdate = originalFindOneAndUpdate;
    User.findById = originalFindById;
  }
});
