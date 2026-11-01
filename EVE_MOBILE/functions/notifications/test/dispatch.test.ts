import { describe, expect, it } from 'vitest';
import { dispatchDueNotifications, NOTIFICATION_COPY, type Messenger } from '../src/dispatch.js';
import { MemoryDb } from '../../shared/test/memoryDb.js';

function recordingMessenger() {
  const sent: { uid: string; title: string; body: string; data: Record<string, string> }[] = [];
  const messenger: Messenger = {
    async pushToUser(uid, title, body, data) {
      sent.push({ uid, title, body, data });
    },
  };
  return { messenger, sent };
}

describe('dispatchDueNotifications', () => {
  it('pushes one message per due type to each eligible user only', async () => {
    const db = new MemoryDb();
    await db.createRow('preferences', 'u1', { enabledReminders: ['morning', 'water'] }, []);
    await db.createRow('preferences', 'u2', { enabledReminders: ['sleep'] }, []);
    await db.createRow('preferences', 'u3', { enabledReminders: [] }, []);
    const { messenger, sent } = recordingMessenger();

    const count = await dispatchDueNotifications(db, messenger, new Date(Date.UTC(2026, 7, 8, 7, 5)));

    expect(count).toBe(1);
    expect(sent).toEqual([
      { uid: 'u1', title: 'Eve', body: NOTIFICATION_COPY.morning, data: { notificationType: 'morning' } },
    ]);
  });

  it('keeps going when one push fails and reports only successes', async () => {
    const db = new MemoryDb();
    await db.createRow('preferences', 'u1', { enabledReminders: ['morning'] }, []);
    await db.createRow('preferences', 'u2', { enabledReminders: ['morning'] }, []);
    const sent: string[] = [];
    const messenger: Messenger = {
      async pushToUser(uid) {
        if (uid === 'u1') throw new Error('no targets');
        sent.push(uid);
      },
    };
    const count = await dispatchDueNotifications(db, messenger, new Date(Date.UTC(2026, 7, 8, 7, 0)));
    expect(count).toBe(1);
    expect(sent).toEqual(['u2']);
  });

  it('notification copy has no emojis', () => {
    for (const body of Object.values(NOTIFICATION_COPY)) {
      expect(body).not.toMatch(/\p{Extended_Pictographic}/u);
    }
  });
});
