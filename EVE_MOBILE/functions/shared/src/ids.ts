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

export const FUNCTION_IDS = {
  onUserCreate: 'onUserCreate',
  partnerView: 'partnerView',
  partnerInvites: 'partnerInvites',
  sendChatMessage: 'sendChatMessage',
  chatSystemMessages: 'chatSystemMessages',
  aiProxy: 'aiProxy',
  notifications: 'notifications',
} as const;
