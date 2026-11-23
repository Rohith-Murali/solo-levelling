import assert from "node:assert/strict";
import test from "node:test";
import { ProgressionEngine, defaultProgressionConfig } from "../dist/core/progression/index.js";
import { createQuestController } from "../dist/controllers/quest.controller.js";
import { User } from "../dist/models/user.model.js";
import { characterVersionFilter } from "../dist/services/character-version-filter.js";
import { createQuestService } from "../dist/services/quest.service.js";

const skill = { id: "focus", name: "Focus", description: "Train attention." };

function createCharacterRecord(overrides = {}) {
  const now = new Date();
  return {
    id: "character-1",
    name: "Hunter",
    avatarId: "avatar-01",
    level: 1,
    xp: 0,
    totalXp: 0,
    rank: "E",
    title: "Shadow Initiate",
    titleHistory: ["Shadow Initiate"],
    skillUnlockTokens: 0,
    version: 0,
    startingSkill: { id: "focus", name: "Focus", level: 1, xp: 0 },
    skills: [
      {
        id: "focus",
        name: "Focus",
        description: "Train attention.",
        category: "STARTING",
        level: 1,
        xp: 0,
        totalXp: 0,
        acquiredAt: now,
        acquisitionSource: "CHARACTER_CREATION",
        status: "ACTIVE",
      },
    ],
    goals: [],
    milestones: [],
    quests: [],
    progressionEvents: [],
    createdAt: now,
    updatedAt: now,
    ...overrides,
  };
}

test("progresses character XP with carryover and independent skill XP", () => {
  const engine = new ProgressionEngine();
  const initial = engine.createInitialState("character-1", skill);
  const result = engine.processQuestCompletion(initial, { questId: "quest-1", primarySkillId: "focus" });

  assert.equal(result.characterXpGained, 100);
  assert.equal(result.state.level, 2);
  assert.equal(result.state.xp, 0);
  assert.equal(result.state.totalXp, 100);
  assert.equal(result.state.skills.focus.xp, 50);
  assert.equal(result.state.skills.focus.totalXp, 50);
  assert.equal(result.state.rank, "E");
  assert.equal(result.state.title, "Shadow Initiate");
  assert.ok(result.events.some((event) => event.type === "SKILL_XP_GAINED"));
});

test("supports multiple levels, rank/title promotion, and calculated unlock tokens", () => {
  const engine = new ProgressionEngine();
  const initial = engine.createInitialState("character-1", skill);
  const result = engine.awardXp({ ...initial, level: 4, xp: 0, totalXp: 450, rank: "E", title: "Shadow Initiate" }, 700, "quest-1");

  assert.equal(result.state.level, 6);
  assert.equal(result.state.xp, 150);
  assert.equal(result.state.rank, "D");
  assert.equal(result.state.title, "Shadow Walker");
  assert.equal(result.newlyEarnedUnlockTokens, 1);
  assert.deepEqual(result.characterLevelUps, [5, 6]);
  assert.deepEqual(result.newlyUnlockedTitles, ["Shadow Walker"]);
});

test("duplicate completion is idempotent", () => {
  const engine = new ProgressionEngine();
  const initial = engine.createInitialState("character-1", skill);
  const first = engine.processQuestCompletion(initial, { questId: "quest-1", primarySkillId: "focus" });
  const duplicate = engine.processQuestCompletion(first.state, { questId: "quest-1", primarySkillId: "focus" });

  assert.equal(duplicate.alreadyCompleted, true);
  assert.equal(duplicate.characterXpGained, 0);
  assert.equal(duplicate.state.totalXp, first.state.totalXp);
});

test("configuration changes formulas and title/rank definitions without engine changes", () => {
  const config = {
    ...defaultProgressionConfig,
    skillXpMultiplier: 0.6,
    ranks: [...defaultProgressionConfig.ranks, { name: "SS", minimumLevel: 50 }],
    titles: [...defaultProgressionConfig.titles, { name: "Beyond Shadow", rank: "SS" }],
  };
  const engine = new ProgressionEngine(config);
  const state = engine.createInitialState("character-1", skill);
  const result = engine.processQuestCompletion(state, { questId: "quest-1", primarySkillId: "focus" });

  assert.equal(result.skillXpGained, 60);
  assert.equal(result.state.skills.focus.xp, 60);
});

test("rejects incomplete quests and awards no skill XP for an unacquired skill", () => {
  const engine = new ProgressionEngine();
  const initial = engine.createInitialState("character-1", skill);
  assert.throws(() => engine.processQuestCompletion(initial, { questId: "quest-1", requiredObjectiveCount: 1, completedObjectiveCount: 0 }));
  const result = engine.processQuestCompletion(initial, { questId: "quest-2", primarySkillId: "missing" });
  assert.equal(result.characterXpGained, 100);
  assert.equal(result.skillXpGained, 0);
});

