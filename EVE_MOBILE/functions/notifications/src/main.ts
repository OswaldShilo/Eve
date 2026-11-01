import { serverMessaging, type FunctionContext } from '../../shared/src/appwrite.js';
import { serverDb } from '../../shared/src/db.js';
import { appwriteMessenger, dispatchDueNotifications } from './dispatch.js';

// Schedule: */30 * * * * (UTC).
export default async (context: FunctionContext) => {
  const sent = await dispatchDueNotifications(
    serverDb(context),
    appwriteMessenger(serverMessaging(context)),
    new Date(),
    (m) => context.log(m),
  );
  context.log(`notifications: sent ${sent} push message(s)`);
  return context.res.json({ sent });
};
