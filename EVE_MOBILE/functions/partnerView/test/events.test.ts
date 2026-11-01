import { describe, expect, it } from 'vitest';
import { ownerForEvent, tableFromEvent } from '../src/events.js';
import { ownerEditable, ownerPermissions } from '../../shared/src/permissions.js';

describe('tableFromEvent', () => {
  it('extracts the table ID from a TablesDB row event', () => {
    expect(tableFromEvent('tablesdb.eve.tables.symptom_logs.rows.abc.create')).toBe('symptom_logs');
    expect(tableFromEvent('users.u1.create')).toBeNull();
    expect(tableFromEvent(null)).toBeNull();
  });
});

describe('ownerForEvent', () => {
  it('symptom_logs: the userId, only when that user owns the row', () => {
    expect(ownerForEvent('symptom_logs', { $id: 'l1', $permissions: ownerPermissions('u1'), userId: 'u1' })).toBe('u1');
    expect(ownerForEvent('symptom_logs', { $id: 'l1', $permissions: ownerPermissions('x'), userId: 'u1' })).toBeNull();
  });

  it('singleton tables: the row ID is the owner', () => {
    expect(ownerForEvent('partner_permissions', { $id: 'u1', $permissions: ownerEditable('u1') })).toBe('u1');
    expect(ownerForEvent('life_stage_profiles', { $id: 'u1', $permissions: ownerEditable('u1') })).toBe('u1');
  });

  it('any other table is ignored', () => {
    expect(ownerForEvent('chat_messages', { $id: 'm1', $permissions: [] })).toBeNull();
  });
});
