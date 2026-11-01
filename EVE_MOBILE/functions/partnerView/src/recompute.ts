import type { Db } from '../../shared/src/db.js';
import { TABLES } from '../../shared/src/ids.js';
import { isOwnedBy, readersPermissions } from '../../shared/src/permissions.js';
import {
  PERMISSION_CATEGORIES,
  type LifeStageProfileRow,
  type Mood,
  type PartnerViewRow,
  type PermissionCategory,
  type SymptomLogRow,
} from '../../shared/src/types.js';

/**
 * Known V0 categories are a strict allowlist: shown only when listed.
 * onlyApproveMode governs categories the product does not define yet:
 * withheld when it is on (the safe default), shown when she turned it off.
 */
export function isCategoryApproved(category: string, approvedCategories: readonly string[], onlyApproveMode: boolean): boolean {
  if (approvedCategories.includes(category)) return true;
  if ((PERMISSION_CATEGORIES as readonly string[]).includes(category)) return false;
  return !onlyApproveMode;
}

export function moodToTrend(mood: Mood | null | undefined): 'low' | 'neutral' | 'positive' {
  switch (mood) {
    case 'great':
    case 'good':
      return 'positive';
    case 'low':
    case 'difficult':
      return 'low';
    default:
      return 'neutral';
  }
}

export interface PartnerViewInput {
  perms: { approvedCategories: readonly string[]; onlyApproveMode: boolean };
  lifeStage: Partial<LifeStageProfileRow>;
  latestLog: Pick<SymptomLogRow, 'symptoms' | 'mood' | 'painLevel'> | null;
}

/** Pure projection. Every column is always present; withheld = null. */
export function buildPartnerView(uid: string, input: PartnerViewInput, now: Date): PartnerViewRow {
  const approved = (c: PermissionCategory) =>
    isCategoryApproved(c, input.perms.approvedCategories, input.perms.onlyApproveMode);
  const shown: PermissionCategory[] = [];
  const view: PartnerViewRow = {
    primaryUserId: uid,
    approvedCategories: shown,
    upcomingAppointmentLabel: null,
    upcomingAppointmentAt: null,
    pregnancyCurrentWeek: null,
    pregnancyLatestMilestone: null,
    supportSuggested: null,
    supportReason: null,
    recentMoodTrend: null,
    recomputedAt: now.toISOString(),
  };

  if (approved('appointmentReminders')) {
    shown.push('appointmentReminders');
    view.upcomingAppointmentLabel = input.lifeStage.nextAppointmentLabel ?? null;
    view.upcomingAppointmentAt = input.lifeStage.nextAppointmentAt ?? null;
  }

  if (input.lifeStage.type === 'pregnant' && approved('pregnancyMilestones')) {
    shown.push('pregnancyMilestones');
    view.pregnancyCurrentWeek = input.lifeStage.currentWeek ?? null;
    view.pregnancyLatestMilestone = input.lifeStage.latestMilestone ?? null;
  }

  if (approved('supportSuggestions')) {
    shown.push('supportSuggestions');
    const highPain = (input.latestLog?.painLevel ?? 0) >= 7;
    const manySymptoms = (input.latestLog?.symptoms?.length ?? 0) >= 3;
    view.supportSuggested = highPain || manySymptoms;
    view.supportReason = highPain ? 'highPain' : manySymptoms ? 'multipleSymptoms' : null;
  }

  if (approved('moodUpdates')) {
    shown.push('moodUpdates');
    view.recentMoodTrend = moodToTrend(input.latestLog?.mood ?? null);
  }

  return view;
}

/** Linked partner uid when the invite is accepted, else null. */
export async function acceptedPartnerOf(db: Db, uid: string): Promise<string | null> {
  const link = await db.getRow(TABLES.partnerLinks, uid);
  return link?.inviteStatus === 'accepted' && typeof link.partnerUserId === 'string' ? link.partnerUserId : null;
}

/**
 * Recomputes partner_views/<uid> from source rows and REPLACES it (data and
 * permissions). Safe to run any number of times, in any order.
 */
export async function recomputePartnerView(db: Db, uid: string, now: Date): Promise<PartnerViewRow> {
  const [permsRow, lifeRow, partnerUid, recentLogs] = await Promise.all([
    db.getRow(TABLES.partnerPermissions, uid),
    db.getRow(TABLES.lifeStageProfiles, uid),
    acceptedPartnerOf(db, uid),
    db.listRows(TABLES.symptomLogs, {
      equal: { userId: uid },
      orderBy: { column: 'date', direction: 'desc' },
      limit: 25,
    }),
  ]);

  const latestOwned = recentLogs.find((row) => isOwnedBy(row, uid));
  const view = buildPartnerView(
    uid,
    {
      perms: {
        approvedCategories: (permsRow?.approvedCategories as string[] | null) ?? [],
        onlyApproveMode: (permsRow?.onlyApproveMode as boolean | null) ?? true,
      },
      lifeStage: (lifeRow ?? {}) as Partial<LifeStageProfileRow>,
      latestLog: latestOwned
        ? {
            symptoms: (latestOwned.symptoms as string[] | null) ?? [],
            mood: (latestOwned.mood as Mood | null) ?? null,
            painLevel: (latestOwned.painLevel as number | null) ?? null,
          }
        : null,
    },
    now,
  );

  const readers = partnerUid ? [uid, partnerUid] : [uid];
  await db.upsertRow(TABLES.partnerViews, uid, view, readersPermissions(readers));
  return view;
}
