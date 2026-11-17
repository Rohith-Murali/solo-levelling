import cors from "cors";
import express from "express";
import { rateLimit } from "express-rate-limit";
import helmet from "helmet";
import { pinoHttp } from "pino-http";
import { logger } from "./config/logger.js";
import { createAuthRouter } from "./routes/auth.routes.js";
import { createCharacterRouter } from "./routes/character.routes.js";
import { createDashboardRouter } from "./routes/dashboard.routes.js";
import { errorHandler } from "./middleware/error-handler.js";
import { notFoundHandler } from "./middleware/not-found.js";
import { healthRouter } from "./routes/health.routes.js";
import { createQuestRouter } from "./routes/quest.routes.js";
import { createSkillRouter } from "./routes/skill.routes.js";

type AppConfig = {
  NODE_ENV: "development" | "test" | "production";
  corsOrigins: readonly string[];
  JWT_SECRET: string;
};

function isDevelopmentLoopbackOrigin(origin: string | undefined, nodeEnv: AppConfig["NODE_ENV"]): boolean {
  if (nodeEnv !== "development" || origin === undefined) {
    return false;
  }

  try {
    const parsedOrigin = new URL(origin);
    return (
      parsedOrigin.protocol === "http:" &&
      parsedOrigin.origin === origin &&
      ["localhost", "127.0.0.1", "[::1]"].includes(parsedOrigin.hostname)
    );
  } catch {
    return false;
  }
}

export function createApp(config: AppConfig) {
  const app = express();

  app.use(
    pinoHttp({
      logger,
      customLogLevel: (_request, response, error) => {
        if (response.statusCode === 503) return "warn";
        if (error || response.statusCode >= 500) return "error";
        if (response.statusCode >= 400) return "warn";
        return "info";
      },
      customErrorObject: (_request, response, _error, value) =>
        response.statusCode === 503 ? { statusCode: response.statusCode } : value,
    }),
  );
  app.use(helmet());
  app.use(
    cors({
      origin: (origin, callback) => {
        callback(
          null,
          (origin !== undefined && config.corsOrigins.includes(origin)) ||
            isDevelopmentLoopbackOrigin(origin, config.NODE_ENV),
        );
      },
    }),
  );
  app.use(express.json({ limit: "1mb" }));
  app.use(
    "/api",
    rateLimit({
      windowMs: 15 * 60 * 1000,
      limit: 100,
      standardHeaders: "draft-8",
      legacyHeaders: false,
      skip: (request) => request.path.startsWith("/health/"),
      handler: (_request, response) => {
        response.status(429).json({
          error: { code: "RATE_LIMITED", message: "Too many requests." },
        });
      },
    }),
  );
  app.use("/api/health", healthRouter);
  app.use("/api/auth", createAuthRouter(config.JWT_SECRET));
  app.use("/api/characters", createCharacterRouter(config.JWT_SECRET));
  app.use("/api/dashboard", createDashboardRouter(config.JWT_SECRET));
  app.use("/api/quests", createQuestRouter(config.JWT_SECRET));
  app.use("/api/skills", createSkillRouter(config.JWT_SECRET));
  app.use(notFoundHandler);
  app.use(errorHandler);

  return app;
}
