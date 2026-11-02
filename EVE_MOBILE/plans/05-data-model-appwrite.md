# Data Model & Appwrite Schema Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn every table listed in `00-design-spec.md` §10 into a concrete, column-typed TablesDB schema in `appwrite.config.json` — expressed identically in TypeScript (Functions) and Dart (Flutter client) — plus the row-permission model that enforces owner/partner/server access boundaries, a storage port with an in-memory test double, and the idempotent `onUserCreate` function that initializes a new user's rows.

**Architecture:** `functions/shared/src/types.ts` is the source of truth for column names/types; a hand-written Dart mirror (`app/lib/shared/models/*.dart`) agrees with it field-for-field. `appwrite.config.json` declares the `eve` database and its 9 tables; a Vitest schema test cross-checks the config's columns against fully-typed TypeScript fixtures and asserts the permission invariants (which tables clients can never write). All server code talks to storage through a small `Db` interface (`functions/shared/src/db.ts`) with two implementations — `AppwriteDb` (wraps `node-appwrite`'s `TablesDB`) and `MemoryDb` (tests). `onUserCreate` is an Appwrite Function subscribed to `users.*.create` that creates each missing singleton row; re-delivery of the event is harmless.

**Tech Stack:** Appwrite (TablesDB, Functions, `users.*.create` event), `node-appwrite` 31.x, Node.js 22 / TypeScript (ESM), Vitest, Dart plain classes (no codegen), `flutter_test`.

## Global Constraints

- Backend is Appwrite; no Firebase/GCP package or config file may be added. [`00-design-spec.md` §2]
- Table IDs, row-ID conventions and canonical stored values MUST match `00-design-spec.md` §10 exactly. [`00-design-spec.md` §10]
- `partner_views`, `partner_links`, `partner_lookups` and `chat_messages` are server-written only: their tables grant **no** table-level permissions, and every row the server writes carries `read` permissions only — no client (including the profile owner) can ever create, update or delete them. [`EVE2_PRD.md` §8, §10.3]
- A partner may read ONLY `partner_views` (her row), `chat_messages` (her thread), `partner_links` (her row, after accepting) and `partner_lookups` (his own row) — never `symptom_logs`, `life_stage_profiles`, `profiles` or `preferences`. Row permissions on those tables name only the owner. [`EVE2_PRD.md` §8]
- Gamification fields are out of V0 scope — no streak/points table. [`EVE2_PRD.md` §7]
- No diagnosis fields. [`EVE2_PRD.md` §9]
- The recompute of `partner_views` and the chat functions belong to Plan 7; this plan defines only their tables and the shared storage port they use.
- All automated tests run in-process against `MemoryDb` — no test may reach an Appwrite instance. Each task ends with an optional manual check against the local Docker Appwrite from Plan 3 Task 1.
- Requires Plan 3 Task 5 (the `functions/` package scaffold) and Plan 3 Task 2 (`appwrite.config.json` skeleton) to have run first.

---

## Assumptions made explicit (no spec value existed to copy verbatim)

1. **Units:** `profiles.height` is centimeters, `profiles.weight` is kilograms.
2. **Mood vocabulary:** `great | good | okay | low | difficult`. Plan 7 previously used `very_low`; this plan standardizes on `difficult` and Plan 7 has been updated to match.
3. **Simplified-branch vocab** (`conceive`/`postpartum`/`menopause`) is free-form `string[]` (`simplifiedSymptoms`, `simplifiedGoals`), not an enum.
4. **One life-stage row, flattened.** Appwrite rows cannot hold nested objects, so `life_stage_profiles` carries every branch's columns side by side with a `type` discriminator; columns of non-active branches are `null`/`[]`. The Dart model writes all columns on every save so switching branches clears stale values. Pregnancy appointment/milestone data that Plan 7 projects is stored as `nextAppointmentLabel`, `nextAppointmentAt`, `currentWeek`, `latestMilestone`.
5. **Four preference documents → one `preferences` row.** Goals, notifications, AI scope and theme are always written together (onboarding completion) and always owned by her, so splitting them bought nothing but extra round-trips.
6. **Partner-view "absent" means `null`.** Firestore could omit a key; a TablesDB row has fixed columns, so a withheld category is a `null` column (and `approvedCategories` lists what is shown).
7. **Ownership of client-written rows is proven by permissions, not by a `userId` column.** A client can put any string in `symptom_logs.userId`, but Appwrite only lets a client grant permissions to roles it holds — so `update("user:<uid>")` on a row proves `<uid>` created it. Every server function that trusts `userId` checks `isOwnedBy(row, row.userId)` first.
8. **No device-token table.** Appwrite native push addresses users (`createPush({ users: [uid] })`), so the old `users/{uid}/fcmTokens` path is dropped (roadmap CN-4 is resolved by deletion).

---

## Task 1: Shared IDs and TypeScript row types

**Files:**
- Create: `EVE_MOBILE/functions/shared/src/ids.ts`
- Create: `EVE_MOBILE/functions/shared/src/types.ts`
- Test: `EVE_MOBILE/functions/shared/test/types.test.ts`

**Interfaces:**
- Consumes: `00-design-spec.md` §10 table/value lists.
- Produces (exact names later tasks and plans import): `DATABASE_ID`, `TABLES`, `TableId`, `FUNCTION_IDS`; `LIFE_STAGES`, `LifeStage`, `MOODS`, `Mood`, `NOTIFICATION_TYPES`, `NotificationType`, `AI_HELP_AREAS`, `AiHelpArea`, `THEMES`, `Theme`, `PERMISSION_CATEGORIES`, `PermissionCategory`, `INVITE_STATUSES`, `InviteStatus`, `ProfileRow`, `LifeStageProfileRow`, `SymptomLogRow`, `PreferencesRow`, `PartnerLinkRow`, `PartnerPermissionsRow`, `PartnerViewRow`, `PartnerLookupRow`, `ChatSenderRole`, `ChatMessageType`, `ChatMessageRow`.

- [ ] **Step 1: Write the failing test**

Create `EVE_MOBILE/functions/shared/test/types.test.ts`:

```ts
import { describe, expect, it } from 'vitest';
import { DATABASE_ID, FUNCTION_IDS, TABLES } from '../src/ids.js';
import { MOODS, NOTIFICATION_TYPES, PERMISSION_CATEGORIES, LIFE_STAGES } from '../src/types.js';

describe('ids', () => {
  it('uses the canonical database and table IDs from design-spec §10', () => {
    expect(DATABASE_ID).toBe('eve');
    expect(Object.values(TABLES).sort()).toEqual([
      'chat_messages',
      'life_stage_profiles',
      'partner_links',
      'partner_lookups',
      'partner_permissions',
      'partner_views',
      'preferences',
      'profiles',
      'symptom_logs',
    ]);
  });

  it('lists every function ID', () => {
    expect(Object.values(FUNCTION_IDS).sort()).toEqual([
      'aiProxy',
      'chatSystemMessages',
      'notifications',
      'onUserCreate',
      'partnerInvites',
      'partnerView',
      'sendChatMessage',
    ]);
  });
});

describe('canonical vocabularies', () => {
  it('matches design-spec §10', () => {
    expect(LIFE_STAGES).toEqual(['cycle', 'conceive', 'pregnant', 'postpartum', 'menopause']);
    expect(MOODS).toEqual(['great', 'good', 'okay', 'low', 'difficult']);
    expect(NOTIFICATION_TYPES).toHaveLength(9);
    expect(PERMISSION_CATEGORIES).toEqual([
      'appointmentReminders',
      'pregnancyMilestones',
      'supportSuggestions',
      'moodUpdates',
    ]);
  });
});
```

- [ ] **Step 2: Run to verify it fails**

Run (from `EVE_MOBILE/functions/`): `npx vitest run shared/test/types.test.ts`
Expected: FAIL — `Failed to resolve import "../src/ids.js"`.

- [ ] **Step 3: Write `EVE_MOBILE/functions/shared/src/ids.ts`**

```ts
export const DATABASE_ID = 'eve';

export const TABLES = {
  profiles: 'profiles',
  lifeStageProfiles: 'life_stage_profiles',
  symptomLogs: 'symptom_logs',
  preferences: 'preferences',
  partnerLinks: 'partner_links',
  partnerPermissions: 'partner_permissions',
  partnerViews: 'partner_views',
  partnerLookups: 'partner_lookups',
  chatMessages: 'chat_messages',
} as const;

export type TableId = (typeof TABLES)[keyof typeof TABLES];

export const FUNCTION_IDS = {
  onUserCreate: 'onUserCreate',
  partnerView: 'partnerView',
  partnerInvites: 'partnerInvites',
  sendChatMessage: 'sendChatMessage',
  chatSystemMessages: 'chatSystemMessages',
  aiProxy: 'aiProxy',
  notifications: 'notifications',
} as const;
```

