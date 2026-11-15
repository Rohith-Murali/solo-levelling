import { model, Schema, Types } from "mongoose";

interface RefreshSessionRecord {
  userId: Types.ObjectId;
  tokenHash: string;
  expiresAt: Date;
}

const refreshSessionSchema = new Schema<RefreshSessionRecord>(
  {
    userId: {
      type: Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },
    tokenHash: {
      type: String,
      required: true,
      unique: true,
    },
    expiresAt: {
      type: Date,
      required: true,
    },
  },
  { timestamps: true },
);

refreshSessionSchema.index({ expiresAt: 1 }, { expireAfterSeconds: 0 });

export const RefreshSession = model<RefreshSessionRecord>("RefreshSession", refreshSessionSchema);
