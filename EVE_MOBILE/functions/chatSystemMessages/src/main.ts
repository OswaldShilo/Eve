import { serverMessaging, type FunctionContext } from '../../shared/src/appwrite.js';
import { serverDb, type Row } from '../../shared/src/db.js';
import { appwriteMessenger } from '../../notifications/src/dispatch.js';
import { handleLogCreated } from './nudge.js';

// Event: tablesdb.eve.tables.symptom_logs.rows.*.create — payload is the new row.
export default async (context: FunctionContext) => {
  const row = context.req.bodyJson as Row | undefined;
  if (!row?.$id) return context.res.json({ ok: false }, 400);
  const nudged = await handleLogCreated(
    { db: serverDb(context), messenger: appwriteMessenger(serverMessaging(context)), now: () => new Date() },
    row,
  );
  context.log(`chatSystemMessages: log ${row.$id} ${nudged ? 'produced a partner nudge' : 'needed no nudge'}`);
  return context.res.json({ ok: true, nudged });
};
