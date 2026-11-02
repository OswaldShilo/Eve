import type { Db } from '../../shared/src/db.js';
import { TABLES } from '../../shared/src/ids.js';
import { ownerReadOnly, readersPermissions } from '../../shared/src/permissions.js';
import type { PartnerLookupRow } from '../../shared/src/types.js';
import { recomputePartnerView } from '../../partnerView/src/recompute.js';

const ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // no 0/O/1/I

export function generateInviteCode(random: () => number = Math.random): string {
  let code = '';
  for (let i = 0; i < 6; i += 1) code += ALPHABET[Math.floor(random() * ALPHABET.length)];
  return code;
}

export interface InviteDeps {
  db: Db;
  now: () => Date;
  newCode: () => string;
}

export interface InviteResponse {
  status: number;
  body: Record<string, unknown>;
}

export async function handleInviteRequest(
  deps: InviteDeps,
  uid: string | null,
  body: Record<string, unknown> | null,
): Promise<InviteResponse> {
  if (!uid) return { status: 401, body: { error: 'Sign in required.' } };
  switch (body?.action) {
    case 'createInvite':
      return createInvite(deps, uid, typeof body.relationshipType === 'string' ? body.relationshipType : null);
    case 'acceptInvite':
      return acceptInvite(deps, uid, typeof body.inviteCode === 'string' ? body.inviteCode : '');
    default:
      return { status: 400, body: { error: 'Unknown action.' } };
  }
}

async function createInvite(deps: InviteDeps, uid: string, relationshipType: string | null): Promise<InviteResponse> {
  const existing = await deps.db.getRow(TABLES.partnerLinks, uid);
  if (existing?.inviteStatus === 'accepted') {
    return { status: 409, body: { error: 'A partner is already linked.' } };
  }
  const inviteCode = deps.newCode();
  await deps.db.upsertRow(
    TABLES.partnerLinks,
    uid,
    {
      partnerUserId: null,
      relationshipType,
      inviteStatus: 'pending',
      inviteCode,
      invitedAt: deps.now().toISOString(),
      linkedAt: null,
    },
    ownerReadOnly(uid),
  );
  return { status: 200, body: { inviteCode } };
}

async function acceptInvite(deps: InviteDeps, partnerUid: string, rawCode: string): Promise<InviteResponse> {
  const inviteCode = rawCode.trim().toUpperCase();
  if (!/^[A-Z0-9]{6}$/.test(inviteCode)) return { status: 400, body: { error: 'Invalid invite code.' } };

  const [link] = await deps.db.listRows(TABLES.partnerLinks, { equal: { inviteCode, inviteStatus: 'pending' }, limit: 1 });
  if (!link) return { status: 404, body: { error: 'This invite code is not valid.' } };
  const primaryUid = link.$id;
  if (primaryUid === partnerUid) return { status: 400, body: { error: 'You cannot accept your own invite.' } };
  if (await deps.db.getRow(TABLES.partnerLookups, partnerUid)) {
    return { status: 409, body: { error: 'This account is already linked to someone.' } };
  }

  const linkedAt = deps.now().toISOString();
  const readers = readersPermissions([primaryUid, partnerUid]);
  await deps.db.updateRow(
    TABLES.partnerLinks,
    primaryUid,
    { partnerUserId: partnerUid, inviteStatus: 'accepted', inviteCode: null, linkedAt },
    readers,
  );
  const lookup: PartnerLookupRow = {
    primaryUserId: primaryUid,
    relationshipType: (link.relationshipType as string | null) ?? null,
    linkedAt,
  };
  await deps.db.upsertRow(TABLES.partnerLookups, partnerUid, lookup, readersPermissions([partnerUid]));

  // Re-grant read on her existing thread so the partner sees chat history.
  for (const message of await deps.db.listRows(TABLES.chatMessages, { equal: { threadUserId: primaryUid } })) {
    await deps.db.updateRow(TABLES.chatMessages, message.$id, {}, readers);
  }
  await recomputePartnerView(deps.db, primaryUid, deps.now());

  return { status: 200, body: { primaryUserId: primaryUid } };
}
