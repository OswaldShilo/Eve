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
