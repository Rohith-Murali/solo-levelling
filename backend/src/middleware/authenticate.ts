import type { RequestHandler } from "express";
import { AppError } from "../errors/app-error.js";
import { verifyAccessToken } from "../services/token.service.js";

export function authenticate(jwtSecret: string): RequestHandler {
  return async (request, _response, next) => {
    const authorization = request.get("authorization");
    if (!authorization?.startsWith("Bearer ")) {
      next(new AppError(401, "AUTHENTICATION_REQUIRED", "Sign in to continue."));
      return;
    }

    try {
      request.authIdentity = await verifyAccessToken(authorization.slice(7).trim(), jwtSecret);
    } catch {
      next(new AppError(401, "INVALID_ACCESS_TOKEN", "Your session is invalid or expired."));
      return;
    }

    next();
  };
}
