import { randomUUID } from "node:crypto";

export interface QuestTemplate {
  readonly id: string;
  readonly name: string;
  readonly description: string;
  readonly minimumLevel: number;
  readonly goal: { readonly title: string; readonly description: string };
  readonly milestones: readonly { readonly title: string; readonly quests: readonly { readonly title: string; readonly description: string; readonly type: "MAIN" | "SIDE"; readonly difficulty: string; readonly primarySkillId: string; readonly statContributions: readonly string[] }[] }[];
}

const template = (id: string, name: string, minimumLevel: number, skill: string): QuestTemplate => ({
  id, name, description: `A structured ${name.toLowerCase()} progression path.`, minimumLevel,
  goal: { title: `${name} Ascension`, description: `Build consistent progress in ${name.toLowerCase()}.` },
  milestones: ["Foundation", "Momentum", "Mastery"].map((milestone, milestoneIndex) => ({
    title: milestone,
    quests: ["Begin", "Build", "Prove"].map((verb, questIndex) => ({
      title: `${verb} ${name} ${milestoneIndex + 1}.${questIndex + 1}`,
      description: `Complete the ${verb.toLowerCase()} step for ${name.toLowerCase()}.`,
      type: "MAIN",
      difficulty: questIndex === 0 ? "EASY" : questIndex === 1 ? "NORMAL" : "HARD",
      primarySkillId: skill,
      statContributions: milestoneIndex === 0 ? ["discipline"] : milestoneIndex === 1 ? ["intelligence", "perception"] : ["vitality", "discipline"],
    })),
  })),
});

export const questTemplates: readonly QuestTemplate[] = [
  template("body", "Body", 1, "fitness"),
  template("mind", "Mind", 1, "focus"),
  template("career", "Career", 3, "programming"),
  template("soul", "Soul", 5, "communication"),
];

export function activateTemplate(templateId: string) {
  const source = questTemplates.find((candidate) => candidate.id === templateId);
  if (!source) return undefined;
  const goalId = randomUUID();
  const milestones = source.milestones.map((milestone) => {
    const milestoneId = randomUUID();
    const quests = milestone.quests.map((quest) => ({
      id: randomUUID(), title: quest.title, description: quest.description, type: quest.type,
      difficulty: quest.difficulty, primarySkillId: quest.primarySkillId,
      goalId: goalId, milestoneId: milestoneId, statContributions: [...quest.statContributions],
      completed: false, sourceTemplateId: source.id,
    }));
    return { id: milestoneId, title: milestone.title, description: `${milestone.title} phase of ${source.name}.`, questIds: quests.map((quest) => quest.id), completed: false, quests };
  });
  return {
    goal: {
      id: goalId,
      title: source.goal.title,
      description: source.goal.description,
      primarySkillId: source.milestones[0]?.quests[0]?.primarySkillId ?? "",
      milestoneIds: milestones.map((milestone) => milestone.id),
      completed: false,
      status: "ACTIVE",
      createdAt: new Date(),
    },
    milestones: milestones.map(({ quests: _quests, ...milestone }) => milestone),
    quests: milestones.flatMap((milestone) => milestone.quests),
  };
}
