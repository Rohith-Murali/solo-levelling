import cors from "cors";
import express from "express";
import { rateLimit } from "express-rate-limit";
import helmet from "helmet";
import { pinoHttp } from "pino-http";
import { logger } from "./config/logger.js";
import { errorHandler } from "./middleware/error-handler.js";
import { notFoundHandler } from "./middleware/not-found.js";
import { healthRouter } from "./routes/health.routes.js";

export function createApp(corsOrigins: readonly string[] = []) {
  const app = express();

  app.use(pinoHttp({ logger }));
  app.use(helmet());
  app.use(cors({ origin: corsOrigins.length > 0 ? [...corsOrigins] : false }));
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
  app.use(notFoundHandler);
  app.use(errorHandler);

  return app;
}
