import assert from "node:assert/strict";
import test from "node:test";
import { activateTemplate, questTemplates } from "../dist/services/quest-catalog.js";

test("MVP catalog contains four templates and 36 quests", () => {
  assert.deepEqual(questTemplates.map((template) => template.name), ["Body", "Mind", "Career", "Soul"]);
  assert.equal(questTemplates.reduce((count, template) => count + template.milestones.reduce((milestoneCount, milestone) => milestoneCount + milestone.quests.length, 0), 0), 36);
});

test("template activation creates independent personal IDs and copies", () => {
  const first = activateTemplate("body");
  const second = activateTemplate("body");
  assert.ok(first && second);
  assert.equal(first.quests.length, 9);
  assert.equal(first.milestones.length, 3);
  assert.notEqual(first.goal.id, second.goal.id);
  assert.notEqual(first.quests[0].id, second.quests[0].id);
  assert.equal(first.quests[0].completed, false);
});
