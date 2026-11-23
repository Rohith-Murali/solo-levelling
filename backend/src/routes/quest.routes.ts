import { Router } from "express";
import { authenticate } from "../middleware/authenticate.js";
import { createQuestController } from "../controllers/quest.controller.js";
import { createQuestService } from "../services/quest.service.js";
import { validateBody } from "../middleware/validate-body.js";
import { createGoalBodySchema, createMilestoneBodySchema, createSideQuestBodySchema } from "../validators/quest.validators.js";

export function createQuestRouter(jwtSecret: string) {
  const router = Router();
  const controller = createQuestController(createQuestService());
  router.use(authenticate(jwtSecret));
  router.get("/templates", controller.templates);
  router.post("/templates/:templateId/activate", controller.activateTemplate);
  router.post("/goals", validateBody(createGoalBodySchema), controller.createGoal);
  router.post("/goals/:goalId/milestones", validateBody(createMilestoneBodySchema), controller.createMilestone);
  router.post("/goals/:goalId/archive", controller.archiveGoal);
  router.post("/side", validateBody(createSideQuestBodySchema), controller.createSideQuest);
  router.get("/", controller.list);
  router.post("/:questId/objectives/:objectiveId/complete", controller.completeObjective);
  router.post("/:questId/complete", controller.complete);
  return router;
}
