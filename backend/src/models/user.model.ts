import { model, Schema } from "mongoose";

export interface StartingSkillRecord {
  id: string;
  name: string;
  level: number;
  xp: number;
}

export interface SkillRecord extends StartingSkillRecord {
  description: string;
  category: string;
  totalXp: number;
  acquiredAt: Date;
  acquisitionSource: string;
  status: "ACTIVE" | "INACTIVE";
}

export interface ObjectiveRecord {
  id: string;
  title: string;
  completed: boolean;
}

export interface QuestRecord {
  id: string;
  title: string;
  description: string;
  type: "MAIN" | "SIDE";
  difficulty: string;
  primarySkillId?: string;
  objectives: ObjectiveRecord[];
  completed: boolean;
  completedAt?: Date;
  sourceTemplateId?: string;
}

export interface MilestoneRecord {
  id: string;
  title: string;
  questIds: string[];
  completed: boolean;
}

export interface GoalRecord {
  id: string;
  title: string;
  description: string;
  milestoneIds: string[];
  completed: boolean;
}

export interface ProgressionEventRecord {
  id: string;
  type: string;
  relatedEntityId?: string;
  xpChange?: number;
  previousValue?: unknown;
  newValue?: unknown;
  occurredAt: Date;
  metadata?: Record<string, unknown>;
}

export interface CharacterRecord {
  id: string;
  name: string;
  avatarId: string;
  level: number;
  xp: number;
  rank: string;
  skillUnlockTokens: number;
  startingSkill: StartingSkillRecord;
  title: string;
  titleHistory: string[];
  totalXp: number;
  version: number;
  skills: SkillRecord[];
  goals: GoalRecord[];
  milestones: MilestoneRecord[];
  quests: QuestRecord[];
  progressionEvents: ProgressionEventRecord[];
  createdAt: Date;
  updatedAt: Date;
}

export interface UserRecord {
  email: string;
  passwordHash: string;
  character?: CharacterRecord;
}

const startingSkillSchema = new Schema<StartingSkillRecord>(
  {
    id: { type: String, required: true },
    name: { type: String, required: true },
    level: { type: Number, required: true },
    xp: { type: Number, required: true },
  },
  { _id: false },
);

const skillSchema = new Schema<SkillRecord>({
  id: { type: String, required: true },
  name: { type: String, required: true },
  description: { type: String, required: true },
  category: { type: String, required: true },
  level: { type: Number, required: true },
  xp: { type: Number, required: true },
  totalXp: { type: Number, required: true },
  acquiredAt: { type: Date, required: true },
  acquisitionSource: { type: String, required: true },
  status: { type: String, enum: ["ACTIVE", "INACTIVE"], required: true },
}, { _id: false });

const objectiveSchema = new Schema<ObjectiveRecord>({
  id: { type: String, required: true },
  title: { type: String, required: true },
  completed: { type: Boolean, required: true },
}, { _id: false });

const questSchema = new Schema<QuestRecord>({
  id: { type: String, required: true },
  title: { type: String, required: true },
  description: { type: String, required: true },
  type: { type: String, enum: ["MAIN", "SIDE"], required: true },
  difficulty: { type: String, required: true },
  primarySkillId: { type: String, required: false },
  objectives: { type: [objectiveSchema], required: true },
  completed: { type: Boolean, required: true },
  completedAt: { type: Date, required: false },
  sourceTemplateId: { type: String, required: false },
}, { _id: false });

const milestoneSchema = new Schema<MilestoneRecord>({
  id: { type: String, required: true },
  title: { type: String, required: true },
  questIds: { type: [String], required: true },
  completed: { type: Boolean, required: true },
}, { _id: false });

const goalSchema = new Schema<GoalRecord>({
  id: { type: String, required: true },
  title: { type: String, required: true },
  description: { type: String, required: true },
  milestoneIds: { type: [String], required: true },
  completed: { type: Boolean, required: true },
}, { _id: false });

const progressionEventSchema = new Schema<ProgressionEventRecord>({
  id: { type: String, required: true },
  type: { type: String, required: true },
  relatedEntityId: { type: String, required: false },
  xpChange: { type: Number, required: false },
  previousValue: { type: Schema.Types.Mixed, required: false },
  newValue: { type: Schema.Types.Mixed, required: false },
  occurredAt: { type: Date, required: true },
  metadata: { type: Schema.Types.Mixed, required: false },
}, { _id: false });

const characterSchema = new Schema<CharacterRecord>(
  {
    id: { type: String, required: true },
    name: { type: String, required: true, maxlength: 24 },
    avatarId: { type: String, required: true },
    level: { type: Number, required: true },
    xp: { type: Number, required: true },
    rank: { type: String, required: true },
    skillUnlockTokens: { type: Number, required: true },
    startingSkill: { type: startingSkillSchema, required: true },
    title: { type: String, required: true, default: "Shadow Initiate" },
    titleHistory: { type: [String], required: true, default: ["Shadow Initiate"] },
    totalXp: { type: Number, required: true, default: 0 },
    version: { type: Number, required: true, default: 0 },
    skills: { type: [skillSchema], required: true, default: [] },
    goals: { type: [goalSchema], required: true, default: [] },
    milestones: { type: [milestoneSchema], required: true, default: [] },
    quests: { type: [questSchema], required: true, default: [] },
    progressionEvents: { type: [progressionEventSchema], required: true, default: [] },
    createdAt: { type: Date, required: true },
    updatedAt: { type: Date, required: true },
  },
  { _id: false },
);

const userSchema = new Schema<UserRecord>(
  {
    email: {
      type: String,
      required: true,
      lowercase: true,
      trim: true,
      maxlength: 254,
    },
    passwordHash: {
      type: String,
      required: true,
      select: false,
    },
    character: {
      type: characterSchema,
      required: false,
    },
  },
  { timestamps: true },
);

userSchema.index({ email: 1 }, { unique: true });

export const User = model<UserRecord>("User", userSchema);
