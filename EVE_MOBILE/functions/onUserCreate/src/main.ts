import type { FunctionContext } from '../../shared/src/appwrite.js';
import { serverDb } from '../../shared/src/db.js';
import { initializeUserRows } from './initializeUser.js';

// Event: users.*.create — the payload is the new user object.
export default async (context: FunctionContext) => {
  const user = context.req.bodyJson as { $id?: string; name?: string } | undefined;
  if (!user?.$id) {
    context.error('onUserCreate: event payload has no user $id');
    return context.res.json({ ok: false }, 400);
  }
  const created = await initializeUserRows(serverDb(context), user.$id, user.name ?? '');
  context.log(`onUserCreate ${user.$id}: created ${created.join(', ') || 'nothing (already initialized)'}`);
  return context.res.json({ ok: true, created });
};
