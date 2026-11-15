import type { ErrorRequestHandler } from "express";
import { logger } from "../config/logger.js";
import { AppError } from "../errors/app-error.js";

export const errorHandler: ErrorRequestHandler = (error, request, response, next) => {
  if (response.headersSent) {
    next(error);
    return;
  }

  const isExpected = error instanceof AppError;
  const isInvalidJson = error instanceof SyntaxError && "body" in error;
  const isOversizedBody =
    typeof error === "object" &&
    error !== null &&
    "type" in error &&
    error.type === "entity.too.large";
  const statusCode = isExpected ? error.statusCode : isInvalidJson ? 400 : isOversizedBody ? 413 : 500;
  const code = isExpected
    ? error.code
    : isInvalidJson
      ? "INVALID_JSON"
      : isOversizedBody
        ? "PAYLOAD_TOO_LARGE"
        : "INTERNAL_SERVER_ERROR";
  const message = isExpected
    ? error.message
    : isInvalidJson
      ? "Request body contains invalid JSON."
      : isOversizedBody
        ? "Request body is too large."
        : "An unexpected error occurred.";

  if (!isExpected && statusCode >= 500) {
    logger.error(
      { errorType: error instanceof Error ? error.name : "UnknownError", method: request.method, path: request.path },
      "Unhandled request error",
    );
  }

  const errorResponse = { error: { code, message }, ...(isExpected && error.details ? { details: error.details } : {}) };
  response.status(statusCode).json(errorResponse);
};