test("repeated template activation is an idempotent success", async () => {
  const originalFindById = User.findById;
  const character = createCharacterRecord({
    quests: [
      {
        id: "existing-body-quest",
        title: "Existing body quest",
        description: "Already activated.",
        type: "MAIN",
        difficulty: "EASY",
        primarySkillId: "fitness",
        objectives: [],
        completed: false,
        sourceTemplateId: "body",
      },
    ],
  });
  character.skills.push({
    id: "fitness",
    name: "Fitness",
    description: "Build a sustainable foundation for physical health.",
    category: "PHYSICAL",
    level: 1,
    xp: 0,
    totalXp: 0,
    acquiredAt: new Date(),
    acquisitionSource: "QUEST_TEMPLATE",
    status: "ACTIVE",
  });

  try {
    User.findById = () => ({
      select: async () => ({ character }),
    });

    assert.deepEqual(
      await createQuestService().activateTemplate("user-1", "body"),
      { alreadyActive: true },
    );
  } finally {
    User.findById = originalFindById;
  }
});

test("repeated activation acquires a missing template skill without duplicating quests", async () => {
  const originalFindById = User.findById;
  const originalFindOneAndUpdate = User.findOneAndUpdate;
  let character = createCharacterRecord({
    quests: [
      {
        id: "existing-body-quest",
        title: "Existing body quest",
        description: "Already activated.",
        type: "MAIN",
        difficulty: "EASY",
        primarySkillId: "fitness",
        objectives: [],
        completed: false,
        sourceTemplateId: "body",
      },
    ],
  });

  try {
    User.findById = () => ({
      select: async () => ({ character }),
    });
    User.findOneAndUpdate = async (_filter, update) => {
      if (update.$set.character) {
        character = update.$set.character;
      }
      return { character };
    };

    const result = await createQuestService().activateTemplate("user-1", "body");

    assert.equal(result.alreadyActive, true);
    assert.equal(character.quests.length, 1);
    assert.equal(character.skills.length, 2);
    assert.equal(character.skills.find((item) => item.id === "fitness").acquisitionSource, "QUEST_TEMPLATE");
  } finally {
    User.findById = originalFindById;
    User.findOneAndUpdate = originalFindOneAndUpdate;
  }
});

test("template activation recovers when another request activates it concurrently", async () => {
  const originalFindById = User.findById;
  const originalFindOneAndUpdate = User.findOneAndUpdate;
  let latestCharacter = createCharacterRecord();

  try {
    User.findById = () => ({
      select: async () => ({ character: latestCharacter }),
    });
    User.findOneAndUpdate = async (_filter, update) => {
      latestCharacter = update.$set.character;
      return null;
    };

    assert.deepEqual(
      await createQuestService().activateTemplate("user-1", "body"),
      { alreadyActive: true },
    );
  } finally {
    User.findById = originalFindById;
    User.findOneAndUpdate = originalFindOneAndUpdate;
  }
});

test("template activation remains a conflict when a concurrent update did not activate it", async () => {
  const originalFindById = User.findById;
  const originalFindOneAndUpdate = User.findOneAndUpdate;
  let reads = 0;
  const initialCharacter = createCharacterRecord();

  try {
    User.findById = () => ({
      select: async () => ({
        character: {
          ...initialCharacter,
          version: reads++ === 0 ? 0 : 1,
        },
      }),
    });
    User.findOneAndUpdate = async () => null;

    await assert.rejects(
      createQuestService().activateTemplate("user-1", "body"),
      (error) => error.code === "CONCURRENT_UPDATE",
    );
  } finally {
    User.findById = originalFindById;
    User.findOneAndUpdate = originalFindOneAndUpdate;
  }
});

test("template activation returns success status for an idempotent retry", async () => {
  const controller = createQuestController({
    activateTemplate: async () => ({ alreadyActive: true }),
  });
  const response = {
    statusCode: null,
    status(code) {
      this.statusCode = code;
      return this;
    },
    json(body) {
      this.body = body;
      return this;
    },
  };

  await controller.activateTemplate(
    {
      authIdentity: { userId: "user-1" },
      params: { templateId: "body" },
    },
    response,
  );

  assert.equal(response.statusCode, 200);
  assert.deepEqual(response.body.data, { alreadyActive: true });
});

test("legacy version zero updates also match records without a stored version", () => {
  assert.deepEqual(characterVersionFilter(0), {
    $or: [
      { "character.version": 0 },
      { "character.version": { $exists: false } },
    ],
  });
  assert.deepEqual(characterVersionFilter(undefined), {
    $or: [
      { "character.version": 0 },
      { "character.version": { $exists: false } },
    ],
  });
});

