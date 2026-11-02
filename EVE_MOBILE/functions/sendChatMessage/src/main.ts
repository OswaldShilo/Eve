import { ID } from 'node-appwrite';
import { callerId, readJsonBody, type FunctionContext } from '../../shared/src/appwrite.js';
import { serverDb } from '../../shared/src/db.js';
import { handleSendRequest } from './send.js';

export default async (context: FunctionContext) => {
  const result = await handleSendRequest(
    { db: serverDb(context), now: () => new Date(), newId: () => ID.unique() },
    callerId(context),
    readJsonBody(context),
  );
  return context.res.json(result.body, result.status);
};
