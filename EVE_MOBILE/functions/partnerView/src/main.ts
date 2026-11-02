import { eventName, type FunctionContext } from '../../shared/src/appwrite.js';
import { serverDb, type Row } from '../../shared/src/db.js';
import { ownerForEvent, tableFromEvent } from './events.js';
import { recomputePartnerView } from './recompute.js';

export default async (context: FunctionContext) => {
  const tableId = tableFromEvent(eventName(context));
  const row = context.req.bodyJson as Row | undefined;
  const uid = tableId && row ? ownerForEvent(tableId, row) : null;
  if (!uid) {
    context.log(`partnerView: ignored ${eventName(context) ?? 'non-event execution'}`);
    return context.res.json({ ok: true, ignored: true });
  }
  const view = await recomputePartnerView(serverDb(context), uid, new Date());
  context.log(`partnerView: recomputed for ${uid}, showing [${view.approvedCategories.join(', ')}]`);
  return context.res.json({ ok: true });
};
