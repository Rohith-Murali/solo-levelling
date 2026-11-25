import { ProgressionEngine } from "../core/progression/index.js";

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

const initialState = new ProgressionEngine().createInitialState("character-options", {
  id: "initial-skill",
  name: "Initial skill",
});
const initialSkill = initialState.skills["initial-skill"]!;

export const initialProgression = {
  level: initialState.level,
  xp: initialState.xp,
  skillUnlockTokens: initialState.skillUnlockTokens,
  skillLevel: initialSkill.level,
  skillXp: initialSkill.xp,
};
