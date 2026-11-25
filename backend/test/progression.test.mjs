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
  const result = engine.processQuestCompletion(initial, { questId: "quest-1", difficulty: "EPIC", primarySkillId: "focus" });

  assert.equal(result.characterXpGained, 160);
  assert.equal(result.state.level, 2);
  assert.equal(result.state.xp, 60);
  assert.equal(result.state.totalXp, 160);
  assert.equal(result.state.skills.focus.xp, 80);
  assert.equal(result.state.skills.focus.totalXp, 80);
  assert.equal(result.state.rank, "E");
  assert.equal(result.state.title, "Shadow Initiate");
  assert.equal(result.events.find((event) => event.type === "CHARACTER_XP_GAINED").metadata.xpTransaction.characterLevelAtAward, 1);
  assert.equal(result.events.find((event) => event.type === "SKILL_XP_GAINED").metadata.xpTransaction.amount, 80);
  assert.ok(result.events.some((event) => event.type === "SKILL_XP_GAINED"));
});

test("supports multiple levels, rank/title promotion, and calculated unlock tokens", () => {
  const engine = new ProgressionEngine();
  const initial = engine.createInitialState("character-1", skill);
  const result = engine.awardXp({ ...initial, level: 4, xp: 0, totalXp: 450, rank: "E", title: "Shadow Initiate" }, 2800, "quest-1");

  assert.equal(result.state.level, 11);
  assert.equal(result.state.xp, 0);
  assert.equal(result.state.rank, "C");
  assert.equal(result.state.title, "Veil Walker");
  assert.equal(result.newlyEarnedUnlockTokens, 2);
  assert.deepEqual(result.characterLevelUps, [5, 6, 7, 8, 9, 10, 11]);
  assert.deepEqual(result.newlyUnlockedTitles, ["Veil Walker"]);
});

test("titles change at configured level milestones and end at Shadow Monarch at level 100", () => {
  const engine = new ProgressionEngine();
  const initial = engine.createInitialState("character-1", skill);
  const xpToLevel100 = Array.from({ length: 99 }, (_, index) =>
    defaultProgressionConfig.characterXpRequired(index + 1),
  ).reduce((total, required) => total + required, 0);
  const result = engine.awardXp(initial, xpToLevel100, "level-100");

  assert.equal(initial.title, "Shadow Initiate");
  assert.equal(result.state.level, 100);
  assert.equal(result.state.title, "Shadow Monarch");
  assert.deepEqual(result.newlyUnlockedTitles, [
    "Veil Walker",
    "Shadow Seeker",
    "Nightblade Disciple",
    "Dusk Reclaimer",
    "Stygian Ascendant",
    "Eternal Eclipse",
    "Ashborne Sentinel",
    "Umbra Mortis",
    "Shadow Sovereign",
    "Shadow Monarch",
  ]);
  assert.deepEqual(result.state.titleHistory, ["Shadow Initiate", ...result.newlyUnlockedTitles]);
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
    titles: [
      { name: "Custom Initiate", minimumLevel: 1 },
      { name: "Beyond Shadow", minimumLevel: 2 },
    ],
  };
  const engine = new ProgressionEngine(config);
  const state = engine.createInitialState("character-1", skill);
  const result = engine.awardXp(state, 100, "quest-1", "focus");

  assert.equal(state.title, "Custom Initiate");
  assert.equal(result.state.title, "Beyond Shadow");
  assert.equal(result.skillXpGained, 60);
  assert.equal(result.state.skills.focus.xp, 60);
});

test("completes quests and awards no skill XP for an unacquired skill", () => {
  const engine = new ProgressionEngine();
  const initial = engine.createInitialState("character-1", skill);
  const completed = engine.processQuestCompletion(initial, { questId: "quest-1" });
  assert.equal(completed.characterXpGained, 40);
  const result = engine.processQuestCompletion(initial, { questId: "quest-2", primarySkillId: "missing" });
  assert.equal(result.characterXpGained, 40);
  assert.equal(result.skillXpGained, 0);
});

test("scales all four quest difficulties using the pre-award character level", () => {
  const engine = new ProgressionEngine();
  const expected = new Map([
    [1, [15, 40, 80, 160]],
    [10, [35, 94, 188, 375]],
    [20, [49, 130, 259, 518]],
    [50, [76, 202, 404, 808]],
    [100, [107, 284, 569, 1137]],
  ]);
  const difficulties = ["EASY", "NORMAL", "HARD", "EPIC"];

  for (const [level, rewards] of expected) {
    let state = engine.createInitialState(`character-${level}`, skill);
    for (let currentLevel = 1; currentLevel < level; currentLevel++) {
      state = engine.awardXp(
        state,
        defaultProgressionConfig.characterXpRequired(currentLevel),
        `reach-${level}-${currentLevel}`,
      ).state;
    }

    difficulties.forEach((difficulty, index) => {
      const result = engine.processQuestCompletion(state, {
        questId: `level-${level}-${difficulty}`,
        difficulty,
        primarySkillId: "focus",
      });
      assert.equal(result.characterXpGained, rewards[index]);
      assert.equal(result.events.find((event) => event.type === "CHARACTER_XP_GAINED").metadata.xpTransaction.characterLevelAtAward, level);
      assert.equal(result.skillXpGained, Math.round(rewards[index] * 0.5));
    });
  }
});

