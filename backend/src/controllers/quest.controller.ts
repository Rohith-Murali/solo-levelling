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
    createGoal: async (request: Request, response: Response) =>
      response.status(201).json({
        data: await service.createGoal(identity(request), request.body),
      }),
    updateGoal: async (
      request: Request<{ goalId: string }>,
      response: Response,
    ) =>
      response.status(200).json({
        data: { goal: await service.updateGoal(identity(request), request.params.goalId, request.body) },
      }),
    deleteGoal: async (
      request: Request<{ goalId: string }>,
      response: Response,
    ) =>
      response.status(200).json({
        data: { goal: await service.deleteGoal(identity(request), request.params.goalId) },
      }),
    createMilestone: async (
      request: Request<{ goalId: string }>,
      response: Response,
    ) =>
      response.status(201).json({
        data: await service.createMilestone(
          identity(request),
          request.params.goalId,
          request.body,
        ),
      }),
    updateMilestone: async (
      request: Request<{ goalId: string; milestoneId: string }>,
      response: Response,
    ) =>
      response.status(200).json({
        data: { milestone: await service.updateMilestone(identity(request), request.params.goalId, request.params.milestoneId, request.body) },
      }),
    deleteMilestone: async (
      request: Request<{ goalId: string; milestoneId: string }>,
      response: Response,
    ) =>
      response.status(200).json({
        data: { milestone: await service.deleteMilestone(identity(request), request.params.goalId, request.params.milestoneId) },
      }),
    createGoalQuest: async (
      request: Request<{ goalId: string }>,
      response: Response,
    ) =>
      response.status(201).json({
        data: { quest: await service.createGoalQuest(identity(request), request.params.goalId, request.body) },
      }),
    updateGoalQuest: async (
      request: Request<{ goalId: string; questId: string }>,
      response: Response,
    ) =>
      response.status(200).json({
        data: { quest: await service.updateGoalQuest(identity(request), request.params.goalId, request.params.questId, request.body) },
      }),
    deleteGoalQuest: async (
      request: Request<{ goalId: string; questId: string }>,
      response: Response,
    ) =>
      response.status(200).json({
        data: { quest: await service.deleteGoalQuest(identity(request), request.params.goalId, request.params.questId) },
      }),
    createSideQuest: async (request: Request, response: Response) =>
      response.status(201).json({
        data: { quest: await service.createSideQuest(identity(request), request.body) },
      }),
    archiveGoal: async (
      request: Request<{ goalId: string }>,
      response: Response,
    ) =>
      response.status(200).json({
        data: { goal: await service.archiveGoal(identity(request), request.params.goalId) },
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