- [ ] **Step 4: Write `EVE_MOBILE/functions/shared/src/types.ts`**

```ts
// Row shapes for every table in design-spec §10. Datetime columns are ISO
// 8601 strings (that is what TablesDB returns and accepts). Appwrite system
// fields ($id, $permissions, $createdAt, ...) are NOT part of these shapes —
// see `Row` in db.ts.

export const LIFE_STAGES = ['cycle', 'conceive', 'pregnant', 'postpartum', 'menopause'] as const;
export type LifeStage = (typeof LIFE_STAGES)[number];

export const MOODS = ['great', 'good', 'okay', 'low', 'difficult'] as const;
export type Mood = (typeof MOODS)[number];

export const NOTIFICATION_TYPES = [
  'morning',
  'medicine',
  'workout',
  'water',
  'sleep',
  'cycle',
  'appointment',
  'mood',
  'daily_tip',
] as const;
export type NotificationType = (typeof NOTIFICATION_TYPES)[number];

export const AI_HELP_AREAS = [
  'healthQuestions',
  'nutrition',
  'workouts',
  'mentalWellbeing',
  'medicationReminders',
  'doctorPrep',
] as const;
export type AiHelpArea = (typeof AI_HELP_AREAS)[number];

export const THEMES = ['light', 'dark', 'default'] as const;
export type Theme = (typeof THEMES)[number];

export const PERMISSION_CATEGORIES = [
  'appointmentReminders',
  'pregnancyMilestones',
  'supportSuggestions',
  'moodUpdates',
] as const;
export type PermissionCategory = (typeof PERMISSION_CATEGORIES)[number];

export const INVITE_STATUSES = ['none', 'pending', 'accepted', 'declined'] as const;
export type InviteStatus = (typeof INVITE_STATUSES)[number];

// profiles — rowId = uid
export interface ProfileRow {
  name: string;
  age: number | null;
  height: number | null; // centimeters
  weight: number | null; // kilograms
  country: string | null;
  lifeStage: LifeStage | null;
}

// life_stage_profiles — rowId = uid. Flattened: see plan assumption 4.
export interface LifeStageProfileRow {
  type: LifeStage | null;
  // cycle
  cycleLength: number | null;
  periodLength: number | null;
  flow: string | null;
  cycleSymptoms: string[];
  cycleGoals: string[];
  nutritionDiet: string | null;
  // pregnant
  dueDate: string | null;
  dueMethod: string | null;
  highRisk: boolean | null;
  pregnancyType: string | null;
  medications: string | null;
  allergies: string | null;
  prenatalVitamins: boolean | null;
  pregnantSymptoms: string[];
  currentWeek: number | null;
  nextAppointmentLabel: string | null;
  nextAppointmentAt: string | null;
  latestMilestone: string | null;
  // conceive / postpartum / menopause
  simplifiedSymptoms: string[];
  simplifiedGoals: string[];
}

// symptom_logs — rowId = ID.unique(); row permissions owner-only.
export interface SymptomLogRow {
  userId: string;
  date: string;
  symptoms: string[];
  mood: Mood | null;
  painLevel: number | null; // 0-10
  notes: string;
}

// preferences — rowId = uid
export interface PreferencesRow {
  selectedGoals: string[];
  dietType: string | null;
  foodAllergies: string;
  cuisines: string[];
  workoutPreference: string[];
  enabledReminders: NotificationType[];
  enabledHelpAreas: AiHelpArea[];
  selectedTheme: Theme;
}

// partner_links — rowId = primary uid; server-written only.
export interface PartnerLinkRow {
  partnerUserId: string | null;
  relationshipType: string | null;
  inviteStatus: InviteStatus;
  inviteCode: string | null;
  invitedAt: string | null;
  linkedAt: string | null;
}

// partner_permissions — rowId = uid
export interface PartnerPermissionsRow {
  approvedCategories: PermissionCategory[];
  onlyApproveMode: boolean;
}

// partner_views — rowId = primary uid; server-written only. A withheld
// category is a null column (plan assumption 6). Plan 7 owns the values.
export interface PartnerViewRow {
  primaryUserId: string;
  approvedCategories: PermissionCategory[];
  upcomingAppointmentLabel: string | null;
  upcomingAppointmentAt: string | null;
  pregnancyCurrentWeek: number | null;
  pregnancyLatestMilestone: string | null;
  supportSuggested: boolean | null;
  supportReason: 'highPain' | 'multipleSymptoms' | null;
  recentMoodTrend: 'low' | 'neutral' | 'positive' | null;
  recomputedAt: string | null;
}

// partner_lookups — rowId = partner uid; server-written only.
export interface PartnerLookupRow {
  primaryUserId: string;
  relationshipType: string | null;
  linkedAt: string;
}

// chat_messages — server-written only (sendChatMessage / chatSystemMessages).
export type ChatSenderRole = 'her' | 'partner' | 'system';
export type ChatMessageType = 'text' | 'system';

export interface ChatMessageRow {
  threadUserId: string; // the primary user's uid — one thread per couple
  senderRole: ChatSenderRole;
  senderUserId: string | null; // null for system messages
  messageText: string;
  sentAt: string;
  type: ChatMessageType;
  category: 'supportSuggestion' | 'moodUpdate' | null;
  sourceLogId: string | null;
}
```

- [ ] **Step 5: Run to verify it passes**

Run: `npx vitest run shared/test/types.test.ts && npx tsc --noEmit`
Expected: `3 passed`; `tsc` exits 0.

- [ ] **Step 6: Commit**

```bash
git add EVE_MOBILE/functions/shared/src/ids.ts EVE_MOBILE/functions/shared/src/types.ts EVE_MOBILE/functions/shared/test/types.test.ts
git commit -m "feat(functions): add canonical Appwrite IDs and row types"
```

---

## Task 2: Storage port, permissions helpers and `MemoryDb`

**Files:**
- Create: `EVE_MOBILE/functions/shared/src/db.ts`
- Create: `EVE_MOBILE/functions/shared/src/permissions.ts`
- Create: `EVE_MOBILE/functions/shared/test/memoryDb.ts`
- Test: `EVE_MOBILE/functions/shared/test/db.test.ts`

**Interfaces:**
- Consumes: `DATABASE_ID`, `TableId` (Task 1).
- Consumes (also): `serverClient`, `FunctionContext` from `functions/shared/src/appwrite.ts` (Plan 3 Task 5).
- Produces: `Row`, `ListOptions`, `Db`, `RowConflictError`, `RowNotFoundError`, `AppwriteDb`, `serverDb(context)`; `ownerPermissions(uid)`, `ownerEditable(uid)`, `ownerReadOnly(uid)`, `readersPermissions(uids)`, `isOwnedBy(row, uid)`; `MemoryDb` (test-only). Every server function in Plans 3/5/7 depends on `Db`, never on `TablesDB` directly.

- [ ] **Step 1: Write the failing tests**

Create `EVE_MOBILE/functions/shared/test/db.test.ts`:

```ts
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
```

- [ ] **Step 2: Run to verify it fails**

Run: `npx vitest run shared/test/db.test.ts`
Expected: FAIL — `Failed to resolve import "../src/db.js"`.

- [ ] **Step 3: Write `EVE_MOBILE/functions/shared/src/db.ts`**

```ts
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
```

- [ ] **Step 4: Write `EVE_MOBILE/functions/shared/src/permissions.ts`**

```ts
import { Permission, Role } from 'node-appwrite';
import type { Row } from './db.js';

/** Rows she writes herself (logs): read/update/delete for her only. */
export function ownerPermissions(uid: string): string[] {
  return [Permission.read(Role.user(uid)), Permission.update(Role.user(uid)), Permission.delete(Role.user(uid))];
}

/** Singleton rows she may edit but never delete (profile, preferences, ...). */
export function ownerEditable(uid: string): string[] {
  return [Permission.read(Role.user(uid)), Permission.update(Role.user(uid))];
}

/** Server-written rows only she can see. */
export function ownerReadOnly(uid: string): string[] {
  return [Permission.read(Role.user(uid))];
}

/** Server-written rows several users can see (partner view, chat). */
export function readersPermissions(uids: string[]): string[] {
  return uids.map((uid) => Permission.read(Role.user(uid)));
}

/**
 * True when `uid` holds update permission on the row. Appwrite only lets a
 * client grant permissions to roles it belongs to, so for a client-created
 * row this proves who created it — the `userId` column alone proves nothing.
 */
export function isOwnedBy(row: Pick<Row, '$permissions'>, uid: string): boolean {
  return row.$permissions.includes(Permission.update(Role.user(uid)));
}
```

