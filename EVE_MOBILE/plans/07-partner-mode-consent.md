# Partner Mode / Consent Enforcement Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the server-side Appwrite Functions that are the actual technical enforcement of EVE's Partner Mode consent model: the `partner_views` projection, the invite/accept link flow, the `sendChatMessage` function that makes chat sender identity unforgeable, and Eve's system-authored chat nudges.

**Architecture:** Four Appwrite Functions in the shared `functions/` package, all talking to storage through Plan 5's `Db` port (unit-tested against `MemoryDb`):
- `partnerView` — event-triggered on every create/update/upsert/delete of `symptom_logs`, `life_stage_profiles` and `partner_permissions`. It **fully recomputes** `partner_views/<uid>` from source rows (never patches), so out-of-order or duplicated events converge on the same result.
- `partnerInvites` — executed by the client. `createInvite` (her) writes a pending `partner_links` row with a short code; `acceptInvite` (partner) links the two accounts, writes `partner_lookups/<partnerUid>`, re-grants read on her `partner_views` row and existing chat rows to the partner.
- `sendChatMessage` — executed by the client; the **only** way a human chat message is written. The function decides `senderRole` from the caller's identity; the client never sends it.
- `chatSystemMessages` — event-triggered on `symptom_logs` create. When a qualifying log arrives and she has approved the matching category for an accepted partner, writes a `type: 'system'` message with the deterministic row ID `sys-<logId>` (so a redelivered event cannot duplicate it) and pushes a notification to the partner.
All four share `isCategoryApproved` from `partnerView/src/recompute.ts`.

**Tech Stack:** Appwrite Functions (Node.js 22, TypeScript ESM), `node-appwrite` 31.x (`TablesDB`, `Messaging`), Vitest, Plan 5's `Db`/`MemoryDb`/permission helpers, Plan 3's `FunctionContext`/`Messenger`.

## Global Constraints

- Functions runtime is Node.js 22 / TypeScript — design spec §2.
- Copy voice is formal and warm, no emojis — EVE2_PRD §6.
- Table IDs and canonical values are fixed by design spec §10; categories are `appointmentReminders | pregnancyMilestones | supportSuggestions | moodUpdates`, moods are `great | good | okay | low | difficult`.
- `partner_views`, `partner_links`, `partner_lookups`, `chat_messages` are server-written only (Plan 5 Task 3 enforces this with zero table permissions; this plan only ever writes them through the server `Db`).
- Every event-driven function is idempotent: re-running it with the same event yields the same stored state and sends no second notification.
- Every server function that trusts a client-written `userId` column first checks `isOwnedBy(row, userId)` (Plan 5 assumption 7).
- Canonical file paths: `functions/partnerView/src/{recompute,main}.ts`, `functions/partnerInvites/src/{invites,main}.ts`, `functions/sendChatMessage/src/{send,main}.ts`, `functions/chatSystemMessages/src/{nudge,main}.ts` — design spec §9.
- No diagnosis language; only coarse support/mood signals — EVE2_PRD §9.
- Requires Plan 5 Tasks 1–3 and Plan 3 Tasks 5 and 9 (for `Messenger`).

## Permission Category → `partner_views` Column Mapping

| Category | Source | Column(s) written | Derivation |
|---|---|---|---|
| `appointmentReminders` | `life_stage_profiles/<uid>` | `upcomingAppointmentLabel`, `upcomingAppointmentAt` | Direct copy of only the label/time — never medication, allergy or risk columns from the same row. |
| `pregnancyMilestones` (only when `type === 'pregnant'`) | `life_stage_profiles/<uid>` | `pregnancyCurrentWeek`, `pregnancyLatestMilestone` | Week counter and most recent milestone label only. Due date, `highRisk`, medications never leave the source row. |
| `supportSuggestions` | her most recent owned `symptom_logs` row | `supportSuggested`, `supportReason` | `supportSuggested = painLevel >= 7 OR symptoms.length >= 3`; reason `highPain` / `multipleSymptoms` / `null`. Raw pain number and symptom list are never copied. |
| `moodUpdates` | her most recent owned `symptom_logs` row | `recentMoodTrend` | `great`/`good` → `positive`; `okay`/missing → `neutral`; `low`/`difficult` → `low`. Raw mood never copied. |

A category that is not approved (or whose condition fails) leaves its columns `null`, and `approvedCategories` on the view lists exactly what is shown. Because every recompute writes every column, revoking a category clears it on the very next recompute.

## Why Appwrite permissions alone aren't enough

Appwrite permissions answer one question per row: "may this role read/update/delete this whole row?" They cannot (a) hide some columns of a row while showing others, (b) derive a value like `recentMoodTrend` that exists nowhere until something buckets a raw mood, or (c) validate what a writer puts in a column. So:

1. **Derived, per-field privacy needs compute.** The partner is granted read on exactly one purpose-built row (`partner_views/<uid>`), never on `symptom_logs` or `life_stage_profiles`. The `partnerView` function is what turns raw rows into that coarse projection.
2. **Sender identity needs a function.** If clients could create `chat_messages` rows, nothing would stop a client writing `senderRole: 'system'` (a forged Eve nudge) or `senderRole: 'her'` from the partner's phone. So the table grants clients no create permission at all, and `sendChatMessage` sets `senderRole` from the authenticated caller (`x-appwrite-user-id`), ignoring anything the body says.
3. **Ownership of client-written rows is proven by permissions.** `symptom_logs.userId` is client-supplied. A client can only grant permissions to roles it holds, so `update("user:<uid>")` on the row proves `<uid>` wrote it; `partnerView` and `chatSystemMessages` ignore any log failing `isOwnedBy`.

**Consistency window (accepted for V0):** events are processed asynchronously, typically within a second or two. Between her revoking a category and the recompute finishing, the partner can still read the previous `partner_views` row. Recompute-from-source guarantees convergence; it does not make revocation instantaneous. Documented, not hidden.

