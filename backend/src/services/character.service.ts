import { randomUUID } from "node:crypto";
import { AppError } from "../errors/app-error.js";
import { User } from "../models/user.model.js";
import type { CharacterRecord } from "../models/user.model.js";
import { characterAvatars, initialProgression, startingSkills } from "./character-catalog.js";

export function createCharacterService() {
  return {
    async create(userId: string, name: string, avatarId: string, startingSkillId: string): Promise<CharacterRecord> {
      const avatar = characterAvatars.find((item) => item.id === avatarId);
      const skill = startingSkills.find((item) => item.id === startingSkillId);
      if (!avatar || !skill) {
        throw new AppError(400, "INVALID_CHARACTER_SELECTION", "Choose an available avatar and starting skill.");
      }

      const now = new Date();
      const character: CharacterRecord = {
        id: randomUUID(),
        name: name.trim(),
        avatarId: avatar.id,
        level: initialProgression.level,
        xp: initialProgression.xp,
        rank: initialProgression.rank,
        skillUnlockTokens: initialProgression.skillUnlockTokens,
        startingSkill: {
          id: skill.id,
          name: skill.name,
          level: initialProgression.skillLevel,
          xp: initialProgression.skillXp,
        },
      stats: { strength: 1, intelligence: 1, vitality: 1, discipline: 1, perception: 1 },
      title: "Shadow Initiate",
      titleHistory: ["Shadow Initiate"],
      totalXp: initialProgression.xp,
      version: 0,
      skills: [{
        id: skill.id,
        name: skill.name,
        description: skill.description,
        category: "STARTING",
        level: initialProgression.skillLevel,
        xp: initialProgression.skillXp,
        totalXp: 0,
        acquiredAt: now,
        acquisitionSource: "CHARACTER_CREATION",
        status: "ACTIVE",
      }],
      goals: [],
      milestones: [],
      quests: [],
      progressionEvents: [],
        createdAt: now,
        updatedAt: now,
      };

      const user = await User.findOneAndUpdate(
        { _id: userId, character: { $exists: false } },
        { $set: { character } },
        { new: true, runValidators: true },
      );
      if (user) {
        return character;
      }

      const existingUser = await User.findById(userId).select("character");
      if (!existingUser) {
        throw new AppError(401, "INVALID_ACCESS_TOKEN", "Your session is invalid or expired.");
      }
      if (existingUser.character) {
        throw new AppError(409, "CHARACTER_ALREADY_EXISTS", "This account already has a character.");
      }

      throw new AppError(409, "CHARACTER_ALREADY_EXISTS", "Character creation could not be completed. Please try again.");
    },
  };
}

export type CharacterService = ReturnType<typeof createCharacterService>;
