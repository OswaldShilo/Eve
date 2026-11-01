import { RowConflictError, RowNotFoundError, type Db, type ListOptions, type Row } from '../src/db.js';
import type { TableId } from '../src/ids.js';

/** In-memory Db with the same semantics as AppwriteDb, for unit tests. */
export class MemoryDb implements Db {
  private readonly tables = new Map<string, Map<string, Row>>();

  private table(tableId: TableId): Map<string, Row> {
    let table = this.tables.get(tableId);
    if (!table) {
      table = new Map();
      this.tables.set(tableId, table);
    }
    return table;
  }

  async getRow(tableId: TableId, rowId: string): Promise<Row | null> {
    const row = this.table(tableId).get(rowId);
    return row ? structuredClone(row) : null;
  }

  async listRows(tableId: TableId, options: ListOptions = {}): Promise<Row[]> {
    let rows = [...this.table(tableId).values()].filter((row) =>
      Object.entries(options.equal ?? {}).every(([column, value]) => row[column] === value),
    );
    if (options.orderBy) {
      const { column, direction } = options.orderBy;
      rows = rows.sort((a, b) => {
        const left = a[column] as string | number;
        const right = b[column] as string | number;
        const cmp = left < right ? -1 : left > right ? 1 : 0;
        return direction === 'asc' ? cmp : -cmp;
      });
    }
    return rows.slice(0, options.limit ?? 5000).map((row) => structuredClone(row));
  }

  async createRow(tableId: TableId, rowId: string, data: object, permissions: string[]): Promise<Row> {
    if (this.table(tableId).has(rowId)) throw new RowConflictError(`${tableId}/${rowId} exists`);
    const row: Row = { ...structuredClone(data), $id: rowId, $permissions: [...permissions] };
    this.table(tableId).set(rowId, row);
    return structuredClone(row);
  }

  async upsertRow(tableId: TableId, rowId: string, data: object, permissions: string[]): Promise<Row> {
    const row: Row = { ...structuredClone(data), $id: rowId, $permissions: [...permissions] };
    this.table(tableId).set(rowId, row);
    return structuredClone(row);
  }

  async updateRow(tableId: TableId, rowId: string, data: object, permissions?: string[]): Promise<Row> {
    const existing = this.table(tableId).get(rowId);
    if (!existing) throw new RowNotFoundError(`${tableId}/${rowId} missing`);
    const row: Row = {
      ...existing,
      ...structuredClone(data),
      $id: rowId,
      $permissions: permissions ? [...permissions] : existing.$permissions,
    };
    this.table(tableId).set(rowId, row);
    return structuredClone(row);
  }

  /** Test helper: every row in a table. */
  all(tableId: TableId): Row[] {
    return [...this.table(tableId).values()].map((row) => structuredClone(row));
  }
}
