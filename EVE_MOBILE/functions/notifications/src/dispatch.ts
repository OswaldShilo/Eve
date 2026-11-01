import { ID, type Messaging } from 'node-appwrite';
import type { Db } from '../../shared/src/db.js';
import { TABLES } from '../../shared/src/ids.js';
import type { NotificationType } from '../../shared/src/types.js';
import { dueNotificationTypes } from './eligibility.js';

export interface Messenger {
  pushToUser(uid: string, title: string, body: string, data: Record<string, string>): Promise<void>;
}

/** Appwrite native push addressed to a user — reaches every device she is subscribed on. */
export function appwriteMessenger(messaging: Messaging): Messenger {
  return {
    async pushToUser(uid, title, body, data) {
      await messaging.createPush({ messageId: ID.unique(), title, body, users: [uid], data });
    },
  };
}

export const NOTIFICATION_COPY: Record<NotificationType, string> = {
  morning: 'Good morning. Eve has a moment for you whenever you are ready.',
  medicine: 'A gentle reminder for your medication.',
  workout: "Today's workout is waiting whenever you are ready for it.",
  water: 'A short reminder to drink some water.',
  sleep: 'Consider winding down soon. Rest matters.',
  cycle: 'Your cycle tracker has an update worth a look.',
  appointment: 'You have an appointment reminder from Eve.',
  mood: 'How are you feeling right now? Eve would like to know.',
  daily_tip: 'Eve has a new insight for you today.',
};

/** Returns how many pushes were sent. One failing user never blocks the others. */
export async function dispatchDueNotifications(
  db: Db,
  messenger: Messenger,
  now: Date,
  log: (message: string) => void = () => undefined,
): Promise<number> {
  let sent = 0;
  for (const row of await db.listRows(TABLES.preferences)) {
    const enabled = (row.enabledReminders as string[] | null) ?? [];
    for (const type of dueNotificationTypes(enabled, now)) {
      try {
        await messenger.pushToUser(row.$id, 'Eve', NOTIFICATION_COPY[type], { notificationType: type });
        sent += 1;
      } catch (e) {
        log(`notifications: push ${type} to ${row.$id} failed: ${e instanceof Error ? e.message : String(e)}`);
      }
    }
  }
  return sent;
}