---

## Task 1: `partnerView` — category evaluation and full recompute

**Files:**
- Create: `EVE_MOBILE/functions/partnerView/src/recompute.ts`
- Test: `EVE_MOBILE/functions/partnerView/test/recompute.test.ts`

**Interfaces:**
- Consumes: `Db`, `ownerPermissions`, `ownerEditable`, `readersPermissions`, `isOwnedBy` (Plan 5 Task 2), `TABLES`, `PERMISSION_CATEGORIES`, row types (Plan 5 Task 1).
- Produces: `isCategoryApproved(category, approvedCategories, onlyApproveMode)`, `moodToTrend(mood)`, `buildPartnerView(uid, input, now)`, `recomputePartnerView(db, uid, now)` — used by Task 2 (event entrypoint), Task 3 (`acceptInvite`) and Task 5 (`chatSystemMessages`).

- [ ] **Step 1: Write the failing tests**

Create `EVE_MOBILE/functions/partnerView/test/recompute.test.ts`:

```ts
import { beforeEach, describe, expect, it } from 'vitest';
import { buildPartnerView, isCategoryApproved, recomputePartnerView } from '../src/recompute.js';
import { ownerEditable, ownerPermissions, ownerReadOnly } from '../../shared/src/permissions.js';
import { MemoryDb } from '../../shared/test/memoryDb.js';

const NOW = new Date('2026-03-14T10:00:00.000Z');

describe('isCategoryApproved', () => {
  it('approves only listed known categories, regardless of onlyApproveMode', () => {
    expect(isCategoryApproved('moodUpdates', ['moodUpdates'], true)).toBe(true);
    expect(isCategoryApproved('moodUpdates', [], true)).toBe(false);
    expect(isCategoryApproved('moodUpdates', [], false)).toBe(false);
  });

  it('withholds an unknown future category when onlyApproveMode is on, exposes it when off', () => {
    expect(isCategoryApproved('futureCategory', [], true)).toBe(false);
    expect(isCategoryApproved('futureCategory', [], false)).toBe(true);
  });
});

describe('buildPartnerView', () => {
  const pregnantProfile = {
    type: 'pregnant' as const,
    currentWeek: 20,
    latestMilestone: 'Anatomy scan',
    nextAppointmentLabel: 'OB check-up',
    nextAppointmentAt: '2026-03-20T09:00:00.000Z',
    highRisk: true,
    medications: 'iron',
  };

  it('with no approvals, every category column is null', () => {
    const view = buildPartnerView(
      'u1',
      { perms: { approvedCategories: [], onlyApproveMode: true }, lifeStage: pregnantProfile, latestLog: null },
      NOW,
    );
    expect(view).toEqual({
      primaryUserId: 'u1',
      approvedCategories: [],
      upcomingAppointmentLabel: null,
      upcomingAppointmentAt: null,
      pregnancyCurrentWeek: null,
      pregnancyLatestMilestone: null,
      supportSuggested: null,
      supportReason: null,
      recentMoodTrend: null,
      recomputedAt: NOW.toISOString(),
    });
  });

  it('projects only coarse values and never copies raw health fields', () => {
    const view = buildPartnerView(
      'u1',
      {
        perms: {
          approvedCategories: ['appointmentReminders', 'pregnancyMilestones', 'supportSuggestions', 'moodUpdates'],
          onlyApproveMode: true,
        },
        lifeStage: pregnantProfile,
        latestLog: { symptoms: ['cramps'], mood: 'difficult', painLevel: 8 },
      },
      NOW,
    );
    expect(view.upcomingAppointmentLabel).toBe('OB check-up');
    expect(view.pregnancyCurrentWeek).toBe(20);
    expect(view.pregnancyLatestMilestone).toBe('Anatomy scan');
    expect(view.supportSuggested).toBe(true);
    expect(view.supportReason).toBe('highPain');
    expect(view.recentMoodTrend).toBe('low');
    const serialized = JSON.stringify(view);
    expect(serialized).not.toContain('iron');
    expect(serialized).not.toContain('cramps');
    expect(serialized).not.toContain('difficult');
    expect(serialized).not.toContain('"8"');
  });

  it('pregnancy milestones stay null for a non-pregnant life stage even when approved', () => {
    const view = buildPartnerView(
      'u1',
      {
        perms: { approvedCategories: ['pregnancyMilestones'], onlyApproveMode: true },
        lifeStage: { type: 'cycle', currentWeek: null, latestMilestone: null },
        latestLog: null,
      },
      NOW,
    );
    expect(view.pregnancyCurrentWeek).toBeNull();
    expect(view.approvedCategories).toEqual([]);
  });

  it('multiple symptoms without high pain yields multipleSymptoms', () => {
    const view = buildPartnerView(
      'u1',
      {
        perms: { approvedCategories: ['supportSuggestions'], onlyApproveMode: true },
        lifeStage: {},
        latestLog: { symptoms: ['a', 'b', 'c'], mood: 'okay', painLevel: 2 },
      },
      NOW,
    );
    expect(view.supportSuggested).toBe(true);
    expect(view.supportReason).toBe('multipleSymptoms');
  });
});

describe('recomputePartnerView', () => {
  let db: MemoryDb;

  beforeEach(async () => {
    db = new MemoryDb();
    await db.createRow('partner_permissions', 'u1', { approvedCategories: ['moodUpdates'], onlyApproveMode: true }, ownerEditable('u1'));
    await db.createRow('life_stage_profiles', 'u1', { type: 'cycle' }, ownerEditable('u1'));
    await db.createRow('partner_links', 'u1', { inviteStatus: 'none', partnerUserId: null }, ownerReadOnly('u1'));
  });

  it('uses her most recent OWNED log and ignores a forged log with her userId', async () => {
    await db.createRow('symptom_logs', 'l1', { userId: 'u1', date: '2026-03-13T00:00:00.000Z', symptoms: [], mood: 'great', painLevel: 0 }, ownerPermissions('u1'));
    // Forged by attacker: userId says u1, but permissions belong to the attacker.
    await db.createRow('symptom_logs', 'l2', { userId: 'u1', date: '2026-03-14T00:00:00.000Z', symptoms: [], mood: 'difficult', painLevel: 0 }, ownerPermissions('attacker'));

    await recomputePartnerView(db, 'u1', NOW);

    const view = await db.getRow('partner_views', 'u1');
    expect(view?.recentMoodTrend).toBe('positive');
  });

  it('grants read to her only until a partner has accepted, then to both', async () => {
    await recomputePartnerView(db, 'u1', NOW);
    expect((await db.getRow('partner_views', 'u1'))?.$permissions).toEqual(['read("user:u1")']);

    await db.updateRow('partner_links', 'u1', { inviteStatus: 'accepted', partnerUserId: 'p1' });
    await recomputePartnerView(db, 'u1', NOW);
    expect((await db.getRow('partner_views', 'u1'))?.$permissions).toEqual(['read("user:u1")', 'read("user:p1")']);
  });

  it('revoking a category clears its column on the next recompute', async () => {
    await db.createRow('symptom_logs', 'l1', { userId: 'u1', date: '2026-03-13T00:00:00.000Z', symptoms: [], mood: 'low', painLevel: 0 }, ownerPermissions('u1'));
    await recomputePartnerView(db, 'u1', NOW);
    expect((await db.getRow('partner_views', 'u1'))?.recentMoodTrend).toBe('low');

    await db.updateRow('partner_permissions', 'u1', { approvedCategories: [] });
    await recomputePartnerView(db, 'u1', NOW);
    expect((await db.getRow('partner_views', 'u1'))?.recentMoodTrend).toBeNull();
  });

  it('is idempotent: recomputing twice yields identical rows', async () => {
    await recomputePartnerView(db, 'u1', NOW);
    const first = await db.getRow('partner_views', 'u1');
    await recomputePartnerView(db, 'u1', NOW);
    expect(await db.getRow('partner_views', 'u1')).toEqual(first);
  });
});
```

