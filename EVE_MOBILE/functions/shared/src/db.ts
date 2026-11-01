import { AppwriteException, Query, TablesDB } from 'node-appwrite';
import { serverClient, type FunctionContext } from './appwrite.js';
import { DATABASE_ID, type TableId } from './ids.js';

/** A stored row: Appwrite system fields plus the table's columns. */
export interface Row {
  $id: string;
  $permissions: string[];
  [column: string]: unknown;
}

export interface ListOptions {
  equal?: Record<string, string | number | boolean>;
  orderBy?: { column: string; direction: 'asc' | 'desc' };
  /** Maximum rows returned across pages. Defaults to 5000. */
  limit?: number;
}

export class RowConflictError extends Error {}
export class RowNotFoundError extends Error {}

/**
 * The only storage surface server code uses. Keeping it this small is what
 * lets every function be unit-tested against MemoryDb with no Appwrite
 * instance running.
 */
export interface Db {
  getRow(tableId: TableId, rowId: string): Promise<Row | null>;
  listRows(tableId: TableId, options?: ListOptions): Promise<Row[]>;
  /** Throws RowConflictError when the row already exists. */
  createRow(tableId: TableId, rowId: string, data: object, permissions: string[]): Promise<Row>;
  /** Creates or fully replaces data AND permissions. */
  upsertRow(tableId: TableId, rowId: string, data: object, permissions: string[]): Promise<Row>;
  /** Patches columns; keeps permissions unless given. Throws RowNotFoundError. */
  updateRow(tableId: TableId, rowId: string, data: object, permissions?: string[]): Promise<Row>;
}

const PAGE_SIZE = 100;

/** The Db every deployed function uses, authenticated with the execution's dynamic API key. */
export function serverDb(context: FunctionContext): Db {
  return new AppwriteDb(new TablesDB(serverClient(context)));
}

export class AppwriteDb implements Db {
  constructor(private readonly tables: TablesDB) {}

  async getRow(tableId: TableId, rowId: string): Promise<Row | null> {
    try {
      return (await this.tables.getRow({ databaseId: DATABASE_ID, tableId, rowId })) as unknown as Row;
    } catch (e) {
      if (e instanceof AppwriteException && e.code === 404) return null;
      throw e;
    }
  }

  async listRows(tableId: TableId, options: ListOptions = {}): Promise<Row[]> {
    const base: string[] = Object.entries(options.equal ?? {}).map(([column, value]) =>
      Query.equal(column, value),
    );
    if (options.orderBy) {
      base.push(
        options.orderBy.direction === 'asc'
          ? Query.orderAsc(options.orderBy.column)
          : Query.orderDesc(options.orderBy.column),
      );
    }
    const max = options.limit ?? 5000;
    const rows: Row[] = [];
    let cursor: string | undefined;
    while (rows.length < max) {
      const pageSize = Math.min(PAGE_SIZE, max - rows.length);
      const queries = [...base, Query.limit(pageSize)];
      if (cursor) queries.push(Query.cursorAfter(cursor));
      const page = await this.tables.listRows({ databaseId: DATABASE_ID, tableId, queries, total: false });
      const batch = page.rows as unknown as Row[];
      rows.push(...batch);
      if (batch.length < pageSize) break;
      cursor = batch[batch.length - 1].$id;
    }
    return rows;
  }

  async createRow(tableId: TableId, rowId: string, data: object, permissions: string[]): Promise<Row> {
    try {
      return (await this.tables.createRow({
        databaseId: DATABASE_ID,
        tableId,
        rowId,
        data: data as Record<string, unknown>,
        permissions,
      })) as unknown as Row;
    } catch (e) {
      if (e instanceof AppwriteException && e.code === 409) throw new RowConflictError(`${tableId}/${rowId} exists`);
      throw e;
    }
  }

  async upsertRow(tableId: TableId, rowId: string, data: object, permissions: string[]): Promise<Row> {
    return (await this.tables.upsertRow({
      databaseId: DATABASE_ID,
      tableId,
      rowId,
      data: data as Record<string, unknown>,
      permissions,
    })) as unknown as Row;
  }

  async updateRow(tableId: TableId, rowId: string, data: object, permissions?: string[]): Promise<Row> {
    try {
      return (await this.tables.updateRow({
        databaseId: DATABASE_ID,
        tableId,
        rowId,
        data: data as Record<string, unknown>,
        ...(permissions ? { permissions } : {}),
      })) as unknown as Row;
    } catch (e) {
      if (e instanceof AppwriteException && e.code === 404) throw new RowNotFoundError(`${tableId}/${rowId} missing`);
      throw e;
    }
  }
}
