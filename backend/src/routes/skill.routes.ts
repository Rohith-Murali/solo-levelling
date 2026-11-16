import { Router } from "express";
import { authenticate } from "../middleware/authenticate.js";
import { validateBody } from "../middleware/validate-body.js";
import { createSkillController } from "../controllers/skill.controller.js";
import { createSkillService } from "../services/skill.service.js";
import { acquireSkillBodySchema } from "../validators/skill.validators.js";

export function createSkillRouter(jwtSecret: string) {
  const router = Router();
  const controller = createSkillController(createSkillService());
  router.use(authenticate(jwtSecret));
  router.get("/library", controller.library);
  router.post("/acquire", validateBody(acquireSkillBodySchema), controller.acquire);
  return router;
}
