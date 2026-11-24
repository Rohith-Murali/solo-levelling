import { Router } from "express";
import { authenticate } from "../middleware/authenticate.js";
import { createQuestController } from "../controllers/quest.controller.js";
import { createQuestService } from "../services/quest.service.js";
import { validateBody } from "../middleware/validate-body.js";
import { createGoalBodySchema, createMilestoneBodySchema, createSideQuestBodySchema, createGoalQuestBodySchema, updateGoalBodySchema, updateMilestoneBodySchema, updateGoalQuestBodySchema } from "../validators/quest.validators.js";

export function createQuestRouter(jwtSecret: string) {
  const router = Router();
  const controller = createQuestController(createQuestService());
  router.use(authenticate(jwtSecret));
  router.get("/templates", controller.templates);
  router.post("/templates/:templateId/activate", controller.activateTemplate);
  router.post("/goals", validateBody(createGoalBodySchema), controller.createGoal);
  router.patch("/goals/:goalId", validateBody(updateGoalBodySchema), controller.updateGoal);
  router.delete("/goals/:goalId", controller.deleteGoal);
  router.post("/goals/:goalId/milestones", validateBody(createMilestoneBodySchema), controller.createMilestone);
  router.patch("/goals/:goalId/milestones/:milestoneId", validateBody(updateMilestoneBodySchema), controller.updateMilestone);
  router.delete("/goals/:goalId/milestones/:milestoneId", controller.deleteMilestone);
  router.post("/goals/:goalId/quests", validateBody(createGoalQuestBodySchema), controller.createGoalQuest);
  router.patch("/goals/:goalId/quests/:questId", validateBody(updateGoalQuestBodySchema), controller.updateGoalQuest);
  router.delete("/goals/:goalId/quests/:questId", controller.deleteGoalQuest);
  router.post("/goals/:goalId/archive", controller.archiveGoal);
  router.post("/goals/:goalId/milestones/:milestoneId/complete", controller.completeMilestone);
  router.post("/goals/:goalId/complete", controller.completeGoal);
  router.post("/side", validateBody(createSideQuestBodySchema), controller.createSideQuest);
  router.get("/", controller.list);
  router.post("/:questId/complete", controller.complete);
  return router;
}
