import type { FunctionContext } from '../../shared/src/appwrite.js';
import { TABLES } from '../../shared/src/ids.js';
import { tableFromEvent } from '../../partnerView/src/events.js';

/**
 * The free Cloud plan allows two functions, so every event- and
 * schedule-driven job runs inside this one function. Each job is the
 * unchanged default export of its original function.
 */
export type EventJob = 'onUserCreate' | 'partnerView' | 'chatSystemMessages' | 'notifications';

export type JobRunner = (context: FunctionContext) => Promise<unknown>;

/** Which jobs an execution runs, from `x-appwrite-trigger` and `x-appwrite-event`. */
export function jobsFor(trigger: string | null, event: string | null): EventJob[] {
  if (trigger === 'schedule') return ['notifications'];
  if (trigger !== 'event' || !event) return [];
  if (/^users\.[^.]+\.create$/.test(event)) return ['onUserCreate'];
  const tableId = tableFromEvent(event);
  if (!tableId) return [];
  const jobs: EventJob[] = ['partnerView'];
  if (tableId === TABLES.symptomLogs && event.endsWith('.create')) jobs.push('chatSystemMessages');
  return jobs;
}

/**
 * Runs every job for this execution in order. A failing job is logged and
 * does not stop the next one; the execution then reports 500.
 */
export function createEventsHandler(jobs: Record<EventJob, JobRunner>) {
  return async (context: FunctionContext) => {
    const trigger = context.req.headers['x-appwrite-trigger'] ?? null;
    const event = context.req.headers['x-appwrite-event'] ?? null;
    const selected = jobsFor(trigger, event);
    if (selected.length === 0) {
      context.log(`eveEvents: ignored ${trigger ?? 'unknown'} trigger ${event ?? ''}`.trim());
      return context.res.json({ ok: true, ignored: true });
    }
    const failed: EventJob[] = [];
    for (const job of selected) {
      try {
        await jobs[job](context);
      } catch (e) {
        failed.push(job);
        context.error(`eveEvents: ${job} failed: ${e instanceof Error ? (e.stack ?? e.message) : String(e)}`);
      }
    }
    return context.res.json({ ok: failed.length === 0, ran: selected, failed }, failed.length === 0 ? 200 : 500);
  };
}
