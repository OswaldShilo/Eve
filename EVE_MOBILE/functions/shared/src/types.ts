// Row shapes for every table in design-spec §10. Datetime columns are ISO
// 8601 strings (that is what TablesDB returns and accepts). Appwrite system
// fields ($id, $permissions, $createdAt, ...) are NOT part of these shapes —
// see `Row` in db.ts.

export const LIFE_STAGES = ['cycle', 'conceive', 'pregnant', 'postpartum', 'menopause'] as const;
export type LifeStage = (typeof LIFE_STAGES)[number];

export const MOODS = ['great', 'good', 'okay', 'low', 'difficult'] as const;
export type Mood = (typeof MOODS)[number];

export const NOTIFICATION_TYPES = [
  'morning',
  'medicine',
  'workout',
  'water',
  'sleep',
  'cycle',
  'appointment',
  'mood',
  'daily_tip',
] as const;
export type NotificationType = (typeof NOTIFICATION_TYPES)[number];

export const AI_HELP_AREAS = [
  'healthQuestions',
  'nutrition',
  'workouts',
  'mentalWellbeing',
  'medicationReminders',
  'doctorPrep',
] as const;
export type AiHelpArea = (typeof AI_HELP_AREAS)[number];

export const THEMES = ['light', 'dark', 'default'] as const;
export type Theme = (typeof THEMES)[number];

export const PERMISSION_CATEGORIES = [
  'appointmentReminders',
  'pregnancyMilestones',
  'supportSuggestions',
  'moodUpdates',
] as const;
export type PermissionCategory = (typeof PERMISSION_CATEGORIES)[number];

export const INVITE_STATUSES = ['none', 'pending', 'accepted', 'declined'] as const;
export type InviteStatus = (typeof INVITE_STATUSES)[number];

// profiles — rowId = uid
export interface ProfileRow {
  name: string;
  age: number | null;
  height: number | null; // centimeters
  weight: number | null; // kilograms
  country: string | null;
  lifeStage: LifeStage | null;
}

// life_stage_profiles — rowId = uid. Flattened: see plan assumption 4.
export interface LifeStageProfileRow {
  type: LifeStage | null;
  // cycle
  cycleLength: number | null;
  periodLength: number | null;
  flow: string | null;
  cycleSymptoms: string[];
  cycleGoals: string[];
  nutritionDiet: string | null;
  // pregnant
  dueDate: string | null;
  dueMethod: string | null;
  highRisk: boolean | null;
  pregnancyType: string | null;
  medications: string | null;
  allergies: string | null;
  prenatalVitamins: boolean | null;
  pregnantSymptoms: string[];
  currentWeek: number | null;
  nextAppointmentLabel: string | null;
  nextAppointmentAt: string | null;
  latestMilestone: string | null;
  // conceive / postpartum / menopause
  simplifiedSymptoms: string[];
  simplifiedGoals: string[];
}

// symptom_logs — rowId = ID.unique(); row permissions owner-only.
export interface SymptomLogRow {
  userId: string;
  date: string;
  symptoms: string[];
  mood: Mood | null;
  painLevel: number | null; // 0-10
  notes: string;
}

// preferences — rowId = uid
export interface PreferencesRow {
  selectedGoals: string[];
  dietType: string | null;
  foodAllergies: string;
  cuisines: string[];
  workoutPreference: string[];
  enabledReminders: NotificationType[];
  enabledHelpAreas: AiHelpArea[];
  selectedTheme: Theme;
}

// partner_links — rowId = primary uid; server-written only.
export interface PartnerLinkRow {
  partnerUserId: string | null;
  relationshipType: string | null;
  inviteStatus: InviteStatus;
  inviteCode: string | null;
  invitedAt: string | null;
  linkedAt: string | null;
}

// partner_permissions — rowId = uid
export interface PartnerPermissionsRow {
  approvedCategories: PermissionCategory[];
  onlyApproveMode: boolean;
}

// partner_views — rowId = primary uid; server-written only. A withheld
// category is a null column (plan assumption 6). Plan 7 owns the values.
export interface PartnerViewRow {
  primaryUserId: string;
  approvedCategories: PermissionCategory[];
  upcomingAppointmentLabel: string | null;
  upcomingAppointmentAt: string | null;
  pregnancyCurrentWeek: number | null;
  pregnancyLatestMilestone: string | null;
  supportSuggested: boolean | null;
  supportReason: 'highPain' | 'multipleSymptoms' | null;
  recentMoodTrend: 'low' | 'neutral' | 'positive' | null;
  recomputedAt: string | null;
}

// partner_lookups — rowId = partner uid; server-written only.
export interface PartnerLookupRow {
  primaryUserId: string;
  relationshipType: string | null;
  linkedAt: string;
}

// chat_messages — server-written only (sendChatMessage / chatSystemMessages).
export type ChatSenderRole = 'her' | 'partner' | 'system';
export type ChatMessageType = 'text' | 'system';

export interface ChatMessageRow {
  threadUserId: string; // the primary user's uid — one thread per couple
  senderRole: ChatSenderRole;
  senderUserId: string | null; // null for system messages
  messageText: string;
  sentAt: string;
  type: ChatMessageType;
  category: 'supportSuggestion' | 'moodUpdate' | null;
  sourceLogId: string | null;
}
