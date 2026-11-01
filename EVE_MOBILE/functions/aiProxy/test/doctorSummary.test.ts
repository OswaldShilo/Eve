import { describe, expect, it } from 'vitest';
import { buildDoctorSummaryPrompt, loadLogsForSummary } from '../src/doctorSummary.js';
import { handleAiRequest } from '../src/handle.js';
import type { AiPrompt, AiProvider } from '../src/providers.js';
import { ownerPermissions } from '../../shared/src/permissions.js';
import { MemoryDb } from '../../shared/test/memoryDb.js';

const NOW = new Date('2026-03-20T00:00:00.000Z');

describe('buildDoctorSummaryPrompt', () => {
  it('states plainly when there is no data', () => {
    expect(buildDoctorSummaryPrompt([])).toContain('No symptom or mood logs were recorded');
  });

  it('lists entries chronologically, marks missing fields, forbids diagnoses', () => {
    const prompt = buildDoctorSummaryPrompt([
      { date: '2026-03-04', symptoms: ['cramps'], mood: 'okay', painLevel: 4, notes: 'Felt tired.' },
      { date: '2026-03-02', symptoms: [], mood: null, painLevel: null, notes: '' },
    ]);
    expect(prompt.indexOf('2026-03-02')).toBeLessThan(prompt.indexOf('2026-03-04'));
    expect(prompt).toContain('Symptoms: cramps');
    expect(prompt).toContain('Symptoms: none reported');
    expect(prompt).toContain('Mood: not reported');
    expect(prompt).toContain('never state a diagnosis');
  });
});

describe('loadLogsForSummary', () => {
  it('returns only her owned logs inside the window', async () => {
    const db = new MemoryDb();
    await db.createRow('symptom_logs', 'a', { userId: 'u1', date: '2026-03-10T08:00:00.000Z', symptoms: ['cramps'], mood: 'low', painLevel: 5, notes: '' }, ownerPermissions('u1'));
    await db.createRow('symptom_logs', 'old', { userId: 'u1', date: '2025-10-01T08:00:00.000Z', symptoms: [], mood: null, painLevel: null, notes: '' }, ownerPermissions('u1'));
    await db.createRow('symptom_logs', 'forged', { userId: 'u1', date: '2026-03-11T08:00:00.000Z', symptoms: ['x'], mood: 'great', painLevel: 0, notes: '' }, ownerPermissions('attacker'));

    const logs = await loadLogsForSummary(db, 'u1', 90, NOW);
    expect(logs).toEqual([{ date: '2026-03-10', symptoms: ['cramps'], mood: 'low', painLevel: 5, notes: '' }]);
  });
});

describe('handleAiRequest doctorSummary', () => {
  it('builds the prompt from server-read logs and returns the summary', async () => {
    const db = new MemoryDb();
    await db.createRow('symptom_logs', 'a', { userId: 'u1', date: '2026-03-10T08:00:00.000Z', symptoms: ['cramps'], mood: 'low', painLevel: 5, notes: '' }, ownerPermissions('u1'));
    const seen: AiPrompt[] = [];
    const provider: AiProvider = {
      name: 'gemini',
      timeoutMs: 1000,
      async generate(prompt) {
        seen.push(prompt);
        return { text: 'Overview: cramps once.', provider: 'gemini', model: 'fake' };
      },
    };

    const result = await handleAiRequest({ providers: [provider], db, now: () => NOW }, 'u1', { feature: 'doctorSummary', days: 30 });

    expect(result).toEqual({ status: 200, body: { summary: 'Overview: cramps once.', provider: 'gemini', logCount: 1 } });
    expect(seen[0].user).toContain('Date: 2026-03-10');
  });
});