- [ ] **Step 2: Run to verify it fails**

Run (from `EVE_MOBILE/functions/`): `npx vitest run partnerView`
Expected: FAIL — `Failed to resolve import "../src/recompute.js"`.

- [ ] **Step 3: Implement `EVE_MOBILE/functions/partnerView/src/recompute.ts`**

```ts
import type { Db } from '../../shared/src/db.js';
import { TABLES } from '../../shared/src/ids.js';
import { isOwnedBy, readersPermissions } from '../../shared/src/permissions.js';
import {
  PERMISSION_CATEGORIES,
  type LifeStageProfileRow,
  type Mood,
  type PartnerViewRow,
  type PermissionCategory,
  type SymptomLogRow,
} from '../../shared/src/types.js';

/**
 * Known V0 categories are a strict allowlist: shown only when listed.
 * onlyApproveMode governs categories the product does not define yet:
 * withheld when it is on (the safe default), shown when she turned it off.
 */
export function isCategoryApproved(category: string, approvedCategories: readonly string[], onlyApproveMode: boolean): boolean {
  if (approvedCategories.includes(category)) return true;
  if ((PERMISSION_CATEGORIES as readonly string[]).includes(category)) return false;
  return !onlyApproveMode;
}

export function moodToTrend(mood: Mood | null | undefined): 'low' | 'neutral' | 'positive' {
  switch (mood) {
    case 'great':
    case 'good':
      return 'positive';
    case 'low':
    case 'difficult':
      return 'low';
    default:
      return 'neutral';
  }
}

export interface PartnerViewInput {
  perms: { approvedCategories: readonly string[]; onlyApproveMode: boolean };
  lifeStage: Partial<LifeStageProfileRow>;
  latestLog: Pick<SymptomLogRow, 'symptoms' | 'mood' | 'painLevel'> | null;
}

/** Pure projection. Every column is always present; withheld = null. */
export function buildPartnerView(uid: string, input: PartnerViewInput, now: Date): PartnerViewRow {
  const approved = (c: PermissionCategory) =>
    isCategoryApproved(c, input.perms.approvedCategories, input.perms.onlyApproveMode);
  const shown: PermissionCategory[] = [];
  const view: PartnerViewRow = {
    primaryUserId: uid,
    approvedCategories: shown,
    upcomingAppointmentLabel: null,
    upcomingAppointmentAt: null,
    pregnancyCurrentWeek: null,
    pregnancyLatestMilestone: null,
    supportSuggested: null,
    supportReason: null,
    recentMoodTrend: null,
    recomputedAt: now.toISOString(),
  };

  if (approved('appointmentReminders')) {
    shown.push('appointmentReminders');
    view.upcomingAppointmentLabel = input.lifeStage.nextAppointmentLabel ?? null;
    view.upcomingAppointmentAt = input.lifeStage.nextAppointmentAt ?? null;
  }

  if (input.lifeStage.type === 'pregnant' && approved('pregnancyMilestones')) {
    shown.push('pregnancyMilestones');
    view.pregnancyCurrentWeek = input.lifeStage.currentWeek ?? null;
    view.pregnancyLatestMilestone = input.lifeStage.latestMilestone ?? null;
  }

  if (approved('supportSuggestions')) {
    shown.push('supportSuggestions');
    const highPain = (input.latestLog?.painLevel ?? 0) >= 7;
    const manySymptoms = (input.latestLog?.symptoms?.length ?? 0) >= 3;
    view.supportSuggested = highPain || manySymptoms;
    view.supportReason = highPain ? 'highPain' : manySymptoms ? 'multipleSymptoms' : null;
  }

  if (approved('moodUpdates')) {
    shown.push('moodUpdates');
    view.recentMoodTrend = moodToTrend(input.latestLog?.mood ?? null);
  }

  return view;
}

/** Linked partner uid when the invite is accepted, else null. */
export async function acceptedPartnerOf(db: Db, uid: string): Promise<string | null> {
  const link = await db.getRow(TABLES.partnerLinks, uid);
  return link?.inviteStatus === 'accepted' && typeof link.partnerUserId === 'string' ? link.partnerUserId : null;
}

/**
 * Recomputes partner_views/<uid> from source rows and REPLACES it (data and
 * permissions). Safe to run any number of times, in any order.
 */
export async function recomputePartnerView(db: Db, uid: string, now: Date): Promise<PartnerViewRow> {
  const [permsRow, lifeRow, partnerUid, recentLogs] = await Promise.all([
    db.getRow(TABLES.partnerPermissions, uid),
    db.getRow(TABLES.lifeStageProfiles, uid),
    acceptedPartnerOf(db, uid),
    db.listRows(TABLES.symptomLogs, {
      equal: { userId: uid },
      orderBy: { column: 'date', direction: 'desc' },
      limit: 25,
    }),
  ]);

  const latestOwned = recentLogs.find((row) => isOwnedBy(row, uid));
  const view = buildPartnerView(
    uid,
    {
      perms: {
        approvedCategories: (permsRow?.approvedCategories as string[] | null) ?? [],
        onlyApproveMode: (permsRow?.onlyApproveMode as boolean | null) ?? true,
      },
      lifeStage: (lifeRow ?? {}) as Partial<LifeStageProfileRow>,
      latestLog: latestOwned
        ? {
            symptoms: (latestOwned.symptoms as string[] | null) ?? [],
            mood: (latestOwned.mood as Mood | null) ?? null,
            painLevel: (latestOwned.painLevel as number | null) ?? null,
          }
        : null,
    },
    now,
  );

  const readers = partnerUid ? [uid, partnerUid] : [uid];
  await db.upsertRow(TABLES.partnerViews, uid, view, readersPermissions(readers));
  return view;
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `npx vitest run partnerView && npm run typecheck`
Expected: `10 passed`; typecheck exits 0.

- [ ] **Step 5: Commit**

```bash
git add EVE_MOBILE/functions/partnerView/src/recompute.ts EVE_MOBILE/functions/partnerView/test/recompute.test.ts
git commit -m "feat(partnerView): add consent-filtered full recompute of partner_views"
```

---

## Task 2: `partnerView` — event entrypoint and registration

**Files:**
- Create: `EVE_MOBILE/functions/partnerView/src/events.ts`
- Create: `EVE_MOBILE/functions/partnerView/src/main.ts`
- Test: `EVE_MOBILE/functions/partnerView/test/events.test.ts`
- Modify: `EVE_MOBILE/appwrite.config.json` (append to `functions`)

**Interfaces:**
- Consumes: `recomputePartnerView` (Task 1), `eventName`, `FunctionContext` (Plan 3 Task 5), `serverDb` (Plan 5 Task 2).
- Produces: `tableFromEvent(event)`, `ownerForEvent(tableId, row)` and the deployed `partnerView` function.

- [ ] **Step 1: Write the failing tests**

Create `EVE_MOBILE/functions/partnerView/test/events.test.ts`:

```ts
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
```

- [ ] **Step 2: Run to verify it fails**

Run: `npx vitest run partnerView/test/events.test.ts`
Expected: FAIL — `Failed to resolve import "../src/events.js"`.

- [ ] **Step 3: Implement `EVE_MOBILE/functions/partnerView/src/events.ts`**

```ts
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
```

- [ ] **Step 4: Implement the entrypoint `EVE_MOBILE/functions/partnerView/src/main.ts`**

```ts
import { eventName, type FunctionContext } from '../../shared/src/appwrite.js';
import { serverDb, type Row } from '../../shared/src/db.js';
import { ownerForEvent, tableFromEvent } from './events.js';
import { recomputePartnerView } from './recompute.js';

