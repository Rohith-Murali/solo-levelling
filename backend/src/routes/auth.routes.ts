import { Router } from "express";
import { rateLimit } from "express-rate-limit";
import { createAuthController } from "../controllers/auth.controller.js";
import { authenticate } from "../middleware/authenticate.js";
import { validateBody } from "../middleware/validate-body.js";
import { createAuthService } from "../services/auth.service.js";
import {
  loginBodySchema,
  logoutBodySchema,
  refreshBodySchema,
  registerBodySchema,
} from "../validators/auth.validators.js";

export function createAuthRouter(jwtSecret: string) {
  const router = Router();
  const controller = createAuthController(createAuthService(jwtSecret));
  const attemptLimiter = rateLimit({
    windowMs: 15 * 60 * 1000,
    limit: 10,
    skipSuccessfulRequests: true,
    standardHeaders: "draft-8",
    legacyHeaders: false,
    handler: (_request, response) => {
      response.status(429).json({
        error: { code: "RATE_LIMITED", message: "Too many authentication attempts. Try again later." },
      });
    },
  });

  router.post("/register", attemptLimiter, validateBody(registerBodySchema), controller.register);
  router.post("/login", attemptLimiter, validateBody(loginBodySchema), controller.login);
  router.post("/refresh", attemptLimiter, validateBody(refreshBodySchema), controller.refresh);
  router.post("/logout", validateBody(logoutBodySchema), controller.logout);
  router.get("/me", authenticate(jwtSecret), controller.currentUser);

  return router;
}