- [ ] **Step 5: Write `EVE_MOBILE/functions/shared/test/memoryDb.ts`**

```ts
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
```

- [ ] **Step 6: Run to verify it passes**

Run: `npx vitest run shared/test/db.test.ts && npx tsc --noEmit`
Expected: `5 passed`; `tsc` exits 0.

- [ ] **Step 7: Commit**

```bash
git add EVE_MOBILE/functions/shared/src/db.ts EVE_MOBILE/functions/shared/src/permissions.ts EVE_MOBILE/functions/shared/test/memoryDb.ts EVE_MOBILE/functions/shared/test/db.test.ts
git commit -m "feat(functions): add Db storage port, AppwriteDb adapter, MemoryDb and permission helpers"
```

---

## Task 3: Tables, columns, indexes and permissions in `appwrite.config.json`

**Files:**
- Modify: `EVE_MOBILE/appwrite.config.json` (created as a skeleton by Plan 3 Task 2 — replace its empty `"tables": []` with the array below)
- Test: `EVE_MOBILE/functions/shared/test/schema.test.ts`

**Interfaces:**
- Consumes: `TABLES`, row interfaces (Task 1).
- Produces: the deployable schema. The schema test is this plan's replacement for the old Firestore rules tests: it fails if any client-writable permission appears on a server-only table, or if the config's columns drift from the TypeScript types.

- [ ] **Step 1: Write the failing schema test**

Create `EVE_MOBILE/functions/shared/test/schema.test.ts`:

```ts
import { readFileSync } from 'node:fs';
import { describe, expect, it } from 'vitest';
import { TABLES, type TableId } from '../src/ids.js';
import type {
  ChatMessageRow,
  LifeStageProfileRow,
  PartnerLinkRow,
  PartnerLookupRow,
  PartnerPermissionsRow,
  PartnerViewRow,
  PreferencesRow,
  ProfileRow,
  SymptomLogRow,
} from '../src/types.js';

interface ConfigTable {
  $id: string;
  databaseId: string;
  rowSecurity: boolean;
  $permissions: string[];
  columns: { key: string; required: boolean; default?: unknown }[];
  indexes: { key: string; columns: string[] }[];
}

const config = JSON.parse(readFileSync(new URL('../../../appwrite.config.json', import.meta.url), 'utf8')) as {
  tables: ConfigTable[];
};
const table = (id: TableId) => {
  const found = config.tables.find((t) => t.$id === id);
  if (!found) throw new Error(`table ${id} missing from appwrite.config.json`);
  return found;
};

// Fully-typed fixtures: TypeScript forces every column to be present, so
// comparing their keys with the config catches drift in either direction.
const fixtures: Record<TableId, object> = {
  profiles: { name: '', age: null, height: null, weight: null, country: null, lifeStage: null } satisfies ProfileRow,
  life_stage_profiles: {
    type: null, cycleLength: null, periodLength: null, flow: null, cycleSymptoms: [], cycleGoals: [],
    nutritionDiet: null, dueDate: null, dueMethod: null, highRisk: null, pregnancyType: null, medications: null,
    allergies: null, prenatalVitamins: null, pregnantSymptoms: [], currentWeek: null, nextAppointmentLabel: null,
    nextAppointmentAt: null, latestMilestone: null, simplifiedSymptoms: [], simplifiedGoals: [],
  } satisfies LifeStageProfileRow,
  symptom_logs: { userId: 'u', date: '', symptoms: [], mood: null, painLevel: null, notes: '' } satisfies SymptomLogRow,
  preferences: {
    selectedGoals: [], dietType: null, foodAllergies: '', cuisines: [], workoutPreference: [],
    enabledReminders: [], enabledHelpAreas: [], selectedTheme: 'default',
  } satisfies PreferencesRow,
  partner_links: {
    partnerUserId: null, relationshipType: null, inviteStatus: 'none', inviteCode: null, invitedAt: null, linkedAt: null,
  } satisfies PartnerLinkRow,
  partner_permissions: { approvedCategories: [], onlyApproveMode: true } satisfies PartnerPermissionsRow,
  partner_views: {
    primaryUserId: 'u', approvedCategories: [], upcomingAppointmentLabel: null, upcomingAppointmentAt: null,
    pregnancyCurrentWeek: null, pregnancyLatestMilestone: null, supportSuggested: null, supportReason: null,
    recentMoodTrend: null, recomputedAt: null,
  } satisfies PartnerViewRow,
  partner_lookups: { primaryUserId: 'u', relationshipType: null, linkedAt: '' } satisfies PartnerLookupRow,
  chat_messages: {
    threadUserId: 'u', senderRole: 'her', senderUserId: null, messageText: '', sentAt: '', type: 'text',
    category: null, sourceLogId: null,
  } satisfies ChatMessageRow,
};

const SERVER_ONLY: TableId[] = ['partner_links', 'partner_views', 'partner_lookups', 'chat_messages'];

describe('appwrite.config.json schema', () => {
  it.each(Object.values(TABLES))('%s exists in database eve with row security on', (id) => {
    const t = table(id);
    expect(t.databaseId).toBe('eve');
    expect(t.rowSecurity).toBe(true);
  });

  it.each(Object.values(TABLES))('%s columns match the TypeScript row type exactly', (id) => {
    expect(table(id).columns.map((c) => c.key).sort()).toEqual(Object.keys(fixtures[id]).sort());
  });

  it('never combines required with a default (Appwrite rejects it)', () => {
    for (const t of config.tables) {
      for (const c of t.columns) {
        if (c.required) expect(c.default ?? null, `${t.$id}.${c.key}`).toBeNull();
      }
    }
  });

  it.each(SERVER_ONLY)('%s grants no table-level permissions to clients', (id) => {
    expect(table(id).$permissions).toEqual([]);
  });

  it('only symptom_logs lets signed-in users create rows, and grants nothing else table-wide', () => {
    expect(table('symptom_logs').$permissions).toEqual(['create("users")']);
    for (const t of config.tables.filter((x) => x.$id !== 'symptom_logs')) {
      expect(t.$permissions, t.$id).toEqual([]);
    }
  });

  it('indexes the queries the functions run', () => {
    expect(table('symptom_logs').indexes.map((i) => i.columns)).toContainEqual(['userId', 'date']);
    expect(table('chat_messages').indexes.map((i) => i.columns)).toContainEqual(['threadUserId', 'sentAt']);
    expect(table('partner_links').indexes.map((i) => i.columns)).toContainEqual(['inviteCode']);
  });
});
```

- [ ] **Step 2: Run to verify it fails**

