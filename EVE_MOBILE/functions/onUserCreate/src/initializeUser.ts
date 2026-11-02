import { RowConflictError, type Db } from '../../shared/src/db.js';
import { TABLES, type TableId } from '../../shared/src/ids.js';
import { ownerEditable, ownerReadOnly } from '../../shared/src/permissions.js';
import type {
  LifeStageProfileRow,
  PartnerLinkRow,
  PartnerPermissionsRow,
  PartnerViewRow,
  PreferencesRow,
  ProfileRow,
} from '../../shared/src/types.js';

interface DefaultRow {
  tableId: TableId;
  data: object;
  permissions: string[];
}

export function defaultRowsFor(uid: string, name: string): DefaultRow[] {
  const profile: ProfileRow = { name, age: null, height: null, weight: null, country: null, lifeStage: null };
  const lifeStage: LifeStageProfileRow = {
    type: null, cycleLength: null, periodLength: null, flow: null, cycleSymptoms: [], cycleGoals: [],
    nutritionDiet: null, dueDate: null, dueMethod: null, highRisk: null, pregnancyType: null, medications: null,
    allergies: null, prenatalVitamins: null, pregnantSymptoms: [], currentWeek: null, nextAppointmentLabel: null,
    nextAppointmentAt: null, latestMilestone: null, simplifiedSymptoms: [], simplifiedGoals: [],
  };
  const preferences: PreferencesRow = {
    selectedGoals: [], dietType: null, foodAllergies: '', cuisines: [], workoutPreference: [],
    enabledReminders: [], enabledHelpAreas: [], selectedTheme: 'default',
  };
  const partnerPermissions: PartnerPermissionsRow = { approvedCategories: [], onlyApproveMode: true };
  const partnerLink: PartnerLinkRow = {
    partnerUserId: null, relationshipType: null, inviteStatus: 'none', inviteCode: null, invitedAt: null, linkedAt: null,
  };
  const partnerView: PartnerViewRow = {
    primaryUserId: uid, approvedCategories: [], upcomingAppointmentLabel: null, upcomingAppointmentAt: null,
    pregnancyCurrentWeek: null, pregnancyLatestMilestone: null, supportSuggested: null, supportReason: null,
    recentMoodTrend: null, recomputedAt: null,
  };

  return [
    { tableId: TABLES.profiles, data: profile, permissions: ownerEditable(uid) },
    { tableId: TABLES.lifeStageProfiles, data: lifeStage, permissions: ownerEditable(uid) },
    { tableId: TABLES.preferences, data: preferences, permissions: ownerEditable(uid) },
    { tableId: TABLES.partnerPermissions, data: partnerPermissions, permissions: ownerEditable(uid) },
    { tableId: TABLES.partnerLinks, data: partnerLink, permissions: ownerReadOnly(uid) },
    { tableId: TABLES.partnerViews, data: partnerView, permissions: ownerReadOnly(uid) },
  ];
}

/** Creates each missing singleton row; never overwrites. Returns what it created. */
export async function initializeUserRows(db: Db, uid: string, name: string): Promise<TableId[]> {
  const created: TableId[] = [];
  for (const row of defaultRowsFor(uid, name)) {
    if (await db.getRow(row.tableId, uid)) continue;
    try {
      await db.createRow(row.tableId, uid, row.data, row.permissions);
      created.push(row.tableId);
    } catch (e) {
      // A concurrent delivery of the same event won the race — fine.
      if (!(e instanceof RowConflictError)) throw e;
    }
  }
  return created;
}
