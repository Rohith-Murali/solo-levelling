import type { Request, Response } from "express";
import { AppError } from "../errors/app-error.js";
import type { CharacterService } from "../services/character.service.js";
import { characterAvatars, initialProgression, startingSkills } from "../services/character-catalog.js";
import type { CreateCharacterBody } from "../validators/character.validators.js";

export function createCharacterController(characterService: CharacterService) {
  return {
    options: (_request: Request, response: Response): void => {
      response.status(200).json({
        data: { avatars: characterAvatars, startingSkills, initialProgression },
      });
    },

    create: async (request: Request<unknown, unknown, CreateCharacterBody>, response: Response): Promise<void> => {
      const identity = request.authIdentity;
      if (!identity) {
        throw new AppError(401, "AUTHENTICATION_REQUIRED", "Sign in to continue.");
      }

      const character = await characterService.create(
        identity.userId,
        request.body.name,
        request.body.avatarId,
        request.body.startingSkillId,
      );

      response.status(201).json({
        data: {
          character: {
            id: character.id,
            name: character.name,
            avatarId: character.avatarId,
            level: character.level,
            xp: character.xp,
            rank: character.rank,
            skillUnlockTokens: character.skillUnlockTokens,
          },
          startingSkill: {
            id: character.startingSkill.id,
            name: character.startingSkill.name,
            level: character.startingSkill.level,
            xp: character.startingSkill.xp,
          },
        },
      });
    },
  };
}
