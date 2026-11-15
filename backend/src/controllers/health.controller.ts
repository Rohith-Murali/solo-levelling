import type { Request, Response } from "express";
import { getReadinessStatus } from "../services/health.service.js";

export function getLiveness(_request: Request, response: Response): void {
  response.status(200).json({ data: { status: "ok" } });
}

export function getReadiness(_request: Request, response: Response): void {
  const readiness = getReadinessStatus();
  response.status(readiness.status === "ready" ? 200 : 503).json({ data: readiness });
}
