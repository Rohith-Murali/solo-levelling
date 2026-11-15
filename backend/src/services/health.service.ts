import { isDatabaseReady } from "../database/connection.js";

export function getReadinessStatus(): {
  status: "ready" | "not_ready";
  database: "connected" | "disconnected";
} {
  const ready = isDatabaseReady();
  return {
    status: ready ? "ready" : "not_ready",
    database: ready ? "connected" : "disconnected",
  };
}
