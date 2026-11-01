import { RowConflictError, type Db, type Row } from '../../shared/src/db.js';
import { TABLES } from '../../shared/src/ids.js';
import { isOwnedBy, readersPermissions } from '../../shared/src/permissions.js';
import type { ChatMessageRow, Mood, PermissionCategory } from '../../shared/src/types.js';
import type { Messenger } from '../../notifications/src/dispatch.js';
import { acceptedPartnerOf, isCategoryApproved } from '../../partnerView/src/recompute.js';

export type QualifyingReason = { kind: 'highPain'; severity: 'moderate' | 'severe' } | { kind: 'lowMood' } | null;

export function getQualifyingReason(log: { painLevel?: number | null; mood?: Mood | null }): QualifyingReason {
  const pain = log.painLevel ?? 0;
  if (pain >= 9) return { kind: 'highPain', severity: 'severe' };
  if (pain >= 7) return { kind: 'highPain', severity: 'moderate' };
  if (log.mood === 'low' || log.mood === 'difficult') return { kind: 'lowMood' };
  return null;
}

// Warm, formal, no emojis (EVE2_PRD §6); deterministic per severity in V0.
export function messageTextFor(reason: Exclude<QualifyingReason, null>): string {
  if (reason.kind === 'highPain') {
    return reason.severity === 'severe'
      ? 'Eve: Today has been especially difficult for her. A visit, a call, or simply being present could mean a great deal right now.'
      : 'Eve: She logged a difficult day today. This may be a good moment to check in and offer some support.';
  }
  return 'Eve: She noted today has been an emotionally low day. A kind word or a small gesture of support could mean a lot right now.';
}

export interface NudgeDeps {
  db: Db;
  messenger: Messenger;
  now: () => Date;
}

/** Returns true when a new nudge was written (and pushed). */
export async function handleLogCreated(deps: NudgeDeps, log: Row): Promise<boolean> {
  const uid = typeof log.userId === 'string' ? log.userId : null;
  if (!uid || !isOwnedBy(log, uid)) return false;

  const reason = getQualifyingReason({ painLevel: log.painLevel as number | null, mood: log.mood as Mood | null });
  if (!reason) return false;
  const category: PermissionCategory = reason.kind === 'highPain' ? 'supportSuggestions' : 'moodUpdates';

  const partnerUid = await acceptedPartnerOf(deps.db, uid);
  if (!partnerUid) return false;

  const perms = await deps.db.getRow(TABLES.partnerPermissions, uid);
  const approved = isCategoryApproved(
    category,
    (perms?.approvedCategories as string[] | null) ?? [],
    (perms?.onlyApproveMode as boolean | null) ?? true,
  );
  if (!approved) return false;

  const text = messageTextFor(reason);
  const message: ChatMessageRow = {
    threadUserId: uid,
    senderRole: 'system',
    senderUserId: null,
    messageText: text,
    sentAt: deps.now().toISOString(),
    type: 'system',
    category: category === 'supportSuggestions' ? 'supportSuggestion' : 'moodUpdate',
    sourceLogId: log.$id,
  };
  try {
    await deps.db.createRow(TABLES.chatMessages, `sys-${log.$id}`, message, readersPermissions([uid, partnerUid]));
  } catch (e) {
    if (e instanceof RowConflictError) return false; // already nudged for this log
    throw e;
  }
  await deps.messenger.pushToUser(partnerUid, 'Eve', text, { type: 'partnerNudge', threadUserId: uid });
  return true;
}
