export type PublicUser = {
  id: string;
  email: string;
  hasCharacter: boolean;
};

export type AuthIdentity = {
  userId: string;
  email: string;
};

export type AuthTokens = {
  user: PublicUser;
  accessToken: string;
  refreshToken: string;
  tokenType: "Bearer";
  expiresIn: number;
};
