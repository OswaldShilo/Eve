import type { Db } from '../../shared/src/db.js';
import { TABLES } from '../../shared/src/ids.js';
import { isOwnedBy } from '../../shared/src/permissions.js';

export interface DoctorSummaryLogEntry {
  date: string; // YYYY-MM-DD
  symptoms: string[];
  mood: string | null;
  painLevel: number | null;
  notes: string;
}

export const DOCTOR_SUMMARY_SYSTEM_PROMPT =
  "You write factual clinical summaries of a patient's self-reported symptom and mood log for her doctor. " +
  'Use only the data given, never invent values, never state a diagnosis, and close by recommending she discuss these patterns with her doctor. Do not use emojis.';

export function buildDoctorSummaryPrompt(logs: DoctorSummaryLogEntry[]): string {
  if (logs.length === 0) {
    return 'No symptom or mood logs were recorded in the selected period. State this plainly and do not fabricate any data.';
  }
  const lines = [...logs]
    .sort((a, b) => a.date.localeCompare(b.date))
    .map((log) => {
      const parts = [
        `Date: ${log.date}`,
        `Symptoms: ${log.symptoms.length > 0 ? log.symptoms.join(', ') : 'none reported'}`,
        `Mood: ${log.mood ?? 'not reported'}`,
        `Pain level (0-10): ${log.painLevel ?? 'not reported'}`,
      ];
      if (log.notes.trim()) parts.push(`Notes: ${log.notes.trim()}`);
      return parts.join(' | ');
    });
  return [
    'Rules: use only the data below, never invent symptoms or values, never state a diagnosis, and close with a line recommending she discuss these patterns with her doctor.',
    'Format: a short overview paragraph, then a "Notable patterns" section, then a "Log entries" section listing each date.',
    '',
    `Log entries (${logs.length} total):`,
    ...lines,
  ].join('\n');
}

export async function loadLogsForSummary(db: Db, uid: string, days: number, now: Date): Promise<DoctorSummaryLogEntry[]> {
  const since = now.getTime() - days * 24 * 60 * 60 * 1000;
  const rows = await db.listRows(TABLES.symptomLogs, {
    equal: { userId: uid },
    orderBy: { column: 'date', direction: 'asc' },
    limit: 1000,
  });
  return rows
    .filter((row) => isOwnedBy(row, uid) && Date.parse(String(row.date)) >= since)
    .map((row) => ({
      date: String(row.date).slice(0, 10),
      symptoms: (row.symptoms as string[] | null) ?? [],
      mood: (row.mood as string | null) ?? null,
      painLevel: (row.painLevel as number | null) ?? null,
      notes: (row.notes as string | null) ?? '',
    }));
}
