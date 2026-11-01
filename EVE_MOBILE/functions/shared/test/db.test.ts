import { describe, expect, it } from 'vitest';
import { RowConflictError, RowNotFoundError } from '../src/db.js';
import { isOwnedBy, ownerPermissions, ownerReadOnly, readersPermissions } from '../src/permissions.js';
import { MemoryDb } from './memoryDb.js';

describe('permissions', () => {
  it('builds owner read/update/delete permissions in Appwrite string form', () => {
    expect(ownerPermissions('u1')).toEqual(['read("user:u1")', 'update("user:u1")', 'delete("user:u1")']);
    expect(ownerReadOnly('u1')).toEqual(['read("user:u1")']);
    expect(readersPermissions(['u1', 'p1'])).toEqual(['read("user:u1")', 'read("user:p1")']);
  });

  it('isOwnedBy is true only when the row grants update to that user', () => {
    expect(isOwnedBy({ $permissions: ownerPermissions('u1') }, 'u1')).toBe(true);
    expect(isOwnedBy({ $permissions: ownerPermissions('u1') }, 'u2')).toBe(false);
    expect(isOwnedBy({ $permissions: ownerReadOnly('u1') }, 'u1')).toBe(false);
  });
});

describe('MemoryDb', () => {
  it('creates, reads, updates and rejects duplicate creates', async () => {
    const db = new MemoryDb();
    await db.createRow('profiles', 'u1', { name: 'Asha' }, ownerPermissions('u1'));
    expect((await db.getRow('profiles', 'u1'))?.name).toBe('Asha');
    await expect(db.createRow('profiles', 'u1', { name: 'X' }, [])).rejects.toBeInstanceOf(RowConflictError);
    await db.updateRow('profiles', 'u1', { name: 'Asha K' });
    const row = await db.getRow('profiles', 'u1');
    expect(row?.name).toBe('Asha K');
    expect(row?.$permissions).toEqual(ownerPermissions('u1'));
    await expect(db.updateRow('profiles', 'missing', {})).rejects.toBeInstanceOf(RowNotFoundError);
    expect(await db.getRow('profiles', 'missing')).toBeNull();
  });

  it('upsert replaces data and permissions', async () => {
    const db = new MemoryDb();
    await db.upsertRow('partner_views', 'u1', { supportSuggested: true }, ownerReadOnly('u1'));
    await db.upsertRow('partner_views', 'u1', { supportSuggested: null }, readersPermissions(['u1', 'p1']));
    const row = await db.getRow('partner_views', 'u1');
    expect(row?.supportSuggested).toBeNull();
    expect(row?.$permissions).toEqual(readersPermissions(['u1', 'p1']));
  });

  it('lists with equality filter, ordering and limit', async () => {
    const db = new MemoryDb();
    await db.createRow('symptom_logs', 'a', { userId: 'u1', date: '2026-03-02T00:00:00.000Z' }, []);
    await db.createRow('symptom_logs', 'b', { userId: 'u1', date: '2026-03-04T00:00:00.000Z' }, []);
    await db.createRow('symptom_logs', 'c', { userId: 'u2', date: '2026-03-05T00:00:00.000Z' }, []);
    const latest = await db.listRows('symptom_logs', {
      equal: { userId: 'u1' },
      orderBy: { column: 'date', direction: 'desc' },
      limit: 1,
    });
    expect(latest.map((r) => r.$id)).toEqual(['b']);
  });
});
