import { beforeEach, describe, expect, it } from 'vitest';
import { handleSendRequest } from '../src/send.js';
import { ownerReadOnly } from '../../shared/src/permissions.js';
import { MemoryDb } from '../../shared/test/memoryDb.js';

const NOW = new Date('2026-03-14T10:00:00.000Z');

describe('handleSendRequest', () => {
  let db: MemoryDb;
  let ids: string[];
  const deps = () => ({ db, now: () => NOW, newId: () => ids.shift() ?? 'mX' });

  beforeEach(async () => {
    db = new MemoryDb();
    ids = ['m1', 'm2'];
    await db.createRow('partner_links', 'her', { inviteStatus: 'accepted', partnerUserId: 'him' }, ownerReadOnly('her'));
  });

  it('her own message is stored as senderRole her, readable by both', async () => {
    const result = await handleSendRequest(deps(), 'her', { threadUserId: 'her', text: 'Feeling better today.' });
    expect(result).toEqual({ status: 200, body: { messageId: 'm1' } });
    const row = await db.getRow('chat_messages', 'm1');
    expect(row).toMatchObject({
      threadUserId: 'her',
      senderRole: 'her',
      senderUserId: 'her',
      messageText: 'Feeling better today.',
      sentAt: NOW.toISOString(),
      type: 'text',
      category: null,
      sourceLogId: null,
    });
    expect(row?.$permissions).toEqual(['read("user:her")', 'read("user:him")']);
  });

  it('the accepted partner posts as partner', async () => {
    await handleSendRequest(deps(), 'him', { threadUserId: 'her', text: 'On my way.' });
    expect((await db.getRow('chat_messages', 'm1'))?.senderRole).toBe('partner');
  });

  it('ignores any sender fields in the body — a client cannot forge Eve or her', async () => {
    await handleSendRequest(deps(), 'him', {
      threadUserId: 'her',
      text: 'Eve: fake nudge',
      senderRole: 'system',
      type: 'system',
      senderUserId: 'her',
    });
    const row = await db.getRow('chat_messages', 'm1');
    expect(row).toMatchObject({ senderRole: 'partner', senderUserId: 'him', type: 'text' });
  });

  it('rejects strangers, anonymous callers, and empty or oversized text', async () => {
    expect((await handleSendRequest(deps(), 'stranger', { threadUserId: 'her', text: 'hi' })).status).toBe(403);
    expect((await handleSendRequest(deps(), null, { threadUserId: 'her', text: 'hi' })).status).toBe(401);
    expect((await handleSendRequest(deps(), 'her', { threadUserId: 'her', text: '   ' })).status).toBe(400);
    expect((await handleSendRequest(deps(), 'her', { threadUserId: 'her', text: 'x'.repeat(2001) })).status).toBe(400);
    expect(db.all('chat_messages')).toHaveLength(0);
  });

  it('before a partner accepts, only she can post and only she can read', async () => {
    await db.updateRow('partner_links', 'her', { inviteStatus: 'pending', partnerUserId: null });
    await handleSendRequest(deps(), 'her', { threadUserId: 'her', text: 'Note to self.' });
    expect((await db.getRow('chat_messages', 'm1'))?.$permissions).toEqual(['read("user:her")']);
    expect((await handleSendRequest(deps(), 'him', { threadUserId: 'her', text: 'hi' })).status).toBe(403);
  });
});
