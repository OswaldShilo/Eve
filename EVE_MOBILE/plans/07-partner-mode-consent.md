# Partner Mode / Consent Enforcement Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the server-side `partnerView` projection Cloud Function and the Eve-authored system-chat-nudge Cloud Function that together are the actual technical enforcement of EVE's Partner Mode consent model — not a UI convenience, and not a security-rules trick.

**Architecture:** Two independent Firestore-triggered Cloud Functions in the `functions/` TypeScript project. `partnerView.ts` listens for writes to `users/{uid}/logs/{logId}`, `users/{uid}/lifeStageProfile/current`, and `users/{uid}/partnerPermissions/current`, and on every one of those writes fully recomputes (never patches) `users/{uid}/partnerView/current` — a small, coarse, derived document containing only what her currently-approved permission categories allow. `chatSystemMessages.ts` listens for new documents in `users/{uid}/logs/{logId}` and, when the new entry crosses a defined severity threshold and she has an accepted partner link with the relevant category approved, writes a `type: 'system'` message into `users/{uid}/chat/{messageId}` using the Admin SDK — the same SDK that both functions run under, which is what makes the write trustworthy (see "Why This Can't Just Be Security Rules" below). Both functions share one exported permission-evaluation helper (`isCategoryApproved`) so the "is this category currently allowed" logic is defined exactly once.

