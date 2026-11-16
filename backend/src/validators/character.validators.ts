import { z } from "zod";
import { characterAvatars, startingSkills } from "../services/character-catalog.js";

export const createCharacterBodySchema = z
  .object({
    name: z.string().trim().min(1).max(24),
    avatarId: z.enum(characterAvatars.map((avatar) => avatar.id)),
    startingSkillId: z.enum(startingSkills.map((skill) => skill.id)),
  })
  .strict();

export type CreateCharacterBody = z.infer<typeof createCharacterBodySchema>;
