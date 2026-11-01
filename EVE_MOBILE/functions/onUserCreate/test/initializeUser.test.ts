import { describe, expect, it } from 'vitest';
import { initializeUserRows } from '../src/initializeUser.js';
import { MemoryDb } from '../../shared/test/memoryDb.js';

describe('initializeUserRows', () => {
  it('creates every singleton row for a new user with the right permissions', async () => {
    const db = new MemoryDb();
    const created = await initializeUserRows(db, 'u1', 'Asha');

    expect(created.sort()).toEqual(
      ['life_stage_profiles', 'partner_links', 'partner_permissions', 'partner_views', 'preferences', 'profiles'].sort(),
    );
    const profile = await db.getRow('profiles', 'u1');
    expect(profile?.name).toBe('Asha');
    expect(profile?.$permissions).toEqual(['read("user:u1")', 'update("user:u1")']);

    const link = await db.getRow('partner_links', 'u1');
    expect(link?.inviteStatus).toBe('none');
    expect(link?.$permissions).toEqual(['read("user:u1")']);

    const view = await db.getRow('partner_views', 'u1');
    expect(view?.primaryUserId).toBe('u1');
    expect(view?.$permissions).toEqual(['read("user:u1")']);

    const perms = await db.getRow('partner_permissions', 'u1');
    expect(perms?.onlyApproveMode).toBe(true);
  });

  it('is idempotent: a redelivered event creates nothing and overwrites nothing', async () => {
    const db = new MemoryDb();
    await initializeUserRows(db, 'u1', 'Asha');
    await db.updateRow('profiles', 'u1', { name: 'Asha K', age: 29 });

    const created = await initializeUserRows(db, 'u1', 'Someone Else');

    expect(created).toEqual([]);
    const profile = await db.getRow('profiles', 'u1');
    expect(profile?.name).toBe('Asha K');
    expect(profile?.age).toBe(29);
  });

  it('fills only the gaps after a partial failure', async () => {
    const db = new MemoryDb();
    await db.createRow('profiles', 'u1', { name: 'Asha' }, []);
    const created = await initializeUserRows(db, 'u1', 'Asha');
    expect(created).not.toContain('profiles');
    expect(created).toHaveLength(5);
  });
});
