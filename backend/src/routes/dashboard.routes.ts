import { Router } from "express";
import { createDashboardController } from "../controllers/dashboard.controller.js";
import { authenticate } from "../middleware/authenticate.js";
import { createDashboardService } from "../services/dashboard.service.js";

export function createDashboardRouter(jwtSecret: string) {
  const router = Router();
  const controller = createDashboardController(createDashboardService());

  router.get("/", authenticate(jwtSecret), controller.get);

  return router;
}
