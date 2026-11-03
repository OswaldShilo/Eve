export const DATABASE_ID = 'eve';

export const TABLES = {
  profiles: 'profiles',
  lifeStageProfiles: 'life_stage_profiles',
  symptomLogs: 'symptom_logs',
  preferences: 'preferences',
  partnerLinks: 'partner_links',
  partnerPermissions: 'partner_permissions',
  partnerViews: 'partner_views',
  partnerLookups: 'partner_lookups',
  chatMessages: 'chat_messages',
} as const;

export type TableId = (typeof TABLES)[keyof typeof TABLES];

/**
 * Deployed functions. The free Cloud plan allows two, so the original seven
 * run as jobs inside these (eveEvents/src/dispatch.ts, eveApi/src/dispatch.ts).
 */
export const FUNCTION_IDS = {
  events: 'eveEvents',
  api: 'eveApi',
} as const;

/** Values of the `route` field the app sends to eveApi. */
export const API_ROUTES = {
  partnerInvites: 'partnerInvites',
  sendChatMessage: 'sendChatMessage',
  aiProxy: 'aiProxy',
} as const;

export type ApiRoute = (typeof API_ROUTES)[keyof typeof API_ROUTES];