export default async (context: FunctionContext) => {
  const tableId = tableFromEvent(eventName(context));
  const row = context.req.bodyJson as Row | undefined;
  const uid = tableId && row ? ownerForEvent(tableId, row) : null;
  if (!uid) {
    context.log(`partnerView: ignored ${eventName(context) ?? 'non-event execution'}`);
    return context.res.json({ ok: true, ignored: true });
  }
  const view = await recomputePartnerView(serverDb(context), uid, new Date());
  context.log(`partnerView: recomputed for ${uid}, showing [${view.approvedCategories.join(', ')}]`);
  return context.res.json({ ok: true });
};
```

- [ ] **Step 5: Register — append to `functions` in `EVE_MOBILE/appwrite.config.json`**

```json
    {
      "$id": "partnerView",
      "name": "partnerView",
      "runtime": "node-22",
      "specification": "s-0.5vcpu-512mb",
      "execute": [],
      "events": [
        "tablesdb.eve.tables.symptom_logs.rows.*.create",
        "tablesdb.eve.tables.symptom_logs.rows.*.update",
        "tablesdb.eve.tables.symptom_logs.rows.*.upsert",
        "tablesdb.eve.tables.symptom_logs.rows.*.delete",
        "tablesdb.eve.tables.life_stage_profiles.rows.*.update",
        "tablesdb.eve.tables.life_stage_profiles.rows.*.upsert",
        "tablesdb.eve.tables.partner_permissions.rows.*.update",
        "tablesdb.eve.tables.partner_permissions.rows.*.upsert"
      ],
      "scopes": ["rows.read", "rows.write"],
      "schedule": "",
      "timeout": 30,
      "enabled": true,
      "logging": true,
      "entrypoint": "dist/partnerView/src/main.js",
      "commands": "npm ci && npm run build",
      "path": "functions"
    }
