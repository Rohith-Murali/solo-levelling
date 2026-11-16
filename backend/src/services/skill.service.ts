import { randomUUID } from "node:crypto";
import { AppError } from "../errors/app-error.js";
import { ProgressionEngine, type ProgressionState } from "../core/progression/index.js";
import { User } from "../models/user.model.js";
import type { CharacterRecord } from "../models/user.model.js";
import { characterVersionFilter } from "./character-version-filter.js";
import { startingSkills } from "./character-catalog.js";

function characterFor(user: { character?: CharacterRecord } | null): CharacterRecord {
  if (!user) throw new AppError(401, "INVALID_ACCESS_TOKEN", "Your session is invalid or expired.");
  if (!user.character) throw new AppError(409, "CHARACTER_REQUIRED", "Create a character before acquiring skills.");
  return user.character;
}

export function createSkillService() {
  const engine = new ProgressionEngine();
  return {
    library: () => startingSkills,
    async acquire(userId: string, input: { skillId?: string | undefined; name?: string | undefined; description?: string | undefined; category?: string | undefined }) {
      const user = await User.findById(userId).select("character");
      const character = characterFor(user);
      const catalogSkill = input.skillId ? startingSkills.find((skill) => skill.id === input.skillId) : undefined;
      if (input.skillId && !catalogSkill) throw new AppError(404, "SKILL_NOT_FOUND", "Skill not found in the skill library.");
      const skill = catalogSkill ?? { id: `custom-${randomUUID()}`, name: input.name!, description: input.description!, category: input.category! };
      const state: ProgressionState = {
        characterId: character.id, level: character.level, xp: character.xp, totalXp: character.totalXp ?? character.xp,
        rank: character.rank, title: character.title ?? "Shadow Initiate", titleHistory: character.titleHistory ?? ["Shadow Initiate"], skillUnlockTokens: character.skillUnlockTokens,
        skills: Object.fromEntries((character.skills?.length ? character.skills : [{ ...character.startingSkill, description: "Starting skill", category: "STARTING", totalXp: character.startingSkill.xp, acquiredAt: character.createdAt, acquisitionSource: "CHARACTER_CREATION", status: "ACTIVE" as const }]).map((item) => [item.id, item])), completedQuestIds: new Set((character.quests ?? []).filter((quest) => quest.completed).map((quest) => quest.id)),
      };
      if (state.skills[skill.id]) {
        throw new AppError(409, "SKILL_ALREADY_ACQUIRED", "This skill has already been acquired.");
      }
      if (state.skillUnlockTokens < 1) {
        throw new AppError(409, "INSUFFICIENT_SKILL_UNLOCK_TOKENS", "You need a skill unlock token to acquire this skill.");
      }
      const acquired = engine.acquireSkill(state, skill);
      const now = new Date();
      const nextCharacter: CharacterRecord = { ...character, skillUnlockTokens: acquired.state.skillUnlockTokens, skills: Object.values(acquired.state.skills).map((item) => ({ id: item.id, name: item.name, description: item.description ?? "", category: item.category ?? "CUSTOM", level: item.level, xp: item.xp, totalXp: item.totalXp, acquiredAt: item.acquiredAt, acquisitionSource: item.acquisitionSource, status: item.status })), progressionEvents: [...(character.progressionEvents ?? []), acquired.event], version: (character.version ?? 0) + 1, updatedAt: now };
      const updated = await User.findOneAndUpdate({ _id: userId, ...characterVersionFilter(character.version) }, { $set: { character: nextCharacter } }, { new: true, runValidators: true });
      if (!updated) throw new AppError(409, "CONCURRENT_UPDATE", "The character changed. Please retry.");
      return nextCharacter.skills.find((item) => item.id === skill.id);
    },
  };
}
export type SkillService = ReturnType<typeof createSkillService>;
