import { Types } from "mongoose";
import { jwtVerify, SignJWT } from "jose";
import type { AuthIdentity, PublicUser } from "../types/auth.js";

export const ACCESS_TOKEN_TTL_SECONDS = 15 * 60;

const tokenIssuer = "solo-levelling-api";
const tokenAudience = "solo-levelling-app";

export async function createAccessToken(user: PublicUser, secret: string): Promise<string> {
  return new SignJWT({ email: user.email })
    .setProtectedHeader({ alg: "HS256" })
    .setIssuer(tokenIssuer)
    .setAudience(tokenAudience)
    .setSubject(user.id)
    .setIssuedAt()
    .setExpirationTime(`${ACCESS_TOKEN_TTL_SECONDS}s`)
    .sign(new TextEncoder().encode(secret));
}

export async function verifyAccessToken(token: string, secret: string): Promise<AuthIdentity> {
  const { payload } = await jwtVerify(token, new TextEncoder().encode(secret), {
    algorithms: ["HS256"],
    issuer: tokenIssuer,
    audience: tokenAudience,
  });

  if (!payload.sub || !Types.ObjectId.isValid(payload.sub) || typeof payload.email !== "string") {
    throw new Error("Access token is missing required claims.");
  }

  return { userId: payload.sub, email: payload.email };
}