```

The function writes only `partner_views`, which is not in its event list — no trigger loop.

- [ ] **Step 6: Run to verify it passes**

Run: `npx vitest run partnerView && npm run typecheck`
Expected: all `partnerView` tests pass (10 + 4).

- [ ] **Step 7: Commit**

```bash
git add EVE_MOBILE/functions/partnerView EVE_MOBILE/appwrite.config.json
git commit -m "feat(partnerView): wire recompute to symptom log, life stage and permission events"
```

---

## Task 3: `partnerInvites` — create and accept a partner link

**Files:**
- Create: `EVE_MOBILE/functions/partnerInvites/src/invites.ts`
- Create: `EVE_MOBILE/functions/partnerInvites/src/main.ts`
- Test: `EVE_MOBILE/functions/partnerInvites/test/invites.test.ts`
- Modify: `EVE_MOBILE/appwrite.config.json` (append to `functions`)

**Interfaces:**
- Consumes: `Db`, `readersPermissions`, `ownerReadOnly` (Plan 5), `recomputePartnerView` (Task 1), `callerId`, `readJsonBody` (Plan 3 Task 5).
- Produces: `generateInviteCode(random)`, `handleInviteRequest(deps, uid, body)` with actions `createInvite { relationshipType }` → `{ inviteCode }` and `acceptInvite { inviteCode }` → `{ primaryUserId }`. Called by Plan 4 M14 (`createInvite` on onboarding completion) and the partner's join screen.

**Why a function:** `partner_links` decides who may read her partner view and chat. If her client could write `partnerUserId` directly, any account ID could be granted access without that person's consent, and the partner side could never prove it accepted. The function is the only writer.

- [ ] **Step 1: Write the failing tests**

Create `EVE_MOBILE/functions/partnerInvites/test/invites.test.ts`:

```ts
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
```

- [ ] **Step 2: Run to verify it fails**

Run: `npx vitest run partnerInvites`
Expected: FAIL — `Failed to resolve import "../src/invites.js"`.

- [ ] **Step 3: Implement `EVE_MOBILE/functions/partnerInvites/src/invites.ts`**

```ts
import type { Db } from '../../shared/src/db.js';
import { TABLES } from '../../shared/src/ids.js';
import { ownerReadOnly, readersPermissions } from '../../shared/src/permissions.js';
import type { PartnerLookupRow } from '../../shared/src/types.js';
import { recomputePartnerView } from '../../partnerView/src/recompute.js';

const ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // no 0/O/1/I

export function generateInviteCode(random: () => number = Math.random): string {
  let code = '';
  for (let i = 0; i < 6; i += 1) code += ALPHABET[Math.floor(random() * ALPHABET.length)];
  return code;
}

export interface InviteDeps {
  db: Db;
  now: () => Date;
  newCode: () => string;
}

export interface InviteResponse {
  status: number;
  body: Record<string, unknown>;
}

export async function handleInviteRequest(
  deps: InviteDeps,
  uid: string | null,
  body: Record<string, unknown> | null,
): Promise<InviteResponse> {
  if (!uid) return { status: 401, body: { error: 'Sign in required.' } };
  switch (body?.action) {
    case 'createInvite':
      return createInvite(deps, uid, typeof body.relationshipType === 'string' ? body.relationshipType : null);
    case 'acceptInvite':
      return acceptInvite(deps, uid, typeof body.inviteCode === 'string' ? body.inviteCode : '');
    default:
      return { status: 400, body: { error: 'Unknown action.' } };
  }
}

async function createInvite(deps: InviteDeps, uid: string, relationshipType: string | null): Promise<InviteResponse> {
  const existing = await deps.db.getRow(TABLES.partnerLinks, uid);
  if (existing?.inviteStatus === 'accepted') {
    return { status: 409, body: { error: 'A partner is already linked.' } };
  }
  const inviteCode = deps.newCode();
  await deps.db.upsertRow(
    TABLES.partnerLinks,
    uid,
    {
      partnerUserId: null,
      relationshipType,
      inviteStatus: 'pending',
      inviteCode,
      invitedAt: deps.now().toISOString(),
      linkedAt: null,
    },
    ownerReadOnly(uid),
  );
  return { status: 200, body: { inviteCode } };
}

async function acceptInvite(deps: InviteDeps, partnerUid: string, rawCode: string): Promise<InviteResponse> {
  const inviteCode = rawCode.trim().toUpperCase();
  if (!/^[A-Z0-9]{6}$/.test(inviteCode)) return { status: 400, body: { error: 'Invalid invite code.' } };

  const [link] = await deps.db.listRows(TABLES.partnerLinks, { equal: { inviteCode, inviteStatus: 'pending' }, limit: 1 });
  if (!link) return { status: 404, body: { error: 'This invite code is not valid.' } };
  const primaryUid = link.$id;
  if (primaryUid === partnerUid) return { status: 400, body: { error: 'You cannot accept your own invite.' } };
  if (await deps.db.getRow(TABLES.partnerLookups, partnerUid)) {
    return { status: 409, body: { error: 'This account is already linked to someone.' } };
  }

  const linkedAt = deps.now().toISOString();
  const readers = readersPermissions([primaryUid, partnerUid]);
  await deps.db.updateRow(
    TABLES.partnerLinks,
    primaryUid,
    { partnerUserId: partnerUid, inviteStatus: 'accepted', inviteCode: null, linkedAt },
    readers,
  );
  const lookup: PartnerLookupRow = {
    primaryUserId: primaryUid,
    relationshipType: (link.relationshipType as string | null) ?? null,
    linkedAt,
  };
  await deps.db.upsertRow(TABLES.partnerLookups, partnerUid, lookup, readersPermissions([partnerUid]));

  // Re-grant read on her existing thread so the partner sees chat history.
  for (const message of await deps.db.listRows(TABLES.chatMessages, { equal: { threadUserId: primaryUid } })) {
    await deps.db.updateRow(TABLES.chatMessages, message.$id, {}, readers);
  }
  await recomputePartnerView(deps.db, primaryUid, deps.now());

  return { status: 200, body: { primaryUserId: primaryUid } };
}
```

- [ ] **Step 4: Implement the entrypoint `EVE_MOBILE/functions/partnerInvites/src/main.ts`**

```ts
import { callerId, readJsonBody, type FunctionContext } from '../../shared/src/appwrite.js';
import { serverDb } from '../../shared/src/db.js';
import { generateInviteCode, handleInviteRequest } from './invites.js';

