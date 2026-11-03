import { describe, expect, it, vi } from 'vitest';
import type { FunctionContext } from '../../shared/src/appwrite.js';
import { createEventsHandler, jobsFor, type EventJob } from '../src/dispatch.js';

function context(headers: Record<string, string>) {
  return {
    req: { headers, bodyJson: { $id: 'u1' } },
    res: { json: (body: unknown, statusCode = 200) => ({ body, statusCode }) },
    log: vi.fn(),
    error: vi.fn(),
  } satisfies FunctionContext;
}

function jobs(failing: EventJob[] = []) {
  const ran: EventJob[] = [];
  const runner = (name: EventJob) => async () => {
    ran.push(name);
    if (failing.includes(name)) throw new Error(`${name} broke`);
  };
  return {
    ran,
    runners: {
      onUserCreate: runner('onUserCreate'),
      partnerView: runner('partnerView'),
      chatSystemMessages: runner('chatSystemMessages'),
      notifications: runner('notifications'),
    },
  };
}

describe('jobsFor', () => {
  it('routes a new user to onUserCreate', () => {
    expect(jobsFor('event', 'users.6ae97ed7969b2415ddb2.create')).toEqual(['onUserCreate']);
  });

  it('runs partnerView and chatSystemMessages for a new symptom log', () => {
    expect(jobsFor('event', 'tablesdb.eve.tables.symptom_logs.rows.r1.create')).toEqual([
      'partnerView',
      'chatSystemMessages',
    ]);
  });

  it('runs only partnerView for log updates/deletes and profile or permission updates', () => {
    for (const event of [
      'tablesdb.eve.tables.symptom_logs.rows.r1.update',
      'tablesdb.eve.tables.symptom_logs.rows.r1.delete',
      'tablesdb.eve.tables.life_stage_profiles.rows.u1.update',
      'tablesdb.eve.tables.partner_permissions.rows.u1.update',
    ]) {
      expect(jobsFor('event', event)).toEqual(['partnerView']);
    }
  });

  it('runs notifications on the schedule', () => {
    expect(jobsFor('schedule', null)).toEqual(['notifications']);
  });

  it('runs nothing for HTTP calls or unknown events', () => {
    expect(jobsFor('http', null)).toEqual([]);
    expect(jobsFor('http', 'users.u1.create')).toEqual([]);
    expect(jobsFor('event', null)).toEqual([]);
    expect(jobsFor('event', 'users.u1.sessions.s1.create')).toEqual([]);
    expect(jobsFor(null, null)).toEqual([]);
  });
});

describe('createEventsHandler', () => {
  it('runs the selected jobs with the execution context', async () => {
    const { ran, runners } = jobs();
    const spy = vi.spyOn(runners, 'onUserCreate');
    const handler = createEventsHandler(runners);
    const ctx = context({ 'x-appwrite-trigger': 'event', 'x-appwrite-event': 'users.u1.create' });

    expect(await handler(ctx)).toEqual({ body: { ok: true, ran: ['onUserCreate'], failed: [] }, statusCode: 200 });
    expect(ran).toEqual(['onUserCreate']);
    expect(spy).toHaveBeenCalledWith(ctx);
  });

  it('a failing job is logged, the next job still runs, and the execution reports 500', async () => {
    const { ran, runners } = jobs(['partnerView']);
    const ctx = context({ 'x-appwrite-trigger': 'event', 'x-appwrite-event': 'tablesdb.eve.tables.symptom_logs.rows.r1.create' });

    const result = await createEventsHandler(runners)(ctx);

    expect(ran).toEqual(['partnerView', 'chatSystemMessages']);
    expect(result).toEqual({
      body: { ok: false, ran: ['partnerView', 'chatSystemMessages'], failed: ['partnerView'] },
      statusCode: 500,
    });
    expect(ctx.error).toHaveBeenCalledWith(expect.stringContaining('partnerView failed'));
  });

  it('ignores a direct HTTP execution without running anything', async () => {
    const { ran, runners } = jobs();
    const result = await createEventsHandler(runners)(context({ 'x-appwrite-trigger': 'http' }));

    expect(ran).toEqual([]);
    expect(result).toEqual({ body: { ok: true, ignored: true }, statusCode: 200 });
  });
});
