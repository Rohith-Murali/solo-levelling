import type { Request, Response } from "express";
import { AppError } from "../errors/app-error.js";
import type { DashboardService } from "../services/dashboard.service.js";

export function createDashboardController(
  dashboardService: DashboardService,
) {
  return {
    get: async (request: Request, response: Response): Promise<void> => {
      const identity = request.authIdentity;
      if (!identity) {
        throw new AppError(
          401,
          "AUTHENTICATION_REQUIRED",
          "Sign in to continue.",
        );
      }

      const dashboard = await dashboardService.getForUser(identity.userId);
      response.status(200).json({ data: dashboard });
    },
  };
}
