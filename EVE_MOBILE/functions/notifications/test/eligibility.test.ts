import { describe, expect, it } from 'vitest';
import { dueNotificationTypes } from '../src/eligibility.js';
import { NOTIFICATION_TYPES } from '../../shared/src/types.js';

const at = (h: number, m: number) => new Date(Date.UTC(2026, 7, 8, h, m));

describe('dueNotificationTypes', () => {
  it('returns nothing when no reminders are enabled', () => {
    expect(dueNotificationTypes([], at(7, 0))).toEqual([]);
  });

  it('returns morning at 07:00 UTC and anywhere in its 30-minute window', () => {
    expect(dueNotificationTypes(['morning'], at(7, 0))).toEqual(['morning']);
    expect(dueNotificationTypes(['morning'], at(7, 22))).toEqual(['morning']);
    expect(dueNotificationTypes(['morning'], at(9, 0))).toEqual([]);
  });

  it('returns several types due in the same slot, in canonical order', () => {
    expect(dueNotificationTypes(['cycle', 'appointment'], at(8, 10))).toEqual(['cycle', 'appointment']);
  });

  it('handles multi-slot types (medicine morning and evening)', () => {
    expect(dueNotificationTypes(['medicine'], at(9, 5))).toEqual(['medicine']);
    expect(dueNotificationTypes(['medicine'], at(21, 5))).toEqual(['medicine']);
    expect(dueNotificationTypes(['medicine'], at(14, 0))).toEqual([]);
  });

  it('ignores unknown values', () => {
    expect(dueNotificationTypes(['morning', 'not_a_type'], at(7, 0))).toEqual(['morning']);
  });

  it('covers all nine types across their slots', () => {
    const all = [...NOTIFICATION_TYPES];
    expect(dueNotificationTypes(all, at(7, 0))).toEqual(['morning']);
    expect(dueNotificationTypes(all, at(8, 0))).toEqual(['cycle', 'appointment']);
    expect(dueNotificationTypes(all, at(8, 30))).toEqual(['daily_tip']);
    expect(dueNotificationTypes(all, at(17, 30))).toEqual(['workout']);
    expect(dueNotificationTypes(all, at(21, 30))).toEqual(['sleep']);
  });
});
