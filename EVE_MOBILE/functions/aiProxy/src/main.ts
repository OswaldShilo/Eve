import { callerId, readJsonBody, type FunctionContext } from '../../shared/src/appwrite.js';
import { handleAiRequest } from './handle.js';
import { providersFromEnv } from './providers.js';

export default async (context: FunctionContext) => {
  const result = await handleAiRequest(
    { providers: providersFromEnv(process.env), log: (m) => context.log(m) },
    callerId(context),
    readJsonBody(context),
  );
  return context.res.json(result.body, result.status);
};
