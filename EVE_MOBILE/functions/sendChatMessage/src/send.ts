import type { Db } from '../../shared/src/db.js';
import { TABLES } from '../../shared/src/ids.js';
import { readersPermissions } from '../../shared/src/permissions.js';
import type { ChatMessageRow } from '../../shared/src/types.js';
import { acceptedPartnerOf } from '../../partnerView/src/recompute.js';

export interface SendDeps {
  db: Db;
  now: () => Date;
  newId: () => string;
}

export interface SendResponse {
  status: number;
  body: Record<string, unknown>;
}

const MAX_TEXT = 2000;

/**
 * The only writer of human chat messages. senderRole/senderUserId/type come
 * from the authenticated caller, never from the request body.
 */
export async function handleSendRequest(deps: SendDeps, uid: string | null, body: Record<string, unknown> | null): Promise<SendResponse> {
  if (!uid) return { status: 401, body: { error: 'Sign in required.' } };
  const threadUserId = typeof body?.threadUserId === 'string' ? body.threadUserId : '';
  const text = typeof body?.text === 'string' ? body.text.trim() : '';
  if (!threadUserId) return { status: 400, body: { error: 'Missing threadUserId.' } };
  if (!text || text.length > MAX_TEXT) return { status: 400, body: { error: 'Message must be 1-2000 characters.' } };

  const partnerUid = await acceptedPartnerOf(deps.db, threadUserId);
  const senderRole = uid === threadUserId ? 'her' : uid === partnerUid ? 'partner' : null;
  if (!senderRole) return { status: 403, body: { error: 'You are not part of this conversation.' } };

  const message: ChatMessageRow = {
    threadUserId,
    senderRole,
    senderUserId: uid,
    messageText: text,
    sentAt: deps.now().toISOString(),
    type: 'text',
    category: null,
    sourceLogId: null,
  };
  const messageId = deps.newId();
  const readers = partnerUid ? [threadUserId, partnerUid] : [threadUserId];
  await deps.db.createRow(TABLES.chatMessages, messageId, message, readersPermissions(readers));
  return { status: 200, body: { messageId } };
}
