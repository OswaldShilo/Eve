import { readFileSync } from 'node:fs';
import { describe, expect, it } from 'vitest';
import { TABLES, type TableId } from '../src/ids.js';
import type {
  ChatMessageRow,
  LifeStageProfileRow,
  PartnerLinkRow,
  PartnerLookupRow,
  PartnerPermissionsRow,
  PartnerViewRow,
  PreferencesRow,
  ProfileRow,
  SymptomLogRow,
} from '../src/types.js';

interface ConfigTable {
  $id: string;
  databaseId: string;
  rowSecurity: boolean;
  $permissions: string[];
  columns: { key: string; required: boolean; default?: unknown }[];
  indexes: { key: string; columns: string[] }[];
}

const config = JSON.parse(readFileSync(new URL('../../../appwrite.config.json', import.meta.url), 'utf8')) as {
  tables: ConfigTable[];
};
const table = (id: TableId) => {
  const found = config.tables.find((t) => t.$id === id);
  if (!found) throw new Error(`table ${id} missing from appwrite.config.json`);
  return found;
};

// Fully-typed fixtures: TypeScript forces every column to be present, so
// comparing their keys with the config catches drift in either direction.
const fixtures: Record<TableId, object> = {
  profiles: { name: '', age: null, height: null, weight: null, country: null, lifeStage: null } satisfies ProfileRow,
  life_stage_profiles: {
    type: null, cycleLength: null, periodLength: null, flow: null, cycleSymptoms: [], cycleGoals: [],
    nutritionDiet: null, dueDate: null, dueMethod: null, highRisk: null, pregnancyType: null, medications: null,
    allergies: null, prenatalVitamins: null, pregnantSymptoms: [], currentWeek: null, nextAppointmentLabel: null,
    nextAppointmentAt: null, latestMilestone: null, simplifiedSymptoms: [], simplifiedGoals: [],
  } satisfies LifeStageProfileRow,
  symptom_logs: { userId: 'u', date: '', symptoms: [], mood: null, painLevel: null, notes: '' } satisfies SymptomLogRow,
  preferences: {
    selectedGoals: [], dietType: null, foodAllergies: '', cuisines: [], workoutPreference: [],
    enabledReminders: [], enabledHelpAreas: [], selectedTheme: 'default',
  } satisfies PreferencesRow,
  partner_links: {
    partnerUserId: null, relationshipType: null, inviteStatus: 'none', inviteCode: null, invitedAt: null, linkedAt: null,
  } satisfies PartnerLinkRow,
  partner_permissions: { approvedCategories: [], onlyApproveMode: true } satisfies PartnerPermissionsRow,
  partner_views: {
    primaryUserId: 'u', approvedCategories: [], upcomingAppointmentLabel: null, upcomingAppointmentAt: null,
    pregnancyCurrentWeek: null, pregnancyLatestMilestone: null, supportSuggested: null, supportReason: null,
    recentMoodTrend: null, recomputedAt: null,
  } satisfies PartnerViewRow,
  partner_lookups: { primaryUserId: 'u', relationshipType: null, linkedAt: '' } satisfies PartnerLookupRow,
  chat_messages: {
    threadUserId: 'u', senderRole: 'her', senderUserId: null, messageText: '', sentAt: '', type: 'text',
    category: null, sourceLogId: null,
  } satisfies ChatMessageRow,
};

const SERVER_ONLY: TableId[] = ['partner_links', 'partner_views', 'partner_lookups', 'chat_messages'];

describe('appwrite.config.json schema', () => {
  it.each(Object.values(TABLES))('%s exists in database eve with row security on', (id) => {
    const t = table(id);
    expect(t.databaseId).toBe('eve');
    expect(t.rowSecurity).toBe(true);
  });

  it.each(Object.values(TABLES))('%s columns match the TypeScript row type exactly', (id) => {
    expect(table(id).columns.map((c) => c.key).sort()).toEqual(Object.keys(fixtures[id]).sort());
  });

  it('never combines required with a default (Appwrite rejects it)', () => {
    for (const t of config.tables) {
      for (const c of t.columns) {
        if (c.required) expect(c.default ?? null, `${t.$id}.${c.key}`).toBeNull();
      }
    }
  });

  it.each(SERVER_ONLY)('%s grants no table-level permissions to clients', (id) => {
    expect(table(id).$permissions).toEqual([]);
  });

  it('only symptom_logs lets signed-in users create rows, and grants nothing else table-wide', () => {
    expect(table('symptom_logs').$permissions).toEqual(['create("users")']);
    for (const t of config.tables.filter((x) => x.$id !== 'symptom_logs')) {
      expect(t.$permissions, t.$id).toEqual([]);
    }
  });

  it('indexes the queries the functions run', () => {
    expect(table('symptom_logs').indexes.map((i) => i.columns)).toContainEqual(['userId', 'date']);
    expect(table('chat_messages').indexes.map((i) => i.columns)).toContainEqual(['threadUserId', 'sentAt']);
    expect(table('partner_links').indexes.map((i) => i.columns)).toContainEqual(['inviteCode']);
  });
});
