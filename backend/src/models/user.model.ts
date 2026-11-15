import { model, Schema } from "mongoose";

export interface UserRecord {
  email: string;
  passwordHash: string;
}

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
  },
  { timestamps: true },
);

userSchema.index({ email: 1 }, { unique: true });

export const User = model<UserRecord>("User", userSchema);