export default async (context: FunctionContext) => {
  const result = await handleInviteRequest(
    { db: serverDb(context), now: () => new Date(), newCode: () => generateInviteCode() },
    callerId(context),
    readJsonBody(context),
  );
  return context.res.json(result.body, result.status);
};
```

- [ ] **Step 5: Register — append to `functions` in `EVE_MOBILE/appwrite.config.json`**

```json
    {
      "$id": "partnerInvites",
      "name": "partnerInvites",
      "runtime": "node-22",
      "specification": "s-0.5vcpu-512mb",
      "execute": ["users"],
      "events": [],
      "scopes": ["rows.read", "rows.write"],
      "schedule": "",
      "timeout": 30,
      "enabled": true,
      "logging": true,
      "entrypoint": "dist/partnerInvites/src/main.js",
      "commands": "npm ci && npm run build",
      "path": "functions"
    }
```

- [ ] **Step 6: Run to verify it passes**

Run: `npx vitest run partnerInvites && npm run typecheck`
Expected: `6 passed`.

- [ ] **Step 7: Commit**

```bash
git add EVE_MOBILE/functions/partnerInvites EVE_MOBILE/appwrite.config.json
git commit -m "feat(partnerInvites): add consent-based partner invite and accept flow"
```

---

## Task 4: `sendChatMessage` — unforgeable sender identity

**Files:**
- Create: `EVE_MOBILE/functions/sendChatMessage/src/send.ts`
- Create: `EVE_MOBILE/functions/sendChatMessage/src/main.ts`
- Test: `EVE_MOBILE/functions/sendChatMessage/test/send.test.ts`
- Modify: `EVE_MOBILE/appwrite.config.json` (append to `functions`)

**Interfaces:**
- Consumes: `Db`, `readersPermissions` (Plan 5), `acceptedPartnerOf` (Task 1).
- Produces: `handleSendRequest(deps, uid, body)` with body `{ threadUserId, text }` → `{ messageId }`. Called by Plan 4 M16's `AppwriteChatRepository.sendMessage`.

- [ ] **Step 1: Write the failing tests**

Create `EVE_MOBILE/functions/sendChatMessage/test/send.test.ts`:

```ts
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
```

- [ ] **Step 2: Run to verify it fails**

Run: `npx vitest run sendChatMessage`
Expected: FAIL — `Failed to resolve import "../src/send.js"`.

- [ ] **Step 3: Implement `EVE_MOBILE/functions/sendChatMessage/src/send.ts`**

```ts
import type { Db } from '../../shared/src/db.js';
import { TABLES } from '../../shared/src/ids.js';
import { readersPermissions } from '../../shared/src/permissions.js';
import type { ChatMessageRow } from '../../shared/src/types.js';
import { acceptedPartnerOf } from '../../partnerView/src/recompute.js';

export interface SendDeps {
  db: Db;
  now: () => Date;
  newId: () => string;
}

export interface SendResponse {
  status: number;
  body: Record<string, unknown>;
}

const MAX_TEXT = 2000;

/**
 * The only writer of human chat messages. senderRole/senderUserId/type come
 * from the authenticated caller, never from the request body.
 */
export async function handleSendRequest(deps: SendDeps, uid: string | null, body: Record<string, unknown> | null): Promise<SendResponse> {
  if (!uid) return { status: 401, body: { error: 'Sign in required.' } };
  const threadUserId = typeof body?.threadUserId === 'string' ? body.threadUserId : '';
  const text = typeof body?.text === 'string' ? body.text.trim() : '';
  if (!threadUserId) return { status: 400, body: { error: 'Missing threadUserId.' } };
  if (!text || text.length > MAX_TEXT) return { status: 400, body: { error: 'Message must be 1-2000 characters.' } };

  const partnerUid = await acceptedPartnerOf(deps.db, threadUserId);
  const senderRole = uid === threadUserId ? 'her' : uid === partnerUid ? 'partner' : null;
  if (!senderRole) return { status: 403, body: { error: 'You are not part of this conversation.' } };

  const message: ChatMessageRow = {
    threadUserId,
    senderRole,
    senderUserId: uid,
    messageText: text,
    sentAt: deps.now().toISOString(),
    type: 'text',
    category: null,
    sourceLogId: null,
  };
  const messageId = deps.newId();
  const readers = partnerUid ? [threadUserId, partnerUid] : [threadUserId];
  await deps.db.createRow(TABLES.chatMessages, messageId, message, readersPermissions(readers));
  return { status: 200, body: { messageId } };
}
```

- [ ] **Step 4: Implement the entrypoint `EVE_MOBILE/functions/sendChatMessage/src/main.ts`**

```ts
import { ID } from 'node-appwrite';
import { callerId, readJsonBody, type FunctionContext } from '../../shared/src/appwrite.js';
import { serverDb } from '../../shared/src/db.js';
import { handleSendRequest } from './send.js';

