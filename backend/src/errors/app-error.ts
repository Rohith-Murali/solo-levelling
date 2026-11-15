export class AppError extends Error {
  constructor(
    public readonly statusCode: number,
    public readonly code: string,
    message: string,
    public readonly details?: readonly { path: string; message: string }[],
  ) {
    super(message);
    this.name = "AppError";
  }
}