**Tech Stack:** Firebase Cloud Functions v2 (`firebase-functions/v2/firestore`), `firebase-admin` (Firestore Admin SDK), TypeScript, Jest + `ts-jest` against the Firestore Emulator (via `firebase-tools`' `emulators:exec`), Node.js 20 runtime.

## Global Constraints

- Cloud Functions runtime is Node.js/TypeScript — EVE2_PRD §10.1 / design spec §2.
- Copy voice is formal and warm, no emojis anywhere in-product — EVE2_PRD §6 / design spec §2.
- Firestore paths are fixed by design spec §10 — this plan does not invent new paths or rename existing ones.
- `users/{uid}/partnerView/current` is server-generated only; never written to by any client, including her own — design spec §10, EVE2_PRD §10.2.
- Canonical file paths for this plan's code are exactly `functions/src/partnerView.ts` and `functions/src/chatSystemMessages.ts` — design spec §9.
- Diagnosis claims are never made; this plan produces no clinical language, only coarse support/mood signals — EVE2_PRD §9.
- Gamification (streaks, points) and full E2E chat encryption are out of V0 scope and are not touched by this plan — design spec §2, §8.

## Assumed Upstream Schema (owned by Plan 5 — not redefined here)

Plan 5 (`05-data-model-firestore.md`) is the authority on these documents' field types. This plan is written in parallel and cannot read Plan 5's output, so it makes the following concrete assumptions, chosen to be the most direct reading of EVE2_PRD §10.2 and design spec §10. If Plan 5 ships different field names, only the small "read" blocks in `partnerView.ts`/`chatSystemMessages.ts` need to change — the projection/derivation logic does not.

```typescript
// users/{uid}/logs/{logId}
interface LogDoc {
  date: FirebaseFirestore.Timestamp;
  symptoms: string[];
  mood: 'great' | 'good' | 'okay' | 'low' | 'very_low' | null;
  painLevel: number | null; // 0-10
  notes: string;
  createdAt: FirebaseFirestore.Timestamp;
}

// users/{uid}/lifeStageProfile/current
interface LifeStageProfileDoc {
  type: 'cycle' | 'conceive' | 'pregnant' | 'postpartum' | 'menopause';
  pregnant?: {
    dueDate?: FirebaseFirestore.Timestamp;
    currentWeek?: number;
    nextAppointment?: { label: string; date: FirebaseFirestore.Timestamp } | null;
    milestones?: { week: number; label: string; achieved: boolean }[];
  };
}

// users/{uid}/partnerPermissions/current
interface PartnerPermissionsDoc {
  approvedCategories: string[]; // literal option-card labels, see below
  onlyApproveMode: boolean;
}

// users/{uid}/partnerLink/current
interface PartnerLinkDoc {
  partnerUserId: string;
  relationshipType: 'husband' | 'boyfriend' | 'partner';
  inviteStatus: 'pending' | 'accepted';
  linkedAt: FirebaseFirestore.Timestamp;
}
```

**Assumption flagged explicitly:** `approvedCategories[]` is assumed to store the *exact literal option-card label strings* from `mockv4.html`'s `screen-partner-perm` (`'Appointment reminders'`, `'Pregnancy milestones'`, `'Support suggestions'`, `'Mood updates'`), because the mock's `toggleMultiSelect('partnerPermissions', 'Appointment reminders', this)` calls write those literal strings into `surveyState.partnerPermissions[]`, and design spec §6 says Plan 5 maps that array directly into Firestore. If Plan 5 instead persists camelCase enum keys, Task 2 Step 3's `KNOWN_CATEGORIES` constant is the only place that needs updating.

## Permission Category → `partnerView` Field Mapping

This is the concrete "nudges not data dumps" mapping (EVE2_PRD §6, §8) — every field on `partnerView` is either a direct copy of a genuinely non-sensitive scheduling fact, or a *derived, coarse* signal computed from raw data that itself never leaves the server.

| Permission category (exact label) | Source document(s) | Source field(s) read | `partnerView.current` field written | Derivation |
|---|---|---|---|---|
| `Appointment reminders` | `lifeStageProfile/current` | `pregnant.nextAppointment` | `upcomingAppointment: { label: string; date: Timestamp } \| null` | Direct copy of only `label`/`date` (never medication, allergy, or risk fields from the same document) when present; `null` otherwise. Copy is acceptable here because a scheduling fact is not a health data point. |
| `Pregnancy milestones` (only meaningful when `lifeStageProfile.type === 'pregnant'`) | `lifeStageProfile/current` | `pregnant.currentWeek`, `pregnant.milestones[]` | `pregnancyStage: { currentWeek: number; latestMilestone: string \| null } \| null` | Reduces the full milestone array to a single most-recently-achieved label plus the week counter. Never exposes the full milestone list, due date, or `highRisk`/medication fields — those are never on `partnerView` under any category. |
| `Support suggestions` | `users/{uid}/logs/{logId}` (most recent log by `date`) | `painLevel`, `symptoms[]` | `supportSuggested: boolean`, `supportReason: 'highPain' \| 'multipleSymptoms' \| null` | `supportSuggested = painLevel >= 7 OR symptoms.length >= 3`. The raw pain number and the raw symptom list are never copied — only the boolean and a coarse reason bucket. |
| `Mood updates` | `users/{uid}/logs/{logId}` (most recent log by `date`) | `mood` | `recentMoodTrend: 'low' \| 'neutral' \| 'positive'` | `'great'`/`'good'` → `'positive'`; `'okay'` → `'neutral'`; `'low'`/`'very_low'` → `'low'`; missing → `'neutral'`. The raw mood string is never copied — only the 3-bucket trend. |

If a category is not approved (or its parent condition, e.g. `type === 'pregnant'`, is not met), its key is **absent** from the document entirely — not `null`-valued, not stale — because Task 2 recomputes the whole document from scratch on every write (see below).

## Why This Can't Just Be Security Rules

Security rules can only decide, per document, "may this requester read/write this whole document" — they cannot answer "may this requester see this one field, reshaped into a coarser value, computed from a different document than the one being read." `recentMoodTrend` doesn't exist anywhere until a Cloud Function reads a raw `mood` string off a log entry and buckets it; a rule evaluated against `request.auth` at read time has no mechanism to run that bucketing, only to allow or deny access to whatever bytes are already stored. Granular, per-field, *derived* privacy requires a compute step that runs on write and produces a smaller, purpose-built document — which is exactly what `partnerView.current` is, and precisely the reason the partner's client is only ever pointed at it, never at `logs/` or `lifeStageProfile/` directly (those collections' rules, owned by Plan 5, can simply deny the partner all access, full stop).

---

## Task 1: Functions project scaffolding and emulator test harness

**Files:**
- Create: `D:\Projects\favourites\eve\EVE_MOBILE\functions\package.json`
- Create: `D:\Projects\favourites\eve\EVE_MOBILE\functions\tsconfig.json`
- Create: `D:\Projects\favourites\eve\EVE_MOBILE\functions\jest.config.js`
- Create: `D:\Projects\favourites\eve\EVE_MOBILE\functions\test\emulatorEnv.ts`
- Create: `D:\Projects\favourites\eve\EVE_MOBILE\functions\test\testUtils.ts`
- Create: `D:\Projects\favourites\eve\EVE_MOBILE\functions\src\index.ts`
- Create: `D:\Projects\favourites\eve\EVE_MOBILE\firebase.json`

**Interfaces:**
- Consumes: nothing (first task).
- Produces: `npm test` (from `functions/`) boots the Firestore emulator, runs Jest against it, and tears it down. `testUtils.ts` exports `clearEmulatorFirestore(projectId: string): Promise<void>` and `TEST_PROJECT_ID = 'eve-hackathon-test'`, both consumed by Tasks 2 and 4's tests. `index.ts` is where Tasks 3 and 5 add their trigger exports.

- [ ] **Step 1: Create `functions/package.json`**

```json
{
  "name": "eve-functions",
  "version": "1.0.0",
  "private": true,
  "engines": { "node": "20" },
  "main": "lib/index.js",
  "scripts": {
    "build": "tsc",
    "test": "firebase emulators:exec --only firestore --project eve-hackathon-test \"jest --runInBand\""
  },
  "dependencies": {
    "firebase-admin": "^12.1.0",
    "firebase-functions": "^5.0.1"
  },
  "devDependencies": {
    "@types/jest": "^29.5.12",
    "@types/node": "^20.12.7",
    "firebase-tools": "^13.7.3",
    "jest": "^29.7.0",
    "ts-jest": "^29.1.2",
    "typescript": "^5.4.5"
  }
}
```

- [ ] **Step 2: Create `functions/tsconfig.json`**

```json
{
  "compilerOptions": {
    "target": "es2020",
    "module": "commonjs",
    "lib": ["es2020"],
    "outDir": "lib",
    "rootDir": "src",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "resolveJsonModule": true,
    "sourceMap": true
  },
  "include": ["src/**/*.ts"],
  "compileOnSchema": false
}
```

- [ ] **Step 3: Create `functions/jest.config.js`**

```javascript
module.exports = {
  preset: 'ts-jest',
  testEnvironment: 'node',
  rootDir: '.',
  testMatch: ['<rootDir>/test/**/*.test.ts'],
  setupFiles: ['<rootDir>/test/emulatorEnv.ts'],
  testTimeout: 20000,
};
```

- [ ] **Step 4: Create `functions/test/emulatorEnv.ts`**

This must set the emulator host env vars *before* `firebase-admin` is ever imported by any test file, so `admin.initializeApp()` auto-connects to the emulator instead of production.

```typescript
process.env.FIRESTORE_EMULATOR_HOST = 'localhost:8080';
process.env.GCLOUD_PROJECT = 'eve-hackathon-test';
```

- [ ] **Step 5: Create `functions/test/testUtils.ts`**

```typescript
export const TEST_PROJECT_ID = 'eve-hackathon-test';

export async function clearEmulatorFirestore(projectId: string): Promise<void> {
  const url = `http://localhost:8080/emulator/v1/projects/${projectId}/databases/(default)/documents`;
  const response = await fetch(url, { method: 'DELETE' });
  if (!response.ok) {
    throw new Error(`Failed to clear emulator Firestore: ${response.status} ${response.statusText}`);
  }
}
```

- [ ] **Step 6: Create `functions/src/index.ts`**

```typescript
// Entry point for Cloud Functions deployment.
// Tasks 3 and 5 add re-exports here as they implement each trigger.
export {};
```

- [ ] **Step 7: Create `D:\Projects\favourites\eve\EVE_MOBILE\firebase.json`**

If this file already exists (e.g. Plan 3/4 ran first and created it for hosting/app config), merge the `emulators` block in rather than overwriting the file.

```json
{
  "functions": {
    "source": "functions"
  },
  "firestore": {
    "rules": "firestore.rules",
    "indexes": "firestore.indexes.json"
  },
  "emulators": {
    "firestore": { "port": 8080 },
    "functions": { "port": 5001 }
  }
}
```

- [ ] **Step 8: Install dependencies and verify the harness boots**

Run (from `D:\Projects\favourites\eve\EVE_MOBILE\functions`):
```bash
npm install
npm test
```
Expected: the emulator starts, Jest reports "No tests found" (0 test files exist yet) with exit code 0 or 1 depending on Jest version's empty-suite behavior — either is acceptable at this step; the goal is confirming the emulator boots and Jest runs against it without a connection error. If `npm test` errors with "port already in use," a leftover emulator process needs killing before proceeding.

- [ ] **Step 9: Commit**

```bash
git add functions/package.json functions/tsconfig.json functions/jest.config.js functions/test/emulatorEnv.ts functions/test/testUtils.ts functions/src/index.ts firebase.json
git commit -m "chore: scaffold functions project and Firestore emulator test harness"
```

---

## Task 2: `partnerView.ts` — permission evaluation and full recompute logic

**Files:**
- Create: `D:\Projects\favourites\eve\EVE_MOBILE\functions\src\partnerView.ts`
- Create: `D:\Projects\favourites\eve\EVE_MOBILE\functions\test\partnerView.test.ts`

**Interfaces:**
- Consumes: `TEST_PROJECT_ID`, `clearEmulatorFirestore` from `../test/testUtils` (Task 1).
- Produces: `PermissionCategory` (union type), `KNOWN_CATEGORIES: PermissionCategory[]`, `isCategoryApproved(category, approvedCategories, onlyApproveMode): boolean`, `recomputePartnerView(uid: string): Promise<void>` — all consumed by Task 3 (trigger wiring) and Task 4 (`chatSystemMessages.ts` imports `isCategoryApproved`/`PermissionCategory`/`KNOWN_CATEGORIES` from this file rather than redefining them).

- [ ] **Step 1: Write the failing test for category approval + empty-permissions minimal view**

```typescript
// functions/test/partnerView.test.ts
import * as admin from 'firebase-admin';
import { TEST_PROJECT_ID, clearEmulatorFirestore } from './testUtils';

if (!admin.apps.length) {
  admin.initializeApp({ projectId: TEST_PROJECT_ID });
}
const db = admin.firestore();

import { recomputePartnerView, isCategoryApproved } from '../src/partnerView';

describe('isCategoryApproved', () => {
  it('approves a category present in approvedCategories', () => {
    expect(isCategoryApproved('Mood updates', ['Mood updates'], true)).toBe(true);
  });

  it('withholds a known category that is not in approvedCategories, regardless of onlyApproveMode', () => {
    expect(isCategoryApproved('Mood updates', [], true)).toBe(false);
    expect(isCategoryApproved('Mood updates', [], false)).toBe(false);
  });

  it('withholds an unrecognized future category when onlyApproveMode is true, exposes it when false', () => {
    expect(isCategoryApproved('Future category' as any, [], true)).toBe(false);
    expect(isCategoryApproved('Future category' as any, [], false)).toBe(true);
  });
});

describe('recomputePartnerView', () => {
  const uid = 'test-user-empty-perms';

  beforeEach(async () => {
    await clearEmulatorFirestore(TEST_PROJECT_ID);
  });

  it('produces a minimal partnerView when onlyApproveMode is true and approvedCategories is empty', async () => {
    await db.doc(`users/${uid}/partnerPermissions/current`).set({
      approvedCategories: [],
      onlyApproveMode: true,
    });

    await recomputePartnerView(uid);

    const snap = await db.doc(`users/${uid}/partnerView/current`).get();
    const data = snap.data();
    expect(data).toBeDefined();
    expect(data!.upcomingAppointment).toBeUndefined();
    expect(data!.pregnancyStage).toBeUndefined();
    expect(data!.supportSuggested).toBeUndefined();
    expect(data!.recentMoodTrend).toBeUndefined();
    expect(data!.updatedAt).toBeDefined();
  });
});
```

- [ ] **Step 2: Run the test to verify it fails**

Run (from `functions/`): `npm test`
Expected: FAIL — `Cannot find module '../src/partnerView'` (file does not exist yet).

- [ ] **Step 3: Implement `functions/src/partnerView.ts`**

```typescript
import * as admin from 'firebase-admin';
import { onDocumentWritten } from 'firebase-functions/v2/firestore';

if (!admin.apps.length) {
  admin.initializeApp();
}
const db = admin.firestore();

export type PermissionCategory =
  | 'Appointment reminders'
  | 'Pregnancy milestones'
  | 'Support suggestions'
  | 'Mood updates';

export const KNOWN_CATEGORIES: PermissionCategory[] = [
  'Appointment reminders',
  'Pregnancy milestones',
  'Support suggestions',
  'Mood updates',
];

interface PartnerPermissionsDoc {
  approvedCategories?: string[];
  onlyApproveMode?: boolean;
}

interface LogDoc {
  date?: admin.firestore.Timestamp;
  symptoms?: string[];
  mood?: 'great' | 'good' | 'okay' | 'low' | 'very_low' | null;
  painLevel?: number | null;
  notes?: string;
}

interface LifeStageProfileDoc {
  type?: 'cycle' | 'conceive' | 'pregnant' | 'postpartum' | 'menopause';
  pregnant?: {
    currentWeek?: number;
    nextAppointment?: { label: string; date: admin.firestore.Timestamp } | null;
    milestones?: { week: number; label: string; achieved: boolean }[];
  };
}

export interface PartnerViewDoc {
  updatedAt: admin.firestore.FieldValue;
  upcomingAppointment?: { label: string; date: admin.firestore.Timestamp } | null;
  pregnancyStage?: { currentWeek: number; latestMilestone: string | null } | null;
  supportSuggested?: boolean;
  supportReason?: 'highPain' | 'multipleSymptoms' | null;
  recentMoodTrend?: 'low' | 'neutral' | 'positive';
}

/**
 * Decides whether `category` is currently allowed to appear on partnerView.
 *
 * Known V0 categories (KNOWN_CATEGORIES) are a strict allowlist: they must
 * appear in approvedCategories, full stop — onlyApproveMode does not relax
 * that. onlyApproveMode instead governs the forward-compatibility case: a
 * category the product doesn't define yet (e.g. one added post-hackathon)
 * defaults to withheld when onlyApproveMode is true (the safe default) and
 * defaults to exposed when she has explicitly turned that master toggle off.
 */
export function isCategoryApproved(
  category: PermissionCategory,
  approvedCategories: string[],
  onlyApproveMode: boolean
): boolean {
  if (approvedCategories.includes(category)) return true;
  const isKnownV0Category = (KNOWN_CATEGORIES as string[]).includes(category);
  if (!isKnownV0Category) return !onlyApproveMode;
  return false;
}

function moodToTrend(mood: LogDoc['mood']): 'low' | 'neutral' | 'positive' {
  switch (mood) {
    case 'great':
    case 'good':
      return 'positive';
    case 'low':
    case 'very_low':
      return 'low';
    default:
      return 'neutral';
  }
}

/**
 * Fully recomputes users/{uid}/partnerView/current from the three source
 * documents. This always REPLACES the document (set with merge: false) so
 * that revoking a category removes its field on the very next recompute,
 * rather than leaving a stale value behind.
 */
export async function recomputePartnerView(uid: string): Promise<void> {
  const userRef = db.collection('users').doc(uid);

  const [permsSnap, latestLogSnap, lifeStageSnap] = await Promise.all([
    userRef.collection('partnerPermissions').doc('current').get(),
    userRef.collection('logs').orderBy('date', 'desc').limit(1).get(),
    userRef.collection('lifeStageProfile').doc('current').get(),
  ]);

  const perms = (permsSnap.data() as PartnerPermissionsDoc | undefined) ?? {};
  const approvedCategories = perms.approvedCategories ?? [];
  const onlyApproveMode = perms.onlyApproveMode ?? true;

  const latestLog = latestLogSnap.empty
    ? undefined
    : (latestLogSnap.docs[0].data() as LogDoc);
  const lifeStage = (lifeStageSnap.data() as LifeStageProfileDoc | undefined) ?? {};

  const view: PartnerViewDoc = {
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  if (isCategoryApproved('Appointment reminders', approvedCategories, onlyApproveMode)) {
    const appt = lifeStage.pregnant?.nextAppointment ?? null;
    view.upcomingAppointment = appt ? { label: appt.label, date: appt.date } : null;
  }

  if (
    lifeStage.type === 'pregnant' &&
    isCategoryApproved('Pregnancy milestones', approvedCategories, onlyApproveMode)
  ) {
    const milestones = lifeStage.pregnant?.milestones ?? [];
    const achieved = milestones.filter((m) => m.achieved);
    const latest = achieved.length > 0 ? achieved[achieved.length - 1] : null;
    view.pregnancyStage = {
      currentWeek: lifeStage.pregnant?.currentWeek ?? 0,
      latestMilestone: latest ? latest.label : null,
    };
  }

  if (isCategoryApproved('Support suggestions', approvedCategories, onlyApproveMode)) {
    const painLevel = latestLog?.painLevel ?? 0;
    const symptomCount = latestLog?.symptoms?.length ?? 0;
    const highPain = painLevel >= 7;
    const manySymptoms = symptomCount >= 3;
    view.supportSuggested = highPain || manySymptoms;
    view.supportReason = highPain ? 'highPain' : manySymptoms ? 'multipleSymptoms' : null;
  }

  if (isCategoryApproved('Mood updates', approvedCategories, onlyApproveMode)) {
    view.recentMoodTrend = moodToTrend(latestLog?.mood ?? null);
  }

  await userRef.collection('partnerView').doc('current').set(view, { merge: false });
}

export const onLogWrittenRecomputePartnerView = onDocumentWritten(
  'users/{uid}/logs/{logId}',
  async (event) => {
    await recomputePartnerView(event.params.uid);
  }
);

export const onLifeStageProfileWrittenRecomputePartnerView = onDocumentWritten(
  'users/{uid}/lifeStageProfile/current',
  async (event) => {
    await recomputePartnerView(event.params.uid);
  }
);

export const onPartnerPermissionsWrittenRecomputePartnerView = onDocumentWritten(
  'users/{uid}/partnerPermissions/current',
  async (event) => {
    await recomputePartnerView(event.params.uid);
  }
);
```

- [ ] **Step 4: Run the test to verify it passes**

Run (from `functions/`): `npm test`
Expected: PASS — all 4 tests in `partnerView.test.ts` (3 `isCategoryApproved` cases + the minimal-view case) succeed.

- [ ] **Step 5: Commit**

```bash
git add functions/src/partnerView.ts functions/test/partnerView.test.ts
git commit -m "feat: add partnerView permission evaluation and full-recompute logic"
```

---

## Task 3: `partnerView.ts` — approve/revoke correctness tests and trigger wiring

**Files:**
- Modify: `D:\Projects\favourites\eve\EVE_MOBILE\functions\test\partnerView.test.ts`
- Modify: `D:\Projects\favourites\eve\EVE_MOBILE\functions\src\index.ts`

**Interfaces:**
- Consumes: `recomputePartnerView` (Task 2).
- Produces: `index.ts` re-exports `onLogWrittenRecomputePartnerView`, `onLifeStageProfileWrittenRecomputePartnerView`, `onPartnerPermissionsWrittenRecomputePartnerView` for deployment; Task 5 appends its own exports to the same file rather than replacing it.

- [ ] **Step 1: Write the failing tests for approve-adds-field and revoke-removes-field**

Append to `functions/test/partnerView.test.ts`, inside the existing `describe('recomputePartnerView', ...)` block (after the minimal-view test):

```typescript
  it('approving Mood updates causes the next recompute to include recentMoodTrend', async () => {
    const uid = 'test-user-approve-mood';
    await db.doc(`users/${uid}/partnerPermissions/current`).set({
      approvedCategories: ['Mood updates'],
      onlyApproveMode: true,
    });
    await db.doc(`users/${uid}/logs/log1`).set({
      date: admin.firestore.Timestamp.fromDate(new Date('2026-08-01')),
      symptoms: [],
      mood: 'low',
      painLevel: 2,
      notes: '',
    });

    await recomputePartnerView(uid);

    const snap = await db.doc(`users/${uid}/partnerView/current`).get();
    expect(snap.data()!.recentMoodTrend).toBe('low');
  });

  it('revoking a previously-approved category removes its field on the next recompute', async () => {
    const uid = 'test-user-revoke-mood';
    const permsRef = db.doc(`users/${uid}/partnerPermissions/current`);
    await permsRef.set({ approvedCategories: ['Mood updates'], onlyApproveMode: true });
    await db.doc(`users/${uid}/logs/log1`).set({
      date: admin.firestore.Timestamp.fromDate(new Date('2026-08-01')),
      symptoms: [],
      mood: 'low',
      painLevel: 2,
      notes: '',
    });
    await recomputePartnerView(uid);

    let snap = await db.doc(`users/${uid}/partnerView/current`).get();
    expect(snap.data()!.recentMoodTrend).toBe('low');

    await permsRef.set({ approvedCategories: [], onlyApproveMode: true });
    await recomputePartnerView(uid);

    snap = await db.doc(`users/${uid}/partnerView/current`).get();
    expect(snap.data()!.recentMoodTrend).toBeUndefined();
  });
```

- [ ] **Step 2: Run the tests to verify they pass against the existing Task 2 implementation**

Run (from `functions/`): `npm test`
Expected: PASS — no implementation changes are needed for these two tests; they verify behavior Task 2 already built (full-document `set` with `merge: false` is what makes revoke-removes-field true). This step is a regression check, not new implementation.

- [ ] **Step 3: Wire the trigger exports into `functions/src/index.ts`**

```typescript
// Entry point for Cloud Functions deployment.
export {
  onLogWrittenRecomputePartnerView,
  onLifeStageProfileWrittenRecomputePartnerView,
  onPartnerPermissionsWrittenRecomputePartnerView,
} from './partnerView';
```

- [ ] **Step 4: Verify the project still builds**

Run (from `functions/`): `npm run build`
Expected: `tsc` exits 0, `functions/lib/index.js` and `functions/lib/partnerView.js` are produced.

- [ ] **Step 5: Commit**

```bash
git add functions/test/partnerView.test.ts functions/src/index.ts
git commit -m "test: cover partnerView approve/revoke correctness; wire trigger exports"
```

---

## Task 4: `chatSystemMessages.ts` — qualifying condition, message templates, and handler

**Files:**
- Create: `D:\Projects\favourites\eve\EVE_MOBILE\functions\src\chatSystemMessages.ts`
- Create: `D:\Projects\favourites\eve\EVE_MOBILE\functions\test\chatSystemMessages.test.ts`

**Interfaces:**
- Consumes: `PermissionCategory`, `isCategoryApproved` from `./partnerView` (Task 2).
- Produces: `handleLogCreated(uid: string, logId: string, log: LogDoc): Promise<void>`, `onLogCreatedGenerateSystemMessage` (the `onDocumentCreated` trigger export, wired in Task 5).

**Qualifying condition (concrete):** a newly-created log entry qualifies when `painLevel >= 7` (support-suggestion nudge, required category `Support suggestions`) or `mood === 'low' || mood === 'very_low'` (mood nudge, required category `Mood updates`). Pain is checked first — a log with both high pain and low mood produces one pain-flavored message, not two.

**Anti-spoofing note:** the write in Step 3 below uses the Admin SDK from inside a Cloud Function, which always bypasses Firestore security rules — rules only constrain requests authenticated as an end-user client (`request.auth`). Plan 5's `firestore.rules` can therefore safely include a blanket `allow create: if request.resource.data.type != 'system'` on `users/{uid}/chat/{messageId}`, which makes it *structurally impossible* for either her client or the partner's client to forge a `type: 'system'` message — only this trusted, server-run function can produce one, and only when the qualifying condition and an approved permission actually hold.

- [ ] **Step 1: Write the failing tests for qualifying-with-permission and qualifying-without-permission**

```typescript
// functions/test/chatSystemMessages.test.ts
import * as admin from 'firebase-admin';
import { TEST_PROJECT_ID, clearEmulatorFirestore } from './testUtils';

if (!admin.apps.length) {
  admin.initializeApp({ projectId: TEST_PROJECT_ID });
}
const db = admin.firestore();

import { handleLogCreated } from '../src/chatSystemMessages';

describe('handleLogCreated', () => {
  beforeEach(async () => {
    await clearEmulatorFirestore(TEST_PROJECT_ID);
  });

  it('writes exactly one system chat message for a qualifying low-mood log with Mood updates approved', async () => {
    const uid = 'test-user-mood-approved';
    await db.doc(`users/${uid}/partnerLink/current`).set({
      partnerUserId: 'partner-1',
      relationshipType: 'husband',
      inviteStatus: 'accepted',
      linkedAt: admin.firestore.Timestamp.now(),
    });
    await db.doc(`users/${uid}/partnerPermissions/current`).set({
      approvedCategories: ['Mood updates'],
      onlyApproveMode: true,
    });

    await handleLogCreated(uid, 'log1', {
      date: admin.firestore.Timestamp.now(),
      symptoms: [],
      mood: 'low',
      painLevel: 1,
      notes: '',
    });

    const chatSnap = await db.collection(`users/${uid}/chat`).get();
    expect(chatSnap.size).toBe(1);
    const message = chatSnap.docs[0].data();
    expect(message.senderId).toBe('system');
    expect(message.type).toBe('system');
    expect(message.category).toBe('moodUpdate');
    expect(message.sourceLogId).toBe('log1');
    expect(typeof message.messageText).toBe('string');
    expect(message.messageText.length).toBeGreaterThan(0);
  });

  it('writes no system message for a qualifying log when the relevant permission is not approved', async () => {
    const uid = 'test-user-mood-not-approved';
    await db.doc(`users/${uid}/partnerLink/current`).set({
      partnerUserId: 'partner-1',
      relationshipType: 'husband',
      inviteStatus: 'accepted',
      linkedAt: admin.firestore.Timestamp.now(),
    });
    await db.doc(`users/${uid}/partnerPermissions/current`).set({
      approvedCategories: ['Appointment reminders'],
      onlyApproveMode: true,
    });

    await handleLogCreated(uid, 'log1', {
      date: admin.firestore.Timestamp.now(),
      symptoms: [],
      mood: 'low',
      painLevel: 1,
      notes: '',
    });

    const chatSnap = await db.collection(`users/${uid}/chat`).get();
    expect(chatSnap.size).toBe(0);
  });
});
```

- [ ] **Step 2: Run the tests to verify they fail**

Run (from `functions/`): `npm test`
Expected: FAIL — `Cannot find module '../src/chatSystemMessages'`.

- [ ] **Step 3: Implement `functions/src/chatSystemMessages.ts`**

```typescript
import * as admin from 'firebase-admin';
import { onDocumentCreated } from 'firebase-functions/v2/firestore';
import { PermissionCategory, isCategoryApproved } from './partnerView';

if (!admin.apps.length) {
  admin.initializeApp();
}
const db = admin.firestore();

interface LogDoc {
  date?: admin.firestore.Timestamp;
  symptoms?: string[];
  mood?: 'great' | 'good' | 'okay' | 'low' | 'very_low' | null;
  painLevel?: number | null;
  notes?: string;
}

interface PartnerPermissionsDoc {
  approvedCategories?: string[];
  onlyApproveMode?: boolean;
}

interface PartnerLinkDoc {
  inviteStatus?: 'pending' | 'accepted';
}

type QualifyingReason =
  | { kind: 'highPain'; severity: 'moderate' | 'severe' }
  | { kind: 'lowMood' }
  | null;

/**
 * Concrete qualifying condition for an Eve system chat nudge:
 *  - painLevel >= 9  -> severe pain nudge
 *  - painLevel >= 7  -> moderate pain nudge
 *  - mood is 'low' or 'very_low' (checked only if pain doesn't already qualify)
 * Everything else produces no nudge.
 */
export function getQualifyingReason(log: LogDoc): QualifyingReason {
  const painLevel = log.painLevel ?? 0;
  if (painLevel >= 9) return { kind: 'highPain', severity: 'severe' };
  if (painLevel >= 7) return { kind: 'highPain', severity: 'moderate' };
  if (log.mood === 'low' || log.mood === 'very_low') return { kind: 'lowMood' };
  return null;
}

function requiredCategoryFor(reason: QualifyingReason): PermissionCategory | null {
  if (!reason) return null;
  return reason.kind === 'highPain' ? 'Support suggestions' : 'Mood updates';
}

// Warm, formal, no-emoji copy per EVE2_PRD §6. Not a randomized pool in V0
// (varied notification phrasing is explicitly roadmap, EVE2_PRD §7) —
// severity picks a fixed template deterministically.
function messageTextFor(reason: QualifyingReason): string {
  if (!reason) return '';
  if (reason.kind === 'highPain') {
    return reason.severity === 'severe'
      ? 'Eve: Today has been especially difficult for her. A visit, a call, or simply being present could mean a great deal right now.'
      : 'Eve: She logged a difficult day today. This may be a good moment to check in and offer some support.';
  }
  return 'Eve: She noted today has been an emotionally low day. A kind word or a small gesture of support could mean a lot right now.';
}

/**
 * Core handler: given a newly-created log entry, decides whether it
 * qualifies for an Eve system chat nudge and, if so, writes it — but only
 * when she has an accepted partner link AND has approved the category the
 * qualifying reason maps to. Deliberately keeps the message text coarse
 * (no raw pain number, no raw symptom list, no raw mood string) so the
 * chat channel doesn't leak more than partnerView itself is allowed to.
 */
export async function handleLogCreated(uid: string, logId: string, log: LogDoc): Promise<void> {
  const reason = getQualifyingReason(log);
  if (!reason) return;

  const requiredCategory = requiredCategoryFor(reason);
  if (!requiredCategory) return;

  const userRef = db.collection('users').doc(uid);

  const [linkSnap, permsSnap] = await Promise.all([
    userRef.collection('partnerLink').doc('current').get(),
    userRef.collection('partnerPermissions').doc('current').get(),
  ]);

  const link = linkSnap.data() as PartnerLinkDoc | undefined;
  if (!link || link.inviteStatus !== 'accepted') return;

  const perms = (permsSnap.data() as PartnerPermissionsDoc | undefined) ?? {};
  const approvedCategories = perms.approvedCategories ?? [];
  const onlyApproveMode = perms.onlyApproveMode ?? true;

  if (!isCategoryApproved(requiredCategory, approvedCategories, onlyApproveMode)) return;

  await userRef.collection('chat').add({
    senderId: 'system',
    type: 'system',
    messageText: messageTextFor(reason),
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
    category: requiredCategory === 'Support suggestions' ? 'supportSuggestion' : 'moodUpdate',
    sourceLogId: logId,
  });
}

export const onLogCreatedGenerateSystemMessage = onDocumentCreated(
  'users/{uid}/logs/{logId}',
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;
    await handleLogCreated(event.params.uid, event.params.logId, snapshot.data() as LogDoc);
  }
);
```

- [ ] **Step 4: Run the tests to verify they pass**

Run (from `functions/`): `npm test`
Expected: PASS — both `chatSystemMessages.test.ts` cases succeed.

- [ ] **Step 5: Commit**

```bash
git add functions/src/chatSystemMessages.ts functions/test/chatSystemMessages.test.ts
git commit -m "feat: add Eve system chat nudge qualifying condition and handler"
```

---

## Task 5: `chatSystemMessages.ts` — severity-tier and no-permission-category regression tests, trigger wiring

**Files:**
- Modify: `D:\Projects\favourites\eve\EVE_MOBILE\functions\test\chatSystemMessages.test.ts`
- Modify: `D:\Projects\favourites\eve\EVE_MOBILE\functions\src\index.ts`

**Interfaces:**
- Consumes: `handleLogCreated`, `getQualifyingReason` (Task 4).
- Produces: `index.ts` also re-exports `onLogCreatedGenerateSystemMessage` for deployment.

- [ ] **Step 1: Write the failing tests for severity tiering and the no-partner-link case**

Append to `functions/test/chatSystemMessages.test.ts`, inside `describe('handleLogCreated', ...)`:

```typescript
  it('writes a severe-tier message for painLevel >= 9 with Support suggestions approved', async () => {
    const uid = 'test-user-severe-pain';
    await db.doc(`users/${uid}/partnerLink/current`).set({
      partnerUserId: 'partner-1',
      relationshipType: 'partner',
      inviteStatus: 'accepted',
      linkedAt: admin.firestore.Timestamp.now(),
    });
    await db.doc(`users/${uid}/partnerPermissions/current`).set({
      approvedCategories: ['Support suggestions'],
      onlyApproveMode: true,
    });

    await handleLogCreated(uid, 'log1', {
      date: admin.firestore.Timestamp.now(),
      symptoms: ['cramps'],
      mood: 'okay',
      painLevel: 9,
      notes: '',
    });

    const chatSnap = await db.collection(`users/${uid}/chat`).get();
    expect(chatSnap.size).toBe(1);
    expect(chatSnap.docs[0].data().messageText).toContain('especially difficult');
  });

  it('writes no system message when there is no accepted partner link, even with the category approved', async () => {
    const uid = 'test-user-no-link';
    await db.doc(`users/${uid}/partnerPermissions/current`).set({
      approvedCategories: ['Mood updates'],
      onlyApproveMode: true,
    });

    await handleLogCreated(uid, 'log1', {
      date: admin.firestore.Timestamp.now(),
      symptoms: [],
      mood: 'very_low',
      painLevel: 0,
      notes: '',
    });

    const chatSnap = await db.collection(`users/${uid}/chat`).get();
    expect(chatSnap.size).toBe(0);
  });

  it('writes no system message for a non-qualifying log', async () => {
    const uid = 'test-user-non-qualifying';
    await db.doc(`users/${uid}/partnerLink/current`).set({
      partnerUserId: 'partner-1',
      relationshipType: 'partner',
      inviteStatus: 'accepted',
      linkedAt: admin.firestore.Timestamp.now(),
    });
    await db.doc(`users/${uid}/partnerPermissions/current`).set({
      approvedCategories: ['Mood updates', 'Support suggestions'],
      onlyApproveMode: true,
    });

    await handleLogCreated(uid, 'log1', {
      date: admin.firestore.Timestamp.now(),
      symptoms: ['cramps'],
      mood: 'good',
      painLevel: 3,
      notes: '',
    });

    const chatSnap = await db.collection(`users/${uid}/chat`).get();
    expect(chatSnap.size).toBe(0);
  });
```

- [ ] **Step 2: Run the tests to verify they pass**

Run (from `functions/`): `npm test`
Expected: PASS — no implementation changes needed; these confirm behavior Task 4 already built.

- [ ] **Step 3: Wire the trigger export into `functions/src/index.ts`**

```typescript
// Entry point for Cloud Functions deployment.
export {
  onLogWrittenRecomputePartnerView,
  onLifeStageProfileWrittenRecomputePartnerView,
  onPartnerPermissionsWrittenRecomputePartnerView,
} from './partnerView';

export { onLogCreatedGenerateSystemMessage } from './chatSystemMessages';
```

- [ ] **Step 4: Verify the project still builds**

Run (from `functions/`): `npm run build`
Expected: `tsc` exits 0, `functions/lib/chatSystemMessages.js` is produced alongside the Task 3 output.

- [ ] **Step 5: Commit**

```bash
git add functions/test/chatSystemMessages.test.ts functions/src/index.ts
git commit -m "test: cover chat nudge severity tiering and missing-link/permission cases; wire trigger export"
```

---

## Task 6: Full suite run and cross-check against required scenarios

**Files:**
- None created or modified — verification only.

**Interfaces:**
- Consumes: everything from Tasks 1–5.
- Produces: nothing new; confirms the five required test scenarios from this plan's brief are all present and passing.

- [ ] **Step 1: Run the complete test suite**

Run (from `D:\Projects\favourites\eve\EVE_MOBILE\functions`): `npm test`

Expected: PASS, with the following scenarios all covered somewhere in the two test files (cross-check by name):
- (a) approving a category → next recompute includes its derived field: `partnerView.test.ts` → `'approving Mood updates causes the next recompute to include recentMoodTrend'`.
- (b) revoking a category → field disappears on next recompute: `partnerView.test.ts` → `'revoking a previously-approved category removes its field on the next recompute'`.
- (c) `onlyApproveMode = true` + empty `approvedCategories[]` → minimal `partnerView`: `partnerView.test.ts` → `'produces a minimal partnerView when onlyApproveMode is true and approvedCategories is empty'`.
- (d) qualifying low-mood log + approved relevant permission → exactly one system message with expected shape: `chatSystemMessages.test.ts` → `'writes exactly one system chat message for a qualifying low-mood log with Mood updates approved'`.
- (e) qualifying log without the relevant permission → no system message: `chatSystemMessages.test.ts` → `'writes no system message for a qualifying log when the relevant permission is not approved'`.

- [ ] **Step 2: Run the build one more time as a final sanity check**

Run (from `functions/`): `npm run build`
Expected: exits 0.

- [ ] **Step 3: Commit (only if Step 1/2 surfaced fixes; otherwise this task is verification-only and produces no diff)**

```bash
git status
```
If clean, no commit is needed — Task 6 is a verification gate, not a code change.
