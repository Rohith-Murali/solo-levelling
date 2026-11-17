import type { CharacterRecord } from "../models/user.model.js";

type MongooseCharacterRecord = CharacterRecord & {
  toObject: () => CharacterRecord;
};

function isMongooseCharacterRecord(
  character: CharacterRecord,
): character is MongooseCharacterRecord {
  return "toObject" in character && typeof character.toObject === "function";
}

export function toPlainCharacterRecord(
  character: CharacterRecord,
): CharacterRecord {
  return isMongooseCharacterRecord(character) ? character.toObject() : character;
}
