import { z } from "zod";

const EnvironmentSchema = z
  .object({
    NODE_ENV: z.enum(["development", "test", "production"]).default("development"),
    PORT: z.coerce.number().int().min(1).max(65535).default(3000),
    MONGODB_URI: z.string().min(1),
    JWT_SECRET: z.string().refine((value) => Buffer.byteLength(value, "utf8") >= 32, {
      message: "must be at least 32 bytes",
    }),
    CORS_ORIGINS: z.string().default(""),
    LOG_LEVEL: z.enum(["fatal", "error", "warn", "info", "debug", "trace", "silent"]).default("info"),
  })
  .superRefine((config, context) => {
    if (config.NODE_ENV !== "production") {
      return;
    }

    const origins = config.CORS_ORIGINS.split(",")
      .map((origin) => origin.trim())
      .filter(Boolean);
    if (origins.length === 0) {
      context.addIssue({
        code: "custom",
        path: ["CORS_ORIGINS"],
        message: "must contain at least one origin in production",
      });
      return;
    }

    for (const origin of origins) {
      const parsed = URL.parse(origin);
      if (!parsed || parsed.protocol !== "https:" || !parsed.host) {
        context.addIssue({
          code: "custom",
          path: ["CORS_ORIGINS"],
          message: "production origins must use HTTPS",
        });
        break;
      }
    }
  });

export class EnvironmentConfigurationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "EnvironmentConfigurationError";
  }
}

export function loadConfig(source: Record<string, string | undefined> = process.env) {
  const result = EnvironmentSchema.safeParse(source);

  if (!result.success) {
    const issues = result.error.issues
      .map((issue) => `${issue.path.join(".") || "environment"}: ${issue.message}`)
      .join("; ");
    throw new EnvironmentConfigurationError(`Invalid environment configuration: ${issues}`);
  }

  return {
    ...result.data,
    corsOrigins: result.data.CORS_ORIGINS.split(",")
      .map((origin) => origin.trim())
      .filter(Boolean),
  };
}