export default async (context: FunctionContext) => {
  const result = await handleSendRequest(
    { db: serverDb(context), now: () => new Date(), newId: () => ID.unique() },
    callerId(context),
    readJsonBody(context),
  );
  return context.res.json(result.body, result.status);
};
```

- [ ] **Step 5: Register — append to `functions` in `EVE_MOBILE/appwrite.config.json`**

```json
    {
      "$id": "sendChatMessage",
      "name": "sendChatMessage",
      "runtime": "node-22",
      "specification": "s-0.5vcpu-512mb",
      "execute": ["users"],
      "events": [],
      "scopes": ["rows.read", "rows.write"],
      "schedule": "",
      "timeout": 15,
      "enabled": true,
      "logging": true,
      "entrypoint": "dist/sendChatMessage/src/main.js",
      "commands": "npm ci && npm run build",
      "path": "functions"
    }
```

- [ ] **Step 6: Run to verify it passes**

Run: `npx vitest run sendChatMessage && npm run typecheck`
Expected: `5 passed`.

- [ ] **Step 7: Commit**

```bash
git add EVE_MOBILE/functions/sendChatMessage EVE_MOBILE/appwrite.config.json
git commit -m "feat(sendChatMessage): write chat messages with server-assigned sender identity"
```

---

## Task 5: `chatSystemMessages` — Eve's nudges, deduplicated, with partner push

**Files:**
- Create: `EVE_MOBILE/functions/chatSystemMessages/src/nudge.ts`
- Create: `EVE_MOBILE/functions/chatSystemMessages/src/main.ts`
- Test: `EVE_MOBILE/functions/chatSystemMessages/test/nudge.test.ts`
- Modify: `EVE_MOBILE/appwrite.config.json` (append to `functions`)

**Interfaces:**
- Consumes: `isCategoryApproved`, `acceptedPartnerOf` (Task 1), `Db`, `RowConflictError`, `isOwnedBy`, `readersPermissions` (Plan 5), `Messenger`/`appwriteMessenger` (Plan 3 Task 9).
- Produces: `getQualifyingReason(log)`, `messageTextFor(reason)`, `handleLogCreated(deps, logRow)` and the deployed function on `symptom_logs` create.

**Qualifying condition:** `painLevel >= 9` → severe pain nudge; `painLevel >= 7` → moderate pain nudge (category `supportSuggestions`); otherwise `mood` `low`/`difficult` → mood nudge (category `moodUpdates`). Pain is checked first — one message per log, never two.

**Idempotency:** the message row ID is `sys-<logId>`. A redelivered event hits `RowConflictError` on create and returns before pushing, so the partner never gets a duplicate message or notification.

- [ ] **Step 1: Write the failing tests**

Create `EVE_MOBILE/functions/chatSystemMessages/test/nudge.test.ts`:

```ts
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
```

- [ ] **Step 2: Run to verify it fails**

Run: `npx vitest run chatSystemMessages`
Expected: FAIL — `Failed to resolve import "../src/nudge.js"`.

- [ ] **Step 3: Implement `EVE_MOBILE/functions/chatSystemMessages/src/nudge.ts`**

```ts
import { RowConflictError, type Db, type Row } from '../../shared/src/db.js';
import { TABLES } from '../../shared/src/ids.js';
import { isOwnedBy, readersPermissions } from '../../shared/src/permissions.js';
import type { ChatMessageRow, Mood, PermissionCategory } from '../../shared/src/types.js';
import type { Messenger } from '../../notifications/src/dispatch.js';
import { acceptedPartnerOf, isCategoryApproved } from '../../partnerView/src/recompute.js';

export type QualifyingReason = { kind: 'highPain'; severity: 'moderate' | 'severe' } | { kind: 'lowMood' } | null;

export function getQualifyingReason(log: { painLevel?: number | null; mood?: Mood | null }): QualifyingReason {
  const pain = log.painLevel ?? 0;
  if (pain >= 9) return { kind: 'highPain', severity: 'severe' };
  if (pain >= 7) return { kind: 'highPain', severity: 'moderate' };
  if (log.mood === 'low' || log.mood === 'difficult') return { kind: 'lowMood' };
  return null;
}

// Warm, formal, no emojis (EVE2_PRD §6); deterministic per severity in V0.
export function messageTextFor(reason: Exclude<QualifyingReason, null>): string {
  if (reason.kind === 'highPain') {
    return reason.severity === 'severe'
      ? 'Eve: Today has been especially difficult for her. A visit, a call, or simply being present could mean a great deal right now.'
      : 'Eve: She logged a difficult day today. This may be a good moment to check in and offer some support.';
  }
  return 'Eve: She noted today has been an emotionally low day. A kind word or a small gesture of support could mean a lot right now.';
}

export interface NudgeDeps {
  db: Db;
  messenger: Messenger;
  now: () => Date;
}

/** Returns true when a new nudge was written (and pushed). */
export async function handleLogCreated(deps: NudgeDeps, log: Row): Promise<boolean> {
  const uid = typeof log.userId === 'string' ? log.userId : null;
  if (!uid || !isOwnedBy(log, uid)) return false;

  const reason = getQualifyingReason({ painLevel: log.painLevel as number | null, mood: log.mood as Mood | null });
  if (!reason) return false;
  const category: PermissionCategory = reason.kind === 'highPain' ? 'supportSuggestions' : 'moodUpdates';

  const partnerUid = await acceptedPartnerOf(deps.db, uid);
  if (!partnerUid) return false;

  const perms = await deps.db.getRow(TABLES.partnerPermissions, uid);
  const approved = isCategoryApproved(
    category,
    (perms?.approvedCategories as string[] | null) ?? [],
    (perms?.onlyApproveMode as boolean | null) ?? true,
  );
  if (!approved) return false;

  const text = messageTextFor(reason);
  const message: ChatMessageRow = {
    threadUserId: uid,
    senderRole: 'system',
    senderUserId: null,
    messageText: text,
    sentAt: deps.now().toISOString(),
    type: 'system',
    category: category === 'supportSuggestions' ? 'supportSuggestion' : 'moodUpdate',
    sourceLogId: log.$id,
  };
  try {
    await deps.db.createRow(TABLES.chatMessages, `sys-${log.$id}`, message, readersPermissions([uid, partnerUid]));
  } catch (e) {
    if (e instanceof RowConflictError) return false; // already nudged for this log
    throw e;
  }
  await deps.messenger.pushToUser(partnerUid, 'Eve', text, { type: 'partnerNudge', threadUserId: uid });
  return true;
}
```

- [ ] **Step 4: Implement the entrypoint `EVE_MOBILE/functions/chatSystemMessages/src/main.ts`**

```ts
import { serverMessaging, type FunctionContext } from '../../shared/src/appwrite.js';
import { serverDb, type Row } from '../../shared/src/db.js';
import { appwriteMessenger } from '../../notifications/src/dispatch.js';
import { handleLogCreated } from './nudge.js';

