type CharacterVersionClause =
  | { "character.version": number }
  | { "character.version": { $exists: false } };

export function characterVersionFilter(version: number | undefined) {
  const expectedVersion = version ?? 0;
  const clauses: CharacterVersionClause[] = [
    { "character.version": expectedVersion },
  ];
  if (expectedVersion === 0) {
    clauses.push({ "character.version": { $exists: false } });
  }
  return { $or: clauses };
}
