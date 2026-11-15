import type { Request, Response } from "express";
import type { ParamsDictionary } from "express-serve-static-core";
import { AppError } from "../errors/app-error.js";
import type { AuthService } from "../services/auth.service.js";
import type { LoginBody, LogoutBody, RefreshBody, RegisterBody } from "../validators/auth.validators.js";

type BodyRequest<T> = Request<ParamsDictionary, unknown, T>;

export function createAuthController(authService: AuthService) {
  return {
    register: async (request: BodyRequest<RegisterBody>, response: Response): Promise<void> => {
      const tokens = await authService.register(request.body.email, request.body.password);
      response.status(201).json({ data: tokens });
    },

    login: async (request: BodyRequest<LoginBody>, response: Response): Promise<void> => {
      const tokens = await authService.login(request.body.email, request.body.password);
      response.status(200).json({ data: tokens });
    },

    refresh: async (request: BodyRequest<RefreshBody>, response: Response): Promise<void> => {
      const tokens = await authService.refresh(request.body.refreshToken);
      response.status(200).json({ data: tokens });
    },

    logout: async (request: BodyRequest<LogoutBody>, response: Response): Promise<void> => {
      await authService.logout(request.body.refreshToken);
      response.status(200).json({ data: { loggedOut: true } });
    },

    currentUser: async (request: Request, response: Response): Promise<void> => {
      const identity = request.authIdentity;
      if (!identity) {
        throw new AppError(401, "AUTHENTICATION_REQUIRED", "Sign in to continue.");
      }

      const user = await authService.getCurrentUser(identity.userId);
      if (!user) {
        throw new AppError(401, "INVALID_ACCESS_TOKEN", "Your session is invalid or expired.");
      }

      response.status(200).json({ data: { user } });
    },
  };
}