// Event: tablesdb.eve.tables.symptom_logs.rows.*.create — payload is the new row.
export default async (context: FunctionContext) => {
  const row = context.req.bodyJson as Row | undefined;
  if (!row?.$id) return context.res.json({ ok: false }, 400);
  const nudged = await handleLogCreated(
    { db: serverDb(context), messenger: appwriteMessenger(serverMessaging(context)), now: () => new Date() },
    row,
  );
  context.log(`chatSystemMessages: log ${row.$id} ${nudged ? 'produced a partner nudge' : 'needed no nudge'}`);
  return context.res.json({ ok: true, nudged });
};
```

- [ ] **Step 5: Register — append to `functions` in `EVE_MOBILE/appwrite.config.json`**

```json
    {
      "$id": "chatSystemMessages",
      "name": "chatSystemMessages",
      "runtime": "node-22",
      "specification": "s-0.5vcpu-512mb",
      "execute": [],
      "events": ["tablesdb.eve.tables.symptom_logs.rows.*.create"],
      "scopes": ["rows.read", "rows.write", "messages.write", "targets.read"],
      "schedule": "",
      "timeout": 30,
      "enabled": true,
      "logging": true,
      "entrypoint": "dist/chatSystemMessages/src/main.js",
      "commands": "npm ci && npm run build",
      "path": "functions"
    }
```

- [ ] **Step 6: Run to verify it passes**

Run: `npx vitest run chatSystemMessages && npm run typecheck`
Expected: `7 passed`.

- [ ] **Step 7: Commit**

```bash
git add EVE_MOBILE/functions/chatSystemMessages EVE_MOBILE/appwrite.config.json
git commit -m "feat(chatSystemMessages): add deduplicated Eve partner nudges with push"
```

---

## Task 6: Full suite + end-to-end consent scenario on local Appwrite

**Files:** none created — verification only.

- [ ] **Step 1: Run every function test**

```bash
cd EVE_MOBILE/functions
npm test
npm run typecheck
npm run build
```

Expected: every test file passes; `dist/<name>/src/main.js` exists for all seven functions.

- [ ] **Step 2: Deploy everything locally**

```bash
cd EVE_MOBILE
appwrite push tables --all --force
appwrite push functions --all --force
```

- [ ] **Step 3: Walk the scenario (two devices/emulators or one device + console)**

1. Sign in as **her**; complete onboarding with partner invite on (roadmap M14 calls `createInvite`) — `partner_links/<her>` shows `pending` and a code.
2. Sign in as **him** on a second device; enter the code (partner join screen) — `partner_links/<her>` becomes `accepted`, `partner_lookups/<him>` exists, `partner_views/<her>` permissions include `read("user:him")`.
3. As her, approve only **Mood updates**, then log a day with mood "Difficult" and pain 3. Expected within seconds: `partner_views/<her>.recentMoodTrend = "low"`, `supportSuggested = null`; `chat_messages/sys-<logId>` exists with `senderRole: system`; his device shows an "Eve" notification.
4. Log a day with pain 8 (mood fine). Expected: no new chat message (Support suggestions not approved); `partner_views` unchanged except `recomputedAt`.
5. As her, revoke **Mood updates**. Expected: `partner_views/<her>.recentMoodTrend` becomes `null`.
6. In the console, try to create a `chat_messages` row signed in as him (API playground with his session). Expected: `401 user_unauthorized`.
7. Functions → chatSystemMessages → re-run the execution from step 3 (same payload). Expected log: `needed no nudge`; still exactly one `sys-<logId>` row; no second notification.

- [ ] **Step 4: Commit (only if Step 1/2 produced lockfile or config normalization changes)**

```bash
git add EVE_MOBILE/appwrite.config.json EVE_MOBILE/functions/package-lock.json
git commit -m "chore: normalize config after full partner-mode deployment"
```

---

## Self-Review

**1. Spec coverage.** Partner view recompute on every relevant write with full replacement — Tasks 1–2. Consent-gated linking — Task 3. Chat sender identity enforced server-side, clients have no create permission — Task 4 + Plan 5's schema test. Eve's nudges only when the qualifying condition AND an approved category AND an accepted link all hold, never duplicated, with partner push — Task 5. Forged-log defense — Tasks 1, 2, 5 tests. Revocation clears data — Task 1 test + Task 6 scenario. The consistency window is stated, not hidden.

**2. Placeholder scan.** None. The join screen for the partner (entering the code) is a UI concern owned by roadmap M18; this plan supplies its backend (`acceptInvite`) completely.

**3. Type consistency.** Categories, moods and columns are imported from Plan 5's `types.ts`; `partner_views` columns written here equal Plan 5's `PartnerViewRow` (schema test enforces the config side). `Messenger` is Plan 3 Task 9's interface. `handleInviteRequest`/`handleSendRequest` request shapes match what Plan 4 M14/M16 send.
