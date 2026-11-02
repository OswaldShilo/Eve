import { beforeEach, describe, expect, it } from 'vitest';
import { getQualifyingReason, handleLogCreated } from '../src/nudge.js';
import type { Messenger } from '../../notifications/src/dispatch.js';
import type { Row } from '../../shared/src/db.js';
import { ownerEditable, ownerPermissions, ownerReadOnly } from '../../shared/src/permissions.js';
import { MemoryDb } from '../../shared/test/memoryDb.js';

const NOW = new Date('2026-03-14T10:00:00.000Z');

function log(overrides: Partial<Row> = {}): Row {
  return {
    $id: 'log1',
    $permissions: ownerPermissions('her'),
    userId: 'her',
    date: NOW.toISOString(),
    symptoms: [],
    mood: 'okay',
    painLevel: 0,
    notes: '',
    ...overrides,
  };
}

describe('getQualifyingReason', () => {
  it('ranks severe pain, moderate pain, then low mood', () => {
    expect(getQualifyingReason({ painLevel: 9, mood: 'low' })).toEqual({ kind: 'highPain', severity: 'severe' });
    expect(getQualifyingReason({ painLevel: 7, mood: null })).toEqual({ kind: 'highPain', severity: 'moderate' });
    expect(getQualifyingReason({ painLevel: 2, mood: 'difficult' })).toEqual({ kind: 'lowMood' });
    expect(getQualifyingReason({ painLevel: 2, mood: 'good' })).toBeNull();
  });
});

describe('handleLogCreated', () => {
  let db: MemoryDb;
  let pushes: { uid: string; body: string }[];
  const messenger: Messenger = {
    async pushToUser(uid, _title, body) {
      pushes.push({ uid, body });
    },
  };
  const deps = () => ({ db, messenger, now: () => NOW });

  beforeEach(async () => {
    db = new MemoryDb();
    pushes = [];
    await db.createRow('partner_links', 'her', { inviteStatus: 'accepted', partnerUserId: 'him' }, ownerReadOnly('her'));
    await db.createRow('partner_permissions', 'her', { approvedCategories: ['moodUpdates'], onlyApproveMode: true }, ownerEditable('her'));
  });

  it('writes exactly one system message and pushes the partner for an approved low-mood log', async () => {
    await handleLogCreated(deps(), log({ mood: 'low' }));

    const row = await db.getRow('chat_messages', 'sys-log1');
    expect(row).toMatchObject({
      threadUserId: 'her',
      senderRole: 'system',
      senderUserId: null,
      type: 'system',
      category: 'moodUpdate',
      sourceLogId: 'log1',
    });
    expect(String(row?.messageText)).toMatch(/^Eve: /);
    expect(row?.$permissions).toEqual(['read("user:her")', 'read("user:him")']);
    expect(pushes).toEqual([{ uid: 'him', body: row?.messageText }]);
  });

  it('a redelivered event creates no duplicate message and no second push', async () => {
    await handleLogCreated(deps(), log({ mood: 'low' }));
    await handleLogCreated(deps(), log({ mood: 'low' }));
    expect(db.all('chat_messages')).toHaveLength(1);
    expect(pushes).toHaveLength(1);
  });

  it('does nothing when the matching category is not approved', async () => {
    await handleLogCreated(deps(), log({ painLevel: 8 }));
    expect(db.all('chat_messages')).toHaveLength(0);
    expect(pushes).toHaveLength(0);
  });

  it('does nothing without an accepted partner', async () => {
    await db.updateRow('partner_links', 'her', { inviteStatus: 'pending', partnerUserId: null });
    await handleLogCreated(deps(), log({ mood: 'low' }));
    expect(db.all('chat_messages')).toHaveLength(0);
  });

  it('ignores a forged log whose permissions do not belong to the userId', async () => {
    await handleLogCreated(deps(), log({ mood: 'low', $permissions: ownerPermissions('attacker') }));
    expect(db.all('chat_messages')).toHaveLength(0);
  });

  it('message text never contains the raw pain number or symptoms', async () => {
    await db.updateRow('partner_permissions', 'her', { approvedCategories: ['supportSuggestions'] });
    await handleLogCreated(deps(), log({ painLevel: 9, symptoms: ['cramps'] }));
    const text = String((await db.getRow('chat_messages', 'sys-log1'))?.messageText);
    expect(text).not.toMatch(/9|cramps/);
  });
});
