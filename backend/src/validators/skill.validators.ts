import { z } from "zod";

export const acquireSkillBodySchema = z.object({
  skillId: z.string().trim().min(1).max(64).optional(),
  name: z.string().trim().min(1).max(80).optional(),
  description: z.string().trim().min(1).max(500).optional(),
  category: z.string().trim().min(1).max(40).optional(),
}).strict().refine((body) => body.skillId || (body.name && body.description && body.category), "Choose a library skill or provide custom skill details.");
export type AcquireSkillBody = z.infer<typeof acquireSkillBodySchema>;
