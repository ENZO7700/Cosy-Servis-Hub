/** Client-safe WordPress CCT exports (no Node/server secrets). */
export * from "./types";
export {
  validatePatches,
  briefToSectionPatches,
  isForbiddenCopyValue,
} from "./patch";
export {
  briefForgeToSectionPatches,
  type BriefForgeMetaboxLike,
} from "./briefForgeMap";
export {
  PAPI_HAIR_DESIGN_JETENGINE_MAPPINGS,
  mapSalonOsContentToJetEnginePatches,
  type SalonOsContent,
  type SalonOsJetEngineMappings,
} from "./salonos";
