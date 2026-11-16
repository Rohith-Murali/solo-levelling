import { Router } from "express";
import { createCharacterController } from "../controllers/character.controller.js";
import { authenticate } from "../middleware/authenticate.js";
import { validateBody } from "../middleware/validate-body.js";
import { createCharacterService } from "../services/character.service.js";
import { createCharacterBodySchema } from "../validators/character.validators.js";

export function createCharacterRouter(jwtSecret: string) {
  const router = Router();
  const controller = createCharacterController(createCharacterService());

  router.use(authenticate(jwtSecret));
  router.get("/options", controller.options);
  router.post("/", validateBody(createCharacterBodySchema), controller.create);

  return router;
}