test("scales milestone and goal bonuses and records their ledger sources", () => {
  const engine = new ProgressionEngine();
  let state = engine.createInitialState("character-10", skill);
  for (let level = 1; level < 10; level++) {
    state = engine.awardXp(
      state,
      defaultProgressionConfig.characterXpRequired(level),
      `reach-level-${level + 1}`,
    ).state;
  }

  const milestone = engine.awardCompletionBonus(
    state,
    "milestone-1",
    "MILESTONE_COMPLETED",
  );
  const goal = engine.awardCompletionBonus(
    milestone.state,
    "goal-1",
    "GOAL_COMPLETED",
  );

  assert.equal(milestone.characterXpGained, 188);
  assert.equal(goal.characterXpGained, 469);
  assert.equal(milestone.events[0].metadata.xpTransaction.sourceType, "MILESTONE");
  assert.equal(goal.events[0].metadata.xpTransaction.sourceType, "GOAL");
  assert.equal(goal.events[0].metadata.xpTransaction.characterLevelAtAward, 10);
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
      statContributions: ["intelligence", "perception"],
    });

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

test("adding a quest to a completed goal reopens the goal and normalizes legacy fields", async () => {
  const originalFindById = User.findById;
  const originalFindOneAndUpdate = User.findOneAndUpdate;
  const now = new Date();
  let character = createCharacterRecord({
    quests: [{
      id: "legacy-quest",
      title: "Legacy quest",
      description: "",
      type: "MAIN",
      difficulty: "EASY",
      primarySkillId: "focus",
      completed: true,
    }],
    goals: [{
      id: "completed-goal",
      title: "Completed goal",
      description: "Add another quest.",
      milestoneIds: [],
      completed: true,
      status: "COMPLETED",
      createdAt: now,
      completedAt: now,
    }],
  });

  try {
    User.findById = () => ({
      select: async () => ({ character }),
    });
    User.findOneAndUpdate = async (_filter, update) => {
      const nextCharacter = {
        ...character,
        goals: update.$set["character.goals"],
        quests: update.$set["character.quests"],
        milestones: update.$set["character.milestones"],
        version: update.$set["character.version"],
        updatedAt: update.$set["character.updatedAt"],
      };
      await new User({
        email: "hunter@example.com",
        passwordHash: "test",
        character: nextCharacter,
      }).validate();
      character = nextCharacter;
      return { character };
    };

    const quest = await createQuestService().createGoalQuest(
      "user-1",
      "completed-goal",
      { title: "A fresh start", difficulty: "NORMAL" },
    );

    assert.equal(quest.title, "A fresh start");
    assert.equal(character.goals[0].status, "ACTIVE");
    assert.equal(character.goals[0].completed, false);
    assert.deepEqual(character.quests[0].statContributions, []);
    assert.equal(character.quests.length, 2);
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

    const service = createQuestService();
    await service.complete("user-1", quest.id);

    assert.equal(character.milestones[0].description, "Foundation");
    assert.equal(character.goals[0].primarySkillId, "focus");
    assert.equal(character.goals[0].status, "COMPLETED");
    assert.equal(character.goals[0].completed, true);
    assert.ok(character.goals[0].createdAt instanceof Date);
    assert.equal(character.totalXp, 295);
    assert.equal(character.progressionEvents.filter((event) => event.metadata?.xpTransaction).length, 4);
    assert.deepEqual(
      character.progressionEvents
        .filter((event) => event.metadata?.xpTransaction)
        .map((event) => event.metadata.xpTransaction.sourceType),
      ["QUEST", "QUEST", "MILESTONE", "GOAL"],
    );
    const transactionCount = character.progressionEvents.filter(
      (event) => event.metadata?.xpTransaction,
    ).length;
    const duplicate = await service.complete("user-1", quest.id);
    assert.equal(duplicate.alreadyCompleted, true);
    assert.equal(
      character.progressionEvents.filter((event) => event.metadata?.xpTransaction).length,
      transactionCount,
    );
  } finally {
    User.findById = originalFindById;
    User.findOneAndUpdate = originalFindOneAndUpdate;
  }
});

