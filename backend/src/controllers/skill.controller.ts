import type { Request, Response } from "express";
import { AppError } from "../errors/app-error.js";
import type { SkillService } from "../services/skill.service.js";
import type { AcquireSkillBody } from "../validators/skill.validators.js";

export function createSkillController(service: SkillService) {
  const userId = (request: Request): string => {
    if (!request.authIdentity) throw new AppError(401, "AUTHENTICATION_REQUIRED", "Sign in to continue.");
    return request.authIdentity.userId;
  };
  return {
    library: (_request: Request, response: Response) => response.status(200).json({ data: { skills: service.library() } }),
    acquire: async (request: Request<Record<string, string>, unknown, AcquireSkillBody>, response: Response) => response.status(201).json({ data: { skill: await service.acquire(userId(request), request.body) } }),
  };
}
