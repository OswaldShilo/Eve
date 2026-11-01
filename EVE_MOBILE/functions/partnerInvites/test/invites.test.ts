import { beforeEach, describe, expect, it } from 'vitest';
import { generateInviteCode, handleInviteRequest } from '../src/invites.js';
import { ownerEditable, ownerReadOnly } from '../../shared/src/permissions.js';
import { MemoryDb } from '../../shared/test/memoryDb.js';

const NOW = new Date('2026-03-14T10:00:00.000Z');

describe('generateInviteCode', () => {
  it('produces 6 characters from an unambiguous alphabet', () => {
    const code = generateInviteCode(() => 0.5);
    expect(code).toMatch(/^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{6}$/);
  });
});

describe('handleInviteRequest', () => {
  let db: MemoryDb;
  let codes: string[];
  const deps = () => ({ db, now: () => NOW, newCode: () => codes.shift() ?? 'ZZZZZZ' });

  beforeEach(async () => {
    db = new MemoryDb();
    codes = ['ABC234', 'DEF567'];
    await db.createRow('partner_links', 'her', { inviteStatus: 'none', partnerUserId: null, inviteCode: null }, ownerReadOnly('her'));
    await db.createRow('partner_permissions', 'her', { approvedCategories: ['moodUpdates'], onlyApproveMode: true }, ownerEditable('her'));
    await db.createRow('life_stage_profiles', 'her', { type: 'cycle' }, ownerEditable('her'));
  });

  it('requires a signed-in caller', async () => {
    expect((await handleInviteRequest(deps(), null, { action: 'createInvite' })).status).toBe(401);
  });

  it('createInvite stores a pending link with a code readable only by her', async () => {
    const result = await handleInviteRequest(deps(), 'her', { action: 'createInvite', relationshipType: 'husband' });
    expect(result).toEqual({ status: 200, body: { inviteCode: 'ABC234' } });
    const link = await db.getRow('partner_links', 'her');
    expect(link).toMatchObject({ inviteStatus: 'pending', inviteCode: 'ABC234', relationshipType: 'husband', partnerUserId: null });
    expect(link?.$permissions).toEqual(['read("user:her")']);
  });

  it('acceptInvite links both accounts, grants the partner read, and writes the reverse lookup', async () => {
    await handleInviteRequest(deps(), 'her', { action: 'createInvite', relationshipType: 'husband' });
    await db.createRow('chat_messages', 'm1', { threadUserId: 'her', senderRole: 'her', messageText: 'hi', sentAt: NOW.toISOString(), type: 'text' }, ['read("user:her")']);

    const result = await handleInviteRequest(deps(), 'him', { action: 'acceptInvite', inviteCode: 'abc234' });

    expect(result).toEqual({ status: 200, body: { primaryUserId: 'her' } });
    const link = await db.getRow('partner_links', 'her');
    expect(link).toMatchObject({ inviteStatus: 'accepted', partnerUserId: 'him', inviteCode: null, linkedAt: NOW.toISOString() });
    expect(link?.$permissions).toEqual(['read("user:her")', 'read("user:him")']);
    expect(await db.getRow('partner_lookups', 'him')).toMatchObject({ primaryUserId: 'her', relationshipType: 'husband' });
    expect((await db.getRow('partner_views', 'her'))?.$permissions).toEqual(['read("user:her")', 'read("user:him")']);
    expect((await db.getRow('chat_messages', 'm1'))?.$permissions).toEqual(['read("user:her")', 'read("user:him")']);
  });

  it('rejects unknown codes, self-acceptance and a second partner', async () => {
    await handleInviteRequest(deps(), 'her', { action: 'createInvite', relationshipType: 'partner' });
    expect((await handleInviteRequest(deps(), 'him', { action: 'acceptInvite', inviteCode: 'NOPE00' })).status).toBe(404);
    expect((await handleInviteRequest(deps(), 'her', { action: 'acceptInvite', inviteCode: 'ABC234' })).status).toBe(400);

    await handleInviteRequest(deps(), 'him', { action: 'acceptInvite', inviteCode: 'ABC234' });
    expect((await handleInviteRequest(deps(), 'other', { action: 'acceptInvite', inviteCode: 'ABC234' })).status).toBe(404);
  });

  it('createInvite after acceptance is refused (unlinking is out of V0 scope)', async () => {
    await handleInviteRequest(deps(), 'her', { action: 'createInvite', relationshipType: 'partner' });
    await handleInviteRequest(deps(), 'him', { action: 'acceptInvite', inviteCode: 'ABC234' });
    expect((await handleInviteRequest(deps(), 'her', { action: 'createInvite', relationshipType: 'partner' })).status).toBe(409);
  });
});
