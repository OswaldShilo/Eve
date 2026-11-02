import { NOTIFICATION_TYPES, type NotificationType } from '../../shared/src/types.js';

interface ScheduleSlot {
  /** 0-23, UTC. Per-user time zones are a known V0 gap. */
  hour: number;
  /** 0 or 30 — the dispatcher runs every 30 minutes. */
  minute: 0 | 30;
}

/**
 * Fixed daily fire times per type. Eligibility only: whether a type is
 * enabled and "now" falls in one of its windows — not whether there is
 * an appointment today, which belongs to the feature owning that data.
 */
export const NOTIFICATION_SCHEDULE: Record<NotificationType, ScheduleSlot[]> = {
  morning: [{ hour: 7, minute: 0 }],
  daily_tip: [{ hour: 8, minute: 30 }],
  appointment: [{ hour: 8, minute: 0 }],
  cycle: [{ hour: 8, minute: 0 }],
  medicine: [
    { hour: 9, minute: 0 },
    { hour: 21, minute: 0 },
  ],
  water: [
    { hour: 10, minute: 0 },
    { hour: 13, minute: 0 },
    { hour: 16, minute: 0 },
    { hour: 19, minute: 0 },
  ],
  mood: [
    { hour: 12, minute: 0 },
    { hour: 20, minute: 0 },
  ],
  workout: [{ hour: 17, minute: 30 }],
  sleep: [{ hour: 21, minute: 30 }],
};

const slotIndex = (hour: number, minute: number) => hour * 2 + (minute >= 30 ? 1 : 0);

export function dueNotificationTypes(enabledReminders: readonly string[], now: Date): NotificationType[] {
  const nowSlot = slotIndex(now.getUTCHours(), now.getUTCMinutes());
  return NOTIFICATION_TYPES.filter(
    (type) =>
      enabledReminders.includes(type) &&
      NOTIFICATION_SCHEDULE[type].some((slot) => slotIndex(slot.hour, slot.minute) === nowSlot),
  );
}
