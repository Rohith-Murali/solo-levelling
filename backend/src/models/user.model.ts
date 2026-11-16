import { model, Schema } from "mongoose";

export interface StartingSkillRecord {
  id: string;
  name: string;
  level: number;
  xp: number;
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
