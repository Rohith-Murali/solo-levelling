import { createHash, randomBytes } from "node:crypto";
import bcrypt from "bcryptjs";
import type { HydratedDocument } from "mongoose";
import { AppError } from "../errors/app-error.js";
import { RefreshSession } from "../models/refresh-session.model.js";
import { User } from "../models/user.model.js";
import type { AuthTokens, PublicUser } from "../types/auth.js";
import type { UserRecord } from "../models/user.model.js";
import { ACCESS_TOKEN_TTL_SECONDS, createAccessToken } from "./token.service.js";

const passwordHashRounds = 12;
const refreshTokenLifetimeMs = 30 * 24 * 60 * 60 * 1000;

function hashRefreshToken(token: string): string {
  return createHash("sha256").update(token).digest("hex");
}

function getPublicUser(user: HydratedDocument<UserRecord>): PublicUser {
  return { id: user.id, email: user.email, hasCharacter: Boolean(user.character) };
}

function isDuplicateKeyError(error: unknown): boolean {
  return typeof error === "object" && error !== null && "code" in error && error.code === 11000;
}

function invalidCredentialsError(): AppError {
  return new AppError(401, "INVALID_CREDENTIALS", "Invalid email or password.");
}

function invalidSessionError(): AppError {
  return new AppError(401, "INVALID_SESSION", "Session expired. Please sign in again.");
}

async function createAuthTokens(
  user: HydratedDocument<UserRecord>,
  refreshToken: string,
  jwtSecret: string,
): Promise<AuthTokens> {
  return {
    user: getPublicUser(user),
    accessToken: await createAccessToken(getPublicUser(user), jwtSecret),
    refreshToken,
    tokenType: "Bearer",
    expiresIn: ACCESS_TOKEN_TTL_SECONDS,
  };
}

async function createSession(user: HydratedDocument<UserRecord>, jwtSecret: string): Promise<AuthTokens> {
  const refreshToken = randomBytes(32).toString("base64url");
  await RefreshSession.create({
    userId: user._id,
    tokenHash: hashRefreshToken(refreshToken),
    expiresAt: new Date(Date.now() + refreshTokenLifetimeMs),
  });

  return createAuthTokens(user, refreshToken, jwtSecret);
}

export function createAuthService(jwtSecret: string) {
  return {
    async register(email: string, password: string): Promise<AuthTokens> {
      const passwordHash = await bcrypt.hash(password, passwordHashRounds);
      let user: HydratedDocument<UserRecord>;

      try {
        user = await User.create({ email, passwordHash });
      } catch (error) {
        if (isDuplicateKeyError(error)) {
          throw new AppError(409, "EMAIL_ALREADY_REGISTERED", "An account with that email already exists.");
        }
        throw error;
      }

      return createSession(user, jwtSecret);
    },

    async login(email: string, password: string): Promise<AuthTokens> {
      const user = await User.findOne({ email }).select("+passwordHash");

      if (!user) {
        await bcrypt.hash(password, passwordHashRounds);
        throw invalidCredentialsError();
      }

      if (!(await bcrypt.compare(password, user.passwordHash))) {
        throw invalidCredentialsError();
      }

      return createSession(user, jwtSecret);
    },

    async refresh(refreshToken: string): Promise<AuthTokens> {
      const nextRefreshToken = randomBytes(32).toString("base64url");
      const now = new Date();
      const session = await RefreshSession.findOneAndUpdate(
        {
          tokenHash: hashRefreshToken(refreshToken),
          expiresAt: { $gt: now },
        },
        {
          $set: {
            tokenHash: hashRefreshToken(nextRefreshToken),
            expiresAt: new Date(now.getTime() + refreshTokenLifetimeMs),
          },
        },
        { new: true },
      );

      if (!session) {
        throw invalidSessionError();
      }

      const user = await User.findById(session.userId);
      if (!user) {
        await RefreshSession.deleteOne({ _id: session._id });
        throw invalidSessionError();
      }

      return createAuthTokens(user, nextRefreshToken, jwtSecret);
    },

    async logout(refreshToken: string): Promise<void> {
      await RefreshSession.deleteOne({ tokenHash: hashRefreshToken(refreshToken) });
    },

    async getCurrentUser(userId: string): Promise<PublicUser | null> {
      const user = await User.findById(userId);
      return user ? getPublicUser(user) : null;
    },
  };
}

export type AuthService = ReturnType<typeof createAuthService>;