Run: `npx vitest run shared/test/schema.test.ts`
Expected: FAIL — `table profiles missing from appwrite.config.json` (the skeleton's `tables` array is empty).

- [ ] **Step 3: Replace `"tables": []` in `EVE_MOBILE/appwrite.config.json`**

```json
  "tables": [
    {
      "$id": "profiles",
      "$permissions": [],
      "databaseId": "eve",
      "name": "profiles",
      "enabled": true,
      "rowSecurity": true,
      "columns": [
        { "key": "name", "type": "string", "required": false, "array": false, "size": 120, "default": "" },
        { "key": "age", "type": "integer", "required": false, "array": false, "min": 0, "max": 130, "default": null },
        { "key": "height", "type": "double", "required": false, "array": false, "min": 0, "max": 300, "default": null },
        { "key": "weight", "type": "double", "required": false, "array": false, "min": 0, "max": 500, "default": null },
        { "key": "country", "type": "string", "required": false, "array": false, "size": 80, "default": null },
        { "key": "lifeStage", "type": "string", "format": "enum", "elements": ["cycle", "conceive", "pregnant", "postpartum", "menopause"], "required": false, "array": false, "size": 16, "default": null }
      ],
      "indexes": []
    },
    {
      "$id": "life_stage_profiles",
      "$permissions": [],
      "databaseId": "eve",
      "name": "life_stage_profiles",
      "enabled": true,
      "rowSecurity": true,
      "columns": [
        { "key": "type", "type": "string", "format": "enum", "elements": ["cycle", "conceive", "pregnant", "postpartum", "menopause"], "required": false, "array": false, "size": 16, "default": null },
        { "key": "cycleLength", "type": "integer", "required": false, "array": false, "min": 10, "max": 90, "default": null },
        { "key": "periodLength", "type": "integer", "required": false, "array": false, "min": 1, "max": 20, "default": null },
        { "key": "flow", "type": "string", "required": false, "array": false, "size": 40, "default": null },
        { "key": "cycleSymptoms", "type": "string", "required": false, "array": true, "size": 64, "default": null },
        { "key": "cycleGoals", "type": "string", "required": false, "array": true, "size": 64, "default": null },
        { "key": "nutritionDiet", "type": "string", "required": false, "array": false, "size": 40, "default": null },
        { "key": "dueDate", "type": "datetime", "required": false, "array": false, "format": "", "default": null },
        { "key": "dueMethod", "type": "string", "required": false, "array": false, "size": 60, "default": null },
        { "key": "highRisk", "type": "boolean", "required": false, "array": false, "default": null },
        { "key": "pregnancyType", "type": "string", "required": false, "array": false, "size": 40, "default": null },
        { "key": "medications", "type": "string", "required": false, "array": false, "size": 500, "default": null },
        { "key": "allergies", "type": "string", "required": false, "array": false, "size": 500, "default": null },
        { "key": "prenatalVitamins", "type": "boolean", "required": false, "array": false, "default": null },
        { "key": "pregnantSymptoms", "type": "string", "required": false, "array": true, "size": 64, "default": null },
        { "key": "currentWeek", "type": "integer", "required": false, "array": false, "min": 0, "max": 45, "default": null },
        { "key": "nextAppointmentLabel", "type": "string", "required": false, "array": false, "size": 120, "default": null },
        { "key": "nextAppointmentAt", "type": "datetime", "required": false, "array": false, "format": "", "default": null },
        { "key": "latestMilestone", "type": "string", "required": false, "array": false, "size": 120, "default": null },
        { "key": "simplifiedSymptoms", "type": "string", "required": false, "array": true, "size": 64, "default": null },
        { "key": "simplifiedGoals", "type": "string", "required": false, "array": true, "size": 64, "default": null }
      ],
      "indexes": []
    },
    {
      "$id": "symptom_logs",
      "$permissions": ["create(\"users\")"],
      "databaseId": "eve",
      "name": "symptom_logs",
      "enabled": true,
      "rowSecurity": true,
      "columns": [
        { "key": "userId", "type": "string", "required": true, "array": false, "size": 36 },
        { "key": "date", "type": "datetime", "required": true, "array": false, "format": "" },
        { "key": "symptoms", "type": "string", "required": false, "array": true, "size": 64, "default": null },
        { "key": "mood", "type": "string", "format": "enum", "elements": ["great", "good", "okay", "low", "difficult"], "required": false, "array": false, "size": 16, "default": null },
        { "key": "painLevel", "type": "integer", "required": false, "array": false, "min": 0, "max": 10, "default": null },
        { "key": "notes", "type": "string", "required": false, "array": false, "size": 2000, "default": "" }
      ],
      "indexes": [
        { "key": "idx_user_date", "type": "key", "columns": ["userId", "date"], "orders": ["ASC", "DESC"] }
      ]
    },
    {
      "$id": "preferences",
      "$permissions": [],
      "databaseId": "eve",
      "name": "preferences",
      "enabled": true,
      "rowSecurity": true,
      "columns": [
        { "key": "selectedGoals", "type": "string", "required": false, "array": true, "size": 64, "default": null },
        { "key": "dietType", "type": "string", "required": false, "array": false, "size": 40, "default": null },
        { "key": "foodAllergies", "type": "string", "required": false, "array": false, "size": 500, "default": "" },
        { "key": "cuisines", "type": "string", "required": false, "array": true, "size": 64, "default": null },
        { "key": "workoutPreference", "type": "string", "required": false, "array": true, "size": 64, "default": null },
        { "key": "enabledReminders", "type": "string", "format": "enum", "elements": ["morning", "medicine", "workout", "water", "sleep", "cycle", "appointment", "mood", "daily_tip"], "required": false, "array": true, "size": 16, "default": null },
        { "key": "enabledHelpAreas", "type": "string", "format": "enum", "elements": ["healthQuestions", "nutrition", "workouts", "mentalWellbeing", "medicationReminders", "doctorPrep"], "required": false, "array": true, "size": 32, "default": null },
        { "key": "selectedTheme", "type": "string", "format": "enum", "elements": ["light", "dark", "default"], "required": false, "array": false, "size": 8, "default": "default" }
      ],
      "indexes": []
    },
    {
      "$id": "partner_links",
      "$permissions": [],
      "databaseId": "eve",
      "name": "partner_links",
      "enabled": true,
      "rowSecurity": true,
      "columns": [
        { "key": "partnerUserId", "type": "string", "required": false, "array": false, "size": 36, "default": null },
        { "key": "relationshipType", "type": "string", "required": false, "array": false, "size": 40, "default": null },
        { "key": "inviteStatus", "type": "string", "format": "enum", "elements": ["none", "pending", "accepted", "declined"], "required": false, "array": false, "size": 16, "default": "none" },
        { "key": "inviteCode", "type": "string", "required": false, "array": false, "size": 8, "default": null },
        { "key": "invitedAt", "type": "datetime", "required": false, "array": false, "format": "", "default": null },
        { "key": "linkedAt", "type": "datetime", "required": false, "array": false, "format": "", "default": null }
      ],
      "indexes": [
        { "key": "idx_invite_code", "type": "key", "columns": ["inviteCode"], "orders": ["ASC"] }
      ]
    },
    {
      "$id": "partner_permissions",
      "$permissions": [],
      "databaseId": "eve",
      "name": "partner_permissions",
      "enabled": true,
      "rowSecurity": true,
      "columns": [
        { "key": "approvedCategories", "type": "string", "format": "enum", "elements": ["appointmentReminders", "pregnancyMilestones", "supportSuggestions", "moodUpdates"], "required": false, "array": true, "size": 32, "default": null },
        { "key": "onlyApproveMode", "type": "boolean", "required": false, "array": false, "default": true }
      ],
      "indexes": []
    },
    {
      "$id": "partner_views",
      "$permissions": [],
      "databaseId": "eve",
      "name": "partner_views",
      "enabled": true,
      "rowSecurity": true,
      "columns": [
        { "key": "primaryUserId", "type": "string", "required": true, "array": false, "size": 36 },
        { "key": "approvedCategories", "type": "string", "format": "enum", "elements": ["appointmentReminders", "pregnancyMilestones", "supportSuggestions", "moodUpdates"], "required": false, "array": true, "size": 32, "default": null },
        { "key": "upcomingAppointmentLabel", "type": "string", "required": false, "array": false, "size": 120, "default": null },
        { "key": "upcomingAppointmentAt", "type": "datetime", "required": false, "array": false, "format": "", "default": null },
        { "key": "pregnancyCurrentWeek", "type": "integer", "required": false, "array": false, "min": 0, "max": 45, "default": null },
        { "key": "pregnancyLatestMilestone", "type": "string", "required": false, "array": false, "size": 120, "default": null },
        { "key": "supportSuggested", "type": "boolean", "required": false, "array": false, "default": null },
        { "key": "supportReason", "type": "string", "format": "enum", "elements": ["highPain", "multipleSymptoms"], "required": false, "array": false, "size": 20, "default": null },
        { "key": "recentMoodTrend", "type": "string", "format": "enum", "elements": ["low", "neutral", "positive"], "required": false, "array": false, "size": 10, "default": null },
        { "key": "recomputedAt", "type": "datetime", "required": false, "array": false, "format": "", "default": null }
      ],
      "indexes": []
    },
    {
      "$id": "partner_lookups",
      "$permissions": [],
      "databaseId": "eve",
      "name": "partner_lookups",
      "enabled": true,
      "rowSecurity": true,
      "columns": [
        { "key": "primaryUserId", "type": "string", "required": true, "array": false, "size": 36 },
        { "key": "relationshipType", "type": "string", "required": false, "array": false, "size": 40, "default": null },
        { "key": "linkedAt", "type": "datetime", "required": true, "array": false, "format": "" }
      ],
      "indexes": []
    },
    {
      "$id": "chat_messages",
      "$permissions": [],
      "databaseId": "eve",
      "name": "chat_messages",
      "enabled": true,
      "rowSecurity": true,
      "columns": [
        { "key": "threadUserId", "type": "string", "required": true, "array": false, "size": 36 },
        { "key": "senderRole", "type": "string", "format": "enum", "elements": ["her", "partner", "system"], "required": true, "array": false, "size": 8 },
        { "key": "senderUserId", "type": "string", "required": false, "array": false, "size": 36, "default": null },
        { "key": "messageText", "type": "string", "required": true, "array": false, "size": 2000 },
        { "key": "sentAt", "type": "datetime", "required": true, "array": false, "format": "" },
        { "key": "type", "type": "string", "format": "enum", "elements": ["text", "system"], "required": true, "array": false, "size": 8 },
        { "key": "category", "type": "string", "format": "enum", "elements": ["supportSuggestion", "moodUpdate"], "required": false, "array": false, "size": 20, "default": null },
        { "key": "sourceLogId", "type": "string", "required": false, "array": false, "size": 36, "default": null }
      ],
      "indexes": [
        { "key": "idx_thread_sent", "type": "key", "columns": ["threadUserId", "sentAt"], "orders": ["ASC", "ASC"] }
      ]
    }
  ],
```

- [ ] **Step 4: Run to verify it passes**

Run: `npx vitest run shared/test/schema.test.ts`
Expected: all schema cases pass (9 + 9 table cases, 4 server-only cases, 3 single cases).

- [ ] **Step 5: Push to the local Appwrite and confirm the CLI accepted every column**

Run (from `EVE_MOBILE/`, with the local Docker Appwrite from Plan 3 Task 1 running and `appwrite login` done):

```bash
appwrite push tables --all --force
appwrite pull tables
git diff --stat appwrite.config.json
```

Expected: push reports 9 tables created. `pull` rewrites the file with server-normalized fields (`status`, `$createdAt`, etc.). Re-run `npx vitest run shared/test/schema.test.ts` — it must still pass. If the CLI renamed a key (for example an index's `columns` → `attributes`), keep the server's spelling and update the `indexes` assertion in the test to read that key — the server's format is authoritative.

- [ ] **Step 6: Manual permission check (local Appwrite)**

In the local console (`http://localhost/console`), create two test users `alice` and `bob` (Auth → Users), then from the console's API playground or a scratch script signed in as **bob**, try `TablesDB.createRow` on `chat_messages` and `partner_views`. Expected: `401 user_unauthorized` for both. Try `TablesDB.createRow` on `symptom_logs` with permissions `["read(\"user:alice\")"]` while signed in as bob. Expected: `401` — Appwrite rejects permissions for a role bob doesn't hold (this is the fact `isOwnedBy` relies on).

- [ ] **Step 7: Commit**

```bash
git add EVE_MOBILE/appwrite.config.json EVE_MOBILE/functions/shared/test/schema.test.ts
git commit -m "feat: declare eve TablesDB schema with row-security permission model"
```

---

## Task 4: Dart mirror models

**Files:**
- Create: `EVE_MOBILE/app/lib/shared/models/row_parsing.dart`
- Create: `EVE_MOBILE/app/lib/shared/models/user_profile.dart`
- Create: `EVE_MOBILE/app/lib/shared/models/life_stage_profile.dart`
- Create: `EVE_MOBILE/app/lib/shared/models/symptom_log.dart`
- Create: `EVE_MOBILE/app/lib/shared/models/preferences.dart`
- Create: `EVE_MOBILE/app/lib/shared/models/partner_link.dart`
- Create: `EVE_MOBILE/app/lib/shared/models/partner_permissions.dart`
- Create: `EVE_MOBILE/app/lib/shared/models/partner_view.dart`
- Create: `EVE_MOBILE/app/lib/shared/models/chat_message.dart`
- Test: `EVE_MOBILE/app/test/shared/models/models_test.dart`

**Interfaces:**
- Consumes: column names from Task 1's `types.ts` (must mirror exactly).
- Produces: `UserProfile`, `LifeStageProfile` (abstract) + `EmptyLifeStageProfile`/`CycleLifeStageProfile`/`PregnantLifeStageProfile`/`SimplifiedLifeStageProfile`, `SymptomLog`, `Preferences`, `PartnerLink`, `PartnerPermissions`, `PartnerView`, `ChatMessage`. Every class has `factory X.fromRow(Map<String, dynamic> data, {String? id})` (accepts an Appwrite `models.Row.data` map) and `Map<String, dynamic> toRow()`. No `package:appwrite` import in this directory.

- [ ] **Step 1: Write the failing tests**

Create `EVE_MOBILE/app/test/shared/models/models_test.dart`:

```dart
import 'package:eve_app/shared/models/chat_message.dart';
import 'package:eve_app/shared/models/life_stage_profile.dart';
import 'package:eve_app/shared/models/partner_permissions.dart';
import 'package:eve_app/shared/models/partner_view.dart';
import 'package:eve_app/shared/models/preferences.dart';
import 'package:eve_app/shared/models/symptom_log.dart';
import 'package:eve_app/shared/models/user_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('UserProfile round-trips and tolerates nulls', () {
    const profile = UserProfile(name: 'Priya', age: 29, height: 165, weight: 58, country: 'India', lifeStage: 'cycle');
    final back = UserProfile.fromRow(profile.toRow());
    expect(back.name, 'Priya');
    expect(back.age, 29);
    expect(back.lifeStage, 'cycle');
    expect(UserProfile.fromRow(const {'name': ''}).age, isNull);
  });

  test('LifeStageProfile.fromRow dispatches on type and toRow clears other branches', () {
    const cycle = CycleLifeStageProfile(
      cycleLength: 28, periodLength: 5, flow: 'moderate',
      cycleSymptoms: ['cramps'], cycleGoals: ['betterNutrition'], nutritionDiet: 'vegan',
    );
    final row = cycle.toRow();
    expect(row['type'], 'cycle');
    expect(row['dueDate'], isNull);
    expect(row['pregnantSymptoms'], isEmpty);
    expect(row['simplifiedGoals'], isEmpty);
    final back = LifeStageProfile.fromRow(row) as CycleLifeStageProfile;
    expect(back.cycleLength, 28);
    expect(back.nutritionDiet, 'vegan');

    final pregnant = PregnantLifeStageProfile(
      dueDate: DateTime.utc(2026, 6, 1), dueMethod: 'dueDate', highRisk: false, pregnancyType: 'single',
      medications: null, allergies: 'peanuts', prenatalVitamins: true, pregnantSymptoms: const ['swelling'],
    );
    final pregnantBack = LifeStageProfile.fromRow(pregnant.toRow()) as PregnantLifeStageProfile;
    expect(pregnantBack.dueDate, DateTime.utc(2026, 6, 1));
    expect(pregnantBack.prenatalVitamins, isTrue);

    const simplified = SimplifiedLifeStageProfile(type: 'menopause', simplifiedSymptoms: ['hotFlashes'], simplifiedGoals: []);
    expect(LifeStageProfile.fromRow(simplified.toRow()), isA<SimplifiedLifeStageProfile>());
    expect(LifeStageProfile.fromRow(const {'type': null}), isA<EmptyLifeStageProfile>());
  });

  test('SymptomLog parses Appwrite ISO datetimes with offsets', () {
    final log = SymptomLog.fromRow({
      'userId': 'u1',
      'date': '2026-03-14T00:00:00.000+00:00',
      'symptoms': ['cramps'],
      'mood': 'low',
      'painLevel': 6,
      'notes': '',
    }, id: 'log1');
    expect(log.id, 'log1');
    expect(log.date, DateTime.utc(2026, 3, 14));
    expect(log.toRow()['date'], '2026-03-14T00:00:00.000Z');
  });

  test('Preferences, PartnerPermissions, PartnerView and ChatMessage round-trip', () {
    const prefs = Preferences(
      selectedGoals: ['betterNutrition'], dietType: 'vegan', foodAllergies: '', cuisines: ['indian'],
      workoutPreference: ['yoga'], enabledReminders: ['morning'], enabledHelpAreas: ['nutrition'], selectedTheme: 'dark',
    );
    expect(Preferences.fromRow(prefs.toRow()).selectedTheme, 'dark');

    const perms = PartnerPermissions(approvedCategories: ['moodUpdates'], onlyApproveMode: true);
    expect(PartnerPermissions.fromRow(perms.toRow()).approvedCategories, ['moodUpdates']);

    final view = PartnerView.fromRow(const {
      'primaryUserId': 'u1', 'approvedCategories': ['moodUpdates'], 'recentMoodTrend': 'low',
      'supportSuggested': null, 'recomputedAt': '2026-03-14T10:00:00.000+00:00',
    });
    expect(view.recentMoodTrend, 'low');
    expect(view.supportSuggested, isNull);

    final message = ChatMessage.fromRow(const {
      'threadUserId': 'u1', 'senderRole': 'system', 'senderUserId': null, 'messageText': 'Eve: check in',
      'sentAt': '2026-03-14T10:00:00.000+00:00', 'type': 'system', 'category': 'moodUpdate', 'sourceLogId': 'log1',
    }, id: 'sys-log1');
    expect(message.id, 'sys-log1');
    expect(message.senderRole, 'system');
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run (from `EVE_MOBILE/app/`): `flutter test test/shared/models/models_test.dart`
Expected: FAIL — `Error when reading 'lib/shared/models/chat_message.dart'`.

- [ ] **Step 3: Implement the shared parsing helpers**

Create `EVE_MOBILE/app/lib/shared/models/row_parsing.dart`:

```dart
/// Helpers shared by every model in this directory. Appwrite returns
/// datetimes as ISO 8601 strings (e.g. `2026-03-14T00:00:00.000+00:00`),
/// numbers as int or double, and arrays as `List<dynamic>`.
DateTime? parseDateTime(Object? value) {
  if (value == null) return null;
  if (value is DateTime) return value.toUtc();
  return DateTime.parse(value as String).toUtc();
}

String? formatDateTime(DateTime? value) => value?.toUtc().toIso8601String();

List<String> parseStringList(Object? value) =>
    value == null ? const [] : List<String>.from(value as List);

int? parseInt(Object? value) => value == null ? null : (value as num).toInt();

double? parseDouble(Object? value) => value == null ? null : (value as num).toDouble();
```

- [ ] **Step 4: Implement the models**

Create `EVE_MOBILE/app/lib/shared/models/user_profile.dart`:

```dart
import 'row_parsing.dart';

/// Mirrors functions/shared/src/types.ts `ProfileRow`. Table `profiles`, rowId = uid.
class UserProfile {
  const UserProfile({
    required this.name,
    this.age,
    this.height,
    this.weight,
    this.country,
    this.lifeStage,
  });

  final String name;
  final int? age;
  final double? height; // centimeters
  final double? weight; // kilograms
  final String? country;
  final String? lifeStage;

  factory UserProfile.fromRow(Map<String, dynamic> data) => UserProfile(
        name: (data['name'] as String?) ?? '',
        age: parseInt(data['age']),
        height: parseDouble(data['height']),
        weight: parseDouble(data['weight']),
        country: data['country'] as String?,
        lifeStage: data['lifeStage'] as String?,
      );

  Map<String, dynamic> toRow() => {
        'name': name,
        'age': age,
        'height': height,
        'weight': weight,
        'country': country,
        'lifeStage': lifeStage,
      };
}
```

Create `EVE_MOBILE/app/lib/shared/models/life_stage_profile.dart`:

```dart
import 'row_parsing.dart';

/// Mirrors `LifeStageProfileRow`. Table `life_stage_profiles`, rowId = uid.
/// One flattened row; `toRow()` always emits every column so saving one
/// branch clears the columns of the others.
abstract class LifeStageProfile {
  const LifeStageProfile();

  String? get type;

  factory LifeStageProfile.fromRow(Map<String, dynamic> data) {
    switch (data['type'] as String?) {
      case 'cycle':
        return CycleLifeStageProfile(
          cycleLength: parseInt(data['cycleLength']),
          periodLength: parseInt(data['periodLength']),
          flow: data['flow'] as String?,
          cycleSymptoms: parseStringList(data['cycleSymptoms']),
          cycleGoals: parseStringList(data['cycleGoals']),
          nutritionDiet: data['nutritionDiet'] as String?,
        );
      case 'pregnant':
        return PregnantLifeStageProfile(
          dueDate: parseDateTime(data['dueDate']),
          dueMethod: data['dueMethod'] as String?,
          highRisk: data['highRisk'] as bool?,
          pregnancyType: data['pregnancyType'] as String?,
          medications: data['medications'] as String?,
          allergies: data['allergies'] as String?,
          prenatalVitamins: data['prenatalVitamins'] as bool?,
          pregnantSymptoms: parseStringList(data['pregnantSymptoms']),
          currentWeek: parseInt(data['currentWeek']),
          nextAppointmentLabel: data['nextAppointmentLabel'] as String?,
          nextAppointmentAt: parseDateTime(data['nextAppointmentAt']),
          latestMilestone: data['latestMilestone'] as String?,
        );
      case 'conceive':
      case 'postpartum':
      case 'menopause':
        return SimplifiedLifeStageProfile(
          type: data['type'] as String,
          simplifiedSymptoms: parseStringList(data['simplifiedSymptoms']),
          simplifiedGoals: parseStringList(data['simplifiedGoals']),
        );
      default:
        return const EmptyLifeStageProfile();
    }
  }

  /// Branch-specific columns; merged over [blankRow] by [toRow].
  Map<String, dynamic> branchColumns();

  Map<String, dynamic> toRow() => {...blankRow(), 'type': type, ...branchColumns()};

  static Map<String, dynamic> blankRow() => {
        'type': null,
        'cycleLength': null,
        'periodLength': null,
        'flow': null,
        'cycleSymptoms': <String>[],
        'cycleGoals': <String>[],
        'nutritionDiet': null,
        'dueDate': null,
        'dueMethod': null,
        'highRisk': null,
        'pregnancyType': null,
        'medications': null,
        'allergies': null,
        'prenatalVitamins': null,
        'pregnantSymptoms': <String>[],
        'currentWeek': null,
        'nextAppointmentLabel': null,
        'nextAppointmentAt': null,
        'latestMilestone': null,
        'simplifiedSymptoms': <String>[],
        'simplifiedGoals': <String>[],
      };
}

class EmptyLifeStageProfile extends LifeStageProfile {
  const EmptyLifeStageProfile();

  @override
  String? get type => null;

  @override
  Map<String, dynamic> branchColumns() => const {};
}

class CycleLifeStageProfile extends LifeStageProfile {
  const CycleLifeStageProfile({
    this.cycleLength,
    this.periodLength,
    this.flow,
    this.cycleSymptoms = const [],
    this.cycleGoals = const [],
    this.nutritionDiet,
  });

  final int? cycleLength;
  final int? periodLength;
  final String? flow;
  final List<String> cycleSymptoms;
  final List<String> cycleGoals;
  final String? nutritionDiet;

  @override
  String get type => 'cycle';

  @override
  Map<String, dynamic> branchColumns() => {
        'cycleLength': cycleLength,
        'periodLength': periodLength,
        'flow': flow,
        'cycleSymptoms': cycleSymptoms,
        'cycleGoals': cycleGoals,
        'nutritionDiet': nutritionDiet,
      };
}

class PregnantLifeStageProfile extends LifeStageProfile {
  const PregnantLifeStageProfile({
    this.dueDate,
    this.dueMethod,
    this.highRisk,
    this.pregnancyType,
    this.medications,
    this.allergies,
    this.prenatalVitamins,
    this.pregnantSymptoms = const [],
    this.currentWeek,
    this.nextAppointmentLabel,
    this.nextAppointmentAt,
    this.latestMilestone,
  });

  final DateTime? dueDate;
  final String? dueMethod;
  final bool? highRisk;
  final String? pregnancyType;
  final String? medications;
  final String? allergies;
  final bool? prenatalVitamins;
  final List<String> pregnantSymptoms;
  final int? currentWeek;
  final String? nextAppointmentLabel;
  final DateTime? nextAppointmentAt;
  final String? latestMilestone;

  @override
  String get type => 'pregnant';

  @override
  Map<String, dynamic> branchColumns() => {
        'dueDate': formatDateTime(dueDate),
        'dueMethod': dueMethod,
        'highRisk': highRisk,
        'pregnancyType': pregnancyType,
        'medications': medications,
        'allergies': allergies,
        'prenatalVitamins': prenatalVitamins,
        'pregnantSymptoms': pregnantSymptoms,
        'currentWeek': currentWeek,
        'nextAppointmentLabel': nextAppointmentLabel,
        'nextAppointmentAt': formatDateTime(nextAppointmentAt),
        'latestMilestone': latestMilestone,
      };
}

class SimplifiedLifeStageProfile extends LifeStageProfile {
  const SimplifiedLifeStageProfile({
    required this.type,
    this.simplifiedSymptoms = const [],
    this.simplifiedGoals = const [],
  });

  @override
  final String type; // 'conceive' | 'postpartum' | 'menopause'
  final List<String> simplifiedSymptoms;
  final List<String> simplifiedGoals;

  @override
  Map<String, dynamic> branchColumns() => {
        'simplifiedSymptoms': simplifiedSymptoms,
        'simplifiedGoals': simplifiedGoals,
      };
}
```

Create `EVE_MOBILE/app/lib/shared/models/symptom_log.dart`:

```dart
import 'row_parsing.dart';

/// Mirrors `SymptomLogRow`. Table `symptom_logs`, rowId = ID.unique().
class SymptomLog {
  const SymptomLog({
    this.id,
    required this.userId,
    required this.date,
    this.symptoms = const [],
    this.mood,
    this.painLevel,
    this.notes = '',
  });

  final String? id;
  final String userId;
  final DateTime date;
  final List<String> symptoms;
  final String? mood; // great | good | okay | low | difficult
  final int? painLevel; // 0-10
  final String notes;

  factory SymptomLog.fromRow(Map<String, dynamic> data, {String? id}) => SymptomLog(
        id: id,
        userId: data['userId'] as String,
        date: parseDateTime(data['date'])!,
        symptoms: parseStringList(data['symptoms']),
        mood: data['mood'] as String?,
        painLevel: parseInt(data['painLevel']),
        notes: (data['notes'] as String?) ?? '',
      );

  Map<String, dynamic> toRow() => {
        'userId': userId,
        'date': formatDateTime(date),
        'symptoms': symptoms,
        'mood': mood,
        'painLevel': painLevel,
        'notes': notes,
      };
}
```

Create `EVE_MOBILE/app/lib/shared/models/preferences.dart`:

```dart
import 'row_parsing.dart';

/// Mirrors `PreferencesRow`. Table `preferences`, rowId = uid. Replaces the
/// four Firestore-era preference documents (goals, notifications, aiScope, theme).
class Preferences {
  const Preferences({
    this.selectedGoals = const [],
    this.dietType,
    this.foodAllergies = '',
    this.cuisines = const [],
    this.workoutPreference = const [],
    this.enabledReminders = const [],
    this.enabledHelpAreas = const [],
    this.selectedTheme = 'default',
  });

  final List<String> selectedGoals;
  final String? dietType;
  final String foodAllergies;
  final List<String> cuisines;
  final List<String> workoutPreference;
  final List<String> enabledReminders;
  final List<String> enabledHelpAreas;
  final String selectedTheme;

  factory Preferences.fromRow(Map<String, dynamic> data) => Preferences(
        selectedGoals: parseStringList(data['selectedGoals']),
        dietType: data['dietType'] as String?,
        foodAllergies: (data['foodAllergies'] as String?) ?? '',
        cuisines: parseStringList(data['cuisines']),
        workoutPreference: parseStringList(data['workoutPreference']),
        enabledReminders: parseStringList(data['enabledReminders']),
        enabledHelpAreas: parseStringList(data['enabledHelpAreas']),
        selectedTheme: (data['selectedTheme'] as String?) ?? 'default',
      );

  Map<String, dynamic> toRow() => {
        'selectedGoals': selectedGoals,
        'dietType': dietType,
        'foodAllergies': foodAllergies,
        'cuisines': cuisines,
        'workoutPreference': workoutPreference,
        'enabledReminders': enabledReminders,
        'enabledHelpAreas': enabledHelpAreas,
        'selectedTheme': selectedTheme,
      };
}
```

Create `EVE_MOBILE/app/lib/shared/models/partner_link.dart`:

```dart
import 'row_parsing.dart';

/// Mirrors `PartnerLinkRow`. Table `partner_links`, rowId = primary uid.
/// Read-only on the client — written by the `partnerInvites` function.
class PartnerLink {
  const PartnerLink({
    this.partnerUserId,
    this.relationshipType,
    this.inviteStatus = 'none',
    this.inviteCode,
    this.invitedAt,
    this.linkedAt,
  });

  final String? partnerUserId;
  final String? relationshipType;
  final String inviteStatus; // none | pending | accepted | declined
  final String? inviteCode;
  final DateTime? invitedAt;
  final DateTime? linkedAt;

  factory PartnerLink.fromRow(Map<String, dynamic> data) => PartnerLink(
        partnerUserId: data['partnerUserId'] as String?,
        relationshipType: data['relationshipType'] as String?,
        inviteStatus: (data['inviteStatus'] as String?) ?? 'none',
        inviteCode: data['inviteCode'] as String?,
        invitedAt: parseDateTime(data['invitedAt']),
        linkedAt: parseDateTime(data['linkedAt']),
      );
}
```

Create `EVE_MOBILE/app/lib/shared/models/partner_permissions.dart`:

```dart
import 'row_parsing.dart';

/// Mirrors `PartnerPermissionsRow`. Table `partner_permissions`, rowId = uid.
class PartnerPermissions {
  const PartnerPermissions({this.approvedCategories = const [], this.onlyApproveMode = true});

  /// appointmentReminders | pregnancyMilestones | supportSuggestions | moodUpdates
  final List<String> approvedCategories;
  final bool onlyApproveMode;

  factory PartnerPermissions.fromRow(Map<String, dynamic> data) => PartnerPermissions(
        approvedCategories: parseStringList(data['approvedCategories']),
        onlyApproveMode: (data['onlyApproveMode'] as bool?) ?? true,
      );

  Map<String, dynamic> toRow() => {
        'approvedCategories': approvedCategories,
        'onlyApproveMode': onlyApproveMode,
      };
}
```

Create `EVE_MOBILE/app/lib/shared/models/partner_view.dart`:

```dart
import 'row_parsing.dart';

/// Mirrors `PartnerViewRow`. Table `partner_views`, rowId = primary uid.
/// Read-only on every client. A null field means "not shared".
class PartnerView {
  const PartnerView({
    required this.primaryUserId,
    this.approvedCategories = const [],
    this.upcomingAppointmentLabel,
    this.upcomingAppointmentAt,
    this.pregnancyCurrentWeek,
    this.pregnancyLatestMilestone,
    this.supportSuggested,
    this.supportReason,
    this.recentMoodTrend,
    this.recomputedAt,
  });

  final String primaryUserId;
  final List<String> approvedCategories;
  final String? upcomingAppointmentLabel;
  final DateTime? upcomingAppointmentAt;
  final int? pregnancyCurrentWeek;
  final String? pregnancyLatestMilestone;
  final bool? supportSuggested;
  final String? supportReason; // highPain | multipleSymptoms
  final String? recentMoodTrend; // low | neutral | positive
  final DateTime? recomputedAt;

  factory PartnerView.fromRow(Map<String, dynamic> data) => PartnerView(
        primaryUserId: data['primaryUserId'] as String,
        approvedCategories: parseStringList(data['approvedCategories']),
        upcomingAppointmentLabel: data['upcomingAppointmentLabel'] as String?,
        upcomingAppointmentAt: parseDateTime(data['upcomingAppointmentAt']),
        pregnancyCurrentWeek: parseInt(data['pregnancyCurrentWeek']),
        pregnancyLatestMilestone: data['pregnancyLatestMilestone'] as String?,
        supportSuggested: data['supportSuggested'] as bool?,
        supportReason: data['supportReason'] as String?,
        recentMoodTrend: data['recentMoodTrend'] as String?,
        recomputedAt: parseDateTime(data['recomputedAt']),
      );
}
```

Create `EVE_MOBILE/app/lib/shared/models/chat_message.dart`:

```dart
import 'row_parsing.dart';

/// Mirrors `ChatMessageRow`. Table `chat_messages`. Read-only on the client:
/// messages are sent through the `sendChatMessage` function.
class ChatMessage {
  const ChatMessage({
    this.id,
    required this.threadUserId,
    required this.senderRole,
    this.senderUserId,
    required this.messageText,
    required this.sentAt,
    required this.type,
    this.category,
    this.sourceLogId,
  });

  final String? id;
  final String threadUserId;
  final String senderRole; // her | partner | system
  final String? senderUserId;
  final String messageText;
  final DateTime sentAt;
  final String type; // text | system
  final String? category;
  final String? sourceLogId;

  factory ChatMessage.fromRow(Map<String, dynamic> data, {String? id}) => ChatMessage(
        id: id,
        threadUserId: data['threadUserId'] as String,
        senderRole: data['senderRole'] as String,
        senderUserId: data['senderUserId'] as String?,
        messageText: data['messageText'] as String,
        sentAt: parseDateTime(data['sentAt'])!,
        type: data['type'] as String,
        category: data['category'] as String?,
        sourceLogId: data['sourceLogId'] as String?,
      );
}
```

- [ ] **Step 5: Run to verify it passes**

Run: `flutter test test/shared/models/models_test.dart`
Expected: `All tests passed!` (4 tests).

- [ ] **Step 6: Commit**

```bash
git add EVE_MOBILE/app/lib/shared/models EVE_MOBILE/app/test/shared/models/models_test.dart
git commit -m "feat(app): add Dart mirror models for the eve TablesDB schema"
```

---

## Task 5: `onUserCreate` function (idempotent)

**Files:**
- Create: `EVE_MOBILE/functions/onUserCreate/src/initializeUser.ts`
- Create: `EVE_MOBILE/functions/onUserCreate/src/main.ts`
- Test: `EVE_MOBILE/functions/onUserCreate/test/initializeUser.test.ts`
- Modify: `EVE_MOBILE/appwrite.config.json` (append to `functions`)

**Interfaces:**
- Consumes: `Db`, `RowConflictError`, `serverDb` (Task 2), `ownerEditable`, `ownerReadOnly` (Task 2), row types (Task 1), `FunctionContext` (Plan 3 Task 5's `shared/src/appwrite.ts`).
- Produces: `defaultRowsFor(uid, name)`, `initializeUserRows(db, uid, name): Promise<TableId[]>` (returns the tables it actually created), and the deployed `onUserCreate` function on event `users.*.create`.

**Why idempotent instead of atomic:** Firestore's `WriteBatch` made all 7 docs appear together. Appwrite events are delivered asynchronously and may be retried, so instead each missing row is created and existing rows are never overwritten — a retry after a partial failure fills only the gaps, and a duplicate delivery is a no-op. The client repositories (Plan 4 M14/M16) treat a missing singleton row as defaults, so a user signing in during the few seconds before the function finishes never crashes.

- [ ] **Step 1: Write the failing tests**

Create `EVE_MOBILE/functions/onUserCreate/test/initializeUser.test.ts`:

```ts
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
```

- [ ] **Step 2: Run to verify it fails**

Run: `npx vitest run onUserCreate`
Expected: FAIL — `Failed to resolve import "../src/initializeUser.js"`.

- [ ] **Step 3: Implement `EVE_MOBILE/functions/onUserCreate/src/initializeUser.ts`**

```ts
import { RowConflictError, type Db } from '../../shared/src/db.js';
import { TABLES, type TableId } from '../../shared/src/ids.js';
import { ownerEditable, ownerReadOnly } from '../../shared/src/permissions.js';
import type {
  LifeStageProfileRow,
  PartnerLinkRow,
  PartnerPermissionsRow,
  PartnerViewRow,
  PreferencesRow,
  ProfileRow,
} from '../../shared/src/types.js';

interface DefaultRow {
  tableId: TableId;
  data: object;
  permissions: string[];
}

export function defaultRowsFor(uid: string, name: string): DefaultRow[] {
  const profile: ProfileRow = { name, age: null, height: null, weight: null, country: null, lifeStage: null };
  const lifeStage: LifeStageProfileRow = {
    type: null, cycleLength: null, periodLength: null, flow: null, cycleSymptoms: [], cycleGoals: [],
    nutritionDiet: null, dueDate: null, dueMethod: null, highRisk: null, pregnancyType: null, medications: null,
    allergies: null, prenatalVitamins: null, pregnantSymptoms: [], currentWeek: null, nextAppointmentLabel: null,
    nextAppointmentAt: null, latestMilestone: null, simplifiedSymptoms: [], simplifiedGoals: [],
  };
  const preferences: PreferencesRow = {
    selectedGoals: [], dietType: null, foodAllergies: '', cuisines: [], workoutPreference: [],
    enabledReminders: [], enabledHelpAreas: [], selectedTheme: 'default',
  };
  const partnerPermissions: PartnerPermissionsRow = { approvedCategories: [], onlyApproveMode: true };
  const partnerLink: PartnerLinkRow = {
    partnerUserId: null, relationshipType: null, inviteStatus: 'none', inviteCode: null, invitedAt: null, linkedAt: null,
  };
  const partnerView: PartnerViewRow = {
    primaryUserId: uid, approvedCategories: [], upcomingAppointmentLabel: null, upcomingAppointmentAt: null,
    pregnancyCurrentWeek: null, pregnancyLatestMilestone: null, supportSuggested: null, supportReason: null,
    recentMoodTrend: null, recomputedAt: null,
  };

  return [
    { tableId: TABLES.profiles, data: profile, permissions: ownerEditable(uid) },
    { tableId: TABLES.lifeStageProfiles, data: lifeStage, permissions: ownerEditable(uid) },
    { tableId: TABLES.preferences, data: preferences, permissions: ownerEditable(uid) },
    { tableId: TABLES.partnerPermissions, data: partnerPermissions, permissions: ownerEditable(uid) },
    { tableId: TABLES.partnerLinks, data: partnerLink, permissions: ownerReadOnly(uid) },
    { tableId: TABLES.partnerViews, data: partnerView, permissions: ownerReadOnly(uid) },
  ];
}

/** Creates each missing singleton row; never overwrites. Returns what it created. */
export async function initializeUserRows(db: Db, uid: string, name: string): Promise<TableId[]> {
  const created: TableId[] = [];
  for (const row of defaultRowsFor(uid, name)) {
    if (await db.getRow(row.tableId, uid)) continue;
    try {
      await db.createRow(row.tableId, uid, row.data, row.permissions);
      created.push(row.tableId);
    } catch (e) {
      // A concurrent delivery of the same event won the race — fine.
      if (!(e instanceof RowConflictError)) throw e;
    }
  }
  return created;
}
```

- [ ] **Step 4: Implement the entrypoint `EVE_MOBILE/functions/onUserCreate/src/main.ts`**

```ts
import type { FunctionContext } from '../../shared/src/appwrite.js';
import { serverDb } from '../../shared/src/db.js';
import { initializeUserRows } from './initializeUser.js';

// Event: users.*.create — the payload is the new user object.
export default async (context: FunctionContext) => {
  const user = context.req.bodyJson as { $id?: string; name?: string } | undefined;
  if (!user?.$id) {
    context.error('onUserCreate: event payload has no user $id');
    return context.res.json({ ok: false }, 400);
  }
  const created = await initializeUserRows(serverDb(context), user.$id, user.name ?? '');
  context.log(`onUserCreate ${user.$id}: created ${created.join(', ') || 'nothing (already initialized)'}`);
  return context.res.json({ ok: true, created });
};
```

- [ ] **Step 5: Register the function — append to `functions` in `EVE_MOBILE/appwrite.config.json`**

```json
    {
      "$id": "onUserCreate",
      "name": "onUserCreate",
      "runtime": "node-22",
      "specification": "s-0.5vcpu-512mb",
      "execute": [],
      "events": ["users.*.create"],
      "scopes": ["users.read", "rows.read", "rows.write"],
      "schedule": "",
      "timeout": 30,
      "enabled": true,
      "logging": true,
      "entrypoint": "dist/onUserCreate/src/main.js",
      "commands": "npm ci && npm run build",
      "path": "functions"
    }
```

- [ ] **Step 6: Run to verify it passes**

Run: `npx vitest run onUserCreate && npx tsc --noEmit`
Expected: `3 passed`; `tsc` exits 0.

- [ ] **Step 7: Deploy locally and verify end-to-end**

```bash
cd EVE_MOBILE
appwrite push functions --function-id onUserCreate --force
```

In the local console, create a user (Auth → Users → Create). Expected within a few seconds: Functions → onUserCreate → Executions shows one `completed` event execution whose log reads `created profiles, life_stage_profiles, preferences, partner_permissions, partner_links, partner_views`; Databases → eve shows a row with that user's ID in each of those 6 tables. Re-run the execution from the console ("Execute" with the same payload) — the log reads `created nothing (already initialized)`.

- [ ] **Step 8: Commit**

```bash
git add EVE_MOBILE/functions/onUserCreate EVE_MOBILE/appwrite.config.json
git commit -m "feat(functions): add idempotent onUserCreate initializer"
```

---

## Self-Review

**1. Spec coverage.** All 9 tables in design-spec §10 have columns, indexes and permissions (Task 3) and TS + Dart shapes (Tasks 1, 4). Server-only tables are enforced by an automated test (Task 3 Step 1) and a manual 401 check (Step 6). `onUserCreate` initializes every singleton row and survives redelivery (Task 5). Device tokens are intentionally absent (assumption 8).

**2. Placeholder scan.** No TBDs. The one externally-sensitive step — the CLI's exact JSON spelling for indexes — has an explicit "server's format wins, update the test" instruction (Task 3 Step 5) rather than a guess left unverified.

**3. Type consistency.** Column keys are asserted equal across `types.ts`, `appwrite.config.json` and the fixtures (schema test); the Dart models use the same keys (models test round-trips). `Db`/`MemoryDb`/`ownerEditable`/`ownerReadOnly`/`readersPermissions`/`isOwnedBy` are the names Plan 7 and Plan 3 import. Canonical vocabularies (mood, categories, reminders) match design-spec §10 and Plan 7.
