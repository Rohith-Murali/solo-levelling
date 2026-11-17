import { z } from "zod";

export const activateTemplateBodySchema = z.object({}).strict();
export type ActivateTemplateBody = z.infer<typeof activateTemplateBodySchema>;
