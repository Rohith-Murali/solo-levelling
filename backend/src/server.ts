import "dotenv/config";
import { createServer } from "node:http";
import { createApp } from "./app.js";
import { EnvironmentConfigurationError, loadConfig } from "./config/env.js";
import { logger } from "./config/logger.js";
import { connectToDatabase, disconnectFromDatabase } from "./database/connection.js";

async function startServer(): Promise<void> {
  const config = loadConfig();
  logger.level = config.LOG_LEVEL;
  await connectToDatabase(config.MONGODB_URI);

  const server = createServer(createApp(config.corsOrigins));
  server.on("error", (error: Error) => {
    logger.error({ errorType: error.name }, "HTTP server error");
    process.exitCode = 1;
  });

  try {
    await new Promise<void>((resolve, reject) => {
      const onListening = (): void => {
        server.off("error", onError);
        logger.info({ port: config.PORT }, "API server listening");
        resolve();
      };
      const onError = (error: Error): void => {
        server.off("listening", onListening);
        reject(error);
      };

      server.once("listening", onListening);
      server.once("error", onError);
      server.listen(config.PORT);
    });
  } catch (error) {
    await disconnectFromDatabase();
    throw error;
  }

  let isShuttingDown = false;
  const shutdown = (signal: NodeJS.Signals): void => {
    if (isShuttingDown) {
      return;
    }

    isShuttingDown = true;
    logger.info({ signal }, "Shutting down");
    const closeServer = new Promise<void>((resolve, reject) => {
      server.close((error) => (error ? reject(error) : resolve()));
    });

    void Promise.all([closeServer, disconnectFromDatabase()])
      .then(() => logger.info("Shutdown complete"))
      .catch((error: unknown) => {
        logger.error({ errorType: error instanceof Error ? error.name : "UnknownError" }, "Shutdown failed");
        process.exitCode = 1;
      });
  };

  process.once("SIGINT", shutdown);
  process.once("SIGTERM", shutdown);
}

startServer().catch((error: unknown) => {
  const details =
    error instanceof EnvironmentConfigurationError
      ? { message: error.message }
      : { errorType: error instanceof Error ? error.name : "UnknownError" };
  logger.fatal(
    details,
    "Failed to start API server",
  );
  process.exitCode = 1;
});
