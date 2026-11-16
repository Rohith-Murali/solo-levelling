import type { Request, Response } from "express";
import { AppError } from "../errors/app-error.js";
import type { QuestService } from "../services/quest.service.js";

export function createQuestController(service: QuestService) {
  const identity = (request: Request): string => {
    if (!request.authIdentity)
      throw new AppError(
        401,
        "AUTHENTICATION_REQUIRED",
        "Sign in to continue.",
      );
    return request.authIdentity.userId;
  };
  return {
    templates: async (request: Request, response: Response) =>
      response
        .status(200)
        .json({
          data: { templates: await service.templates(identity(request)) },
        }),
    activateTemplate: async (
      request: Request<{ templateId: string }>,
      response: Response,
    ) => {
      const activation = await service.activateTemplate(
        identity(request),
        request.params.templateId,
      );
      return response
        .status(activation.alreadyActive ? 200 : 201)
        .json({ data: activation });
    },
    list: async (request: Request, response: Response) =>
      response
        .status(200)
        .json({ data: await service.list(identity(request)) }),
    completeObjective: async (
      request: Request<{ questId: string; objectiveId: string }>,
      response: Response,
    ) =>
      response
        .status(200)
        .json({
          data: {
            objective: await service.completeObjective(
              identity(request),
              request.params.questId,
              request.params.objectiveId,
            ),
          },
        }),
    complete: async (
      request: Request<{ questId: string }>,
      response: Response,
    ) =>
      response
        .status(200)
        .json({
          data: await service.complete(
            identity(request),
            request.params.questId,
          ),
        }),
  };
}
