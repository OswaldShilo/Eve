import type { Row } from '../../shared/src/db.js';
import { TABLES } from '../../shared/src/ids.js';
import { isOwnedBy } from '../../shared/src/permissions.js';

/** `tablesdb.<db>.tables.<table>.rows.<row>.<action>` → `<table>`. */
export function tableFromEvent(event: string | null): string | null {
  if (!event) return null;
  const parts = event.split('.');
  return parts[0] === 'tablesdb' && parts[2] === 'tables' ? parts[3] : null;
}

/** Whose partner view this row change affects, or null to ignore it. */
export function ownerForEvent(tableId: string, row: Row): string | null {
  switch (tableId) {
    case TABLES.symptomLogs: {
      const userId = typeof row.userId === 'string' ? row.userId : null;
      return userId && isOwnedBy(row, userId) ? userId : null;
    }
    case TABLES.lifeStageProfiles:
    case TABLES.partnerPermissions:
      return row.$id;
    default:
      return null;
  }
}
