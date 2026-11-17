export const characterAvatars = [
  { id: "avatar-01", name: "Avatar 1", imagePath: "avatars/Avatar 1.png" },
  { id: "avatar-02", name: "Avatar 2", imagePath: "avatars/Avatar 2.png" },
  { id: "avatar-03", name: "Avatar 3", imagePath: "avatars/Avatar 3.png" },
] as const;

export const startingSkills = [
  { id: "programming", name: "Programming", description: "Build and understand software through deliberate practice.", category: "TECHNICAL" },
  { id: "problem-solving", name: "Problem Solving", description: "Break challenges down and work toward clear solutions.", category: "COGNITIVE" },
  { id: "communication", name: "Communication", description: "Practice expressing ideas and listening with intention.", category: "PERSONAL" },
  { id: "strength", name: "Strength", description: "Track consistent strength and resistance training.", category: "PHYSICAL" },
  { id: "fitness", name: "Fitness", description: "Build a sustainable foundation for physical health.", category: "PHYSICAL" },
  { id: "focus", name: "Focus", description: "Train attention through intentional, distraction-light work.", category: "COGNITIVE" },
  { id: "financial-management", name: "Financial Management", description: "Develop practical habits for managing money.", category: "PERSONAL" },
] as const;

export const initialProgression = {
  level: 1,
  xp: 0,
  rank: "E",
  skillUnlockTokens: 0,
  skillLevel: 1,
  skillXp: 0,
} as const;