test("custom side quest normalizes legacy starting skill and completes with stats", async () => {
  const originalFindById = User.findById;
  const originalFindOneAndUpdate = User.findOneAndUpdate;
  const now = new Date();
  let character = createCharacterRecord({
    createdAt: now,
    updatedAt: now,
    skills: [],
  });

  try {
    User.findById = () => ({
      select: async () => ({ character }),
    });
    User.findOneAndUpdate = async (_filter, update) => {
      if (update.$set.character) {
        character = update.$set.character;
      }
      return { character };
    };

    const service = createQuestService();
    const quest = await service.createSideQuest("user-1", {
      title: "Practice chess",
      description: "Solve a tactical puzzle.",
      difficulty: "HARD",
      skillName: "Chess",
      objectives: ["Solve a puzzle"],
      statContributions: ["intelligence", "perception"],
    });

    const objective = quest.objectives[0];
    await service.completeObjective("user-1", quest.id, objective.id);
    const completion = await service.complete("user-1", quest.id);

    assert.equal(completion.alreadyCompleted, false);
    assert.equal(character.stats.intelligence, 4);
    assert.equal(character.stats.perception, 4);
    assert.equal(character.quests.find((item) => item.id === quest.id).completed, true);
    assert.equal(
      character.skills.every((item) =>
        item.description !== undefined &&
        item.category !== undefined &&
        item.totalXp !== undefined &&
        item.acquiredAt !== undefined &&
        item.status !== undefined
      ),
      true,
    );
  } finally {
    User.findById = originalFindById;
    User.findOneAndUpdate = originalFindOneAndUpdate;
  }
});

test("quest completion backfills legacy goal and milestone fields", async () => {
  const originalFindById = User.findById;
  const originalFindOneAndUpdate = User.findOneAndUpdate;
  const now = new Date();
  const quest = {
    id: "legacy-quest",
    title: "Complete foundation",
    description: "Complete the foundation.",
    type: "MAIN",
    difficulty: "EASY",
    primarySkillId: "focus",
    objectives: [],
    completed: false,
  };
  let character = createCharacterRecord({
    quests: [quest],
    milestones: [{
      id: "legacy-milestone",
      title: "Foundation",
      description: "",
      questIds: [quest.id],
      completed: false,
    }],
    goals: [{
      id: "legacy-goal",
      title: "Build focus",
      description: "Build focus consistently.",
      milestoneIds: ["legacy-milestone"],
      completed: false,
    }],
  });

  try {
    User.findById = () => ({
      select: async () => ({ character }),
    });
    User.findOneAndUpdate = async (_filter, update) => {
      await new User({
        email: "hunter@example.com",
        passwordHash: "test",
        character: update.$set.character,
      }).validate();
      character = update.$set.character;
      return { character };
    };

    await createQuestService().complete("user-1", quest.id);

    assert.equal(character.milestones[0].description, "Foundation");
    assert.equal(character.goals[0].primarySkillId, "focus");
    assert.equal(character.goals[0].status, "COMPLETED");
    assert.equal(character.goals[0].completed, true);
    assert.ok(character.goals[0].createdAt instanceof Date);
  } finally {
    User.findById = originalFindById;
    User.findOneAndUpdate = originalFindOneAndUpdate;
  }
});

test("template activation grants its skill and quests award both XP types", async () => {
  const originalFindById = User.findById;
  const originalFindOneAndUpdate = User.findOneAndUpdate;
  const now = new Date();
  let character = createCharacterRecord({ createdAt: now, updatedAt: now });

  try {
    User.findById = () => ({
      select: async () =>
        new User({
          email: "hunter@example.com",
          passwordHash: "test",
          character,
        }),
    });
    User.findOneAndUpdate = async (_filter, update) => {
      character = update.$set.character;
      return { character };
    };

    const service = createQuestService();
    const bodyActivation = await service.activateTemplate("user-1", "body");
    assert.equal(bodyActivation.alreadyActive, false);
    assert.equal(bodyActivation.quests.length, 9);
    assert.equal(character.skills.length, 2);
    assert.equal(character.id, "character-1");
    assert.equal(character.name, "Hunter");
    assert.equal(character.skillUnlockTokens, 0);
    assert.equal(
      character.skills.find((item) => item.id === "fitness").acquisitionSource,
      "QUEST_TEMPLATE",
    );

    const bodyQuest = character.quests.find(
      (quest) => quest.sourceTemplateId === "body",
    );
    const bodyCompletion = await service.complete("user-1", bodyQuest.id);
    assert.equal(bodyCompletion.progression.characterXpGained, 100);
    assert.equal(bodyCompletion.progression.skillXpGained, 50);
    assert.equal(character.totalXp, 100);
    assert.equal(character.skills.find((item) => item.id === "fitness").totalXp, 50);

    await service.activateTemplate("user-1", "mind");
    assert.equal(character.skills.length, 2);
    const mindQuest = character.quests.find(
      (quest) => quest.sourceTemplateId === "mind",
    );
    const mindCompletion = await service.complete("user-1", mindQuest.id);
    assert.equal(mindCompletion.progression.characterXpGained, 150);
    assert.equal(mindCompletion.progression.skillXpGained, 75);
    assert.equal(character.skills.find((item) => item.id === "focus").totalXp, 75);
    assert.equal(character.totalXp, 250);
  } finally {
    User.findById = originalFindById;
    User.findOneAndUpdate = originalFindOneAndUpdate;
  }
});
