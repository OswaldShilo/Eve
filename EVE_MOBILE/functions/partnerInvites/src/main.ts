import { callerId, readJsonBody, type FunctionContext } from '../../shared/src/appwrite.js';
import { serverDb } from '../../shared/src/db.js';
import { generateInviteCode, handleInviteRequest } from './invites.js';

export default async (context: FunctionContext) => {
  const result = await handleInviteRequest(
    { db: serverDb(context), now: () => new Date(), newCode: () => generateInviteCode() },
    callerId(context),
    readJsonBody(context),
  );
  return context.res.json(result.body, result.status);
};
