import { z } from "zod";

export const activateTemplateBodySchema = z.object({}).strict();
export type ActivateTemplateBody = z.infer<typeof activateTemplateBodySchema>;

const difficultySchema = z.enum(["EASY", "NORMAL", "MEDIUM", "HARD", "EPIC"]);
const statSchema = z.enum(["strength", "intelligence", "vitality", "discipline", "perception"]);

const questInputSchema = z.object({
  title: z.string().trim().min(1).max(120),
  description: z.string().trim().max(1000).optional(),
  difficulty: difficultySchema.optional(),
  objectives: z.array(z.string().trim().min(1).max(200)).max(20).optional(),
  statContributions: z.array(statSchema).min(1).max(2).optional(),
}).strict();

export const createGoalBodySchema = z.object({
  title: z.string().trim().min(1).max(120),
  description: z.string().trim().max(1000).optional().default(""),
  primarySkillId: z.string().trim().min(1).max(64).optional(),
  skillName: z.string().trim().min(1).max(80).optional(),
  milestones: z.array(z.object({
    title: z.string().trim().min(1).max(120),
    description: z.string().trim().max(1000).optional(),
    quests: z.array(questInputSchema).max(50).optional(),
  }).strict()).max(20).optional(),
}).strict().refine((body) => body.primarySkillId || body.skillName, "Choose or create exactly one associated skill.");

export const createMilestoneBodySchema = z.object({
  title: z.string().trim().min(1).max(120),
  description: z.string().trim().max(1000).optional(),
  quests: z.array(questInputSchema).max(50).optional().default([]),
}).strict();

export const updateGoalBodySchema = z.object({
  title: z.string().trim().min(1).max(120).optional(),
  description: z.string().trim().max(1000).optional(),
}).strict().refine((body) => body.title !== undefined || body.description !== undefined, "Provide a goal field to update.");

export const updateMilestoneBodySchema = z.object({
  title: z.string().trim().min(1).max(120).optional(),
  description: z.string().trim().max(1000).optional(),
}).strict().refine((body) => body.title !== undefined || body.description !== undefined, "Provide a milestone field to update.");

export const createGoalQuestBodySchema = questInputSchema.extend({
  milestoneId: z.string().trim().min(1).max(64).optional(),
}).strict();

export const updateGoalQuestBodySchema = z.object({
  title: z.string().trim().min(1).max(120).optional(),
  description: z.string().trim().max(1000).optional(),
  difficulty: difficultySchema.optional(),
  milestoneId: z.string().trim().max(64).nullable().optional(),
  objectives: z.array(z.string().trim().min(1).max(200)).max(20).optional(),
  statContributions: z.array(statSchema).min(1).max(2).optional(),
}).strict().refine((body) =>
  body.title !== undefined ||
  body.description !== undefined ||
  body.difficulty !== undefined ||
  body.milestoneId !== undefined ||
  body.objectives !== undefined ||
  body.statContributions !== undefined,
"Provide a quest field to update.");

export const createSideQuestBodySchema = z.object({
  title: z.string().trim().min(1).max(120),
  description: z.string().trim().max(1000).optional(),
  difficulty: difficultySchema.optional(),
  primarySkillId: z.string().trim().min(1).max(64).optional(),
  skillName: z.string().trim().min(1).max(80).optional(),
  objectives: z.array(z.string().trim().min(1).max(200)).max(20).optional(),
  statContributions: z.array(statSchema).min(1).max(2).optional(),
}).strict().refine((body) => body.primarySkillId || body.skillName, "Choose or create exactly one associated skill.");
