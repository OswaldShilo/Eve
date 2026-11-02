import { Client, Messaging } from 'node-appwrite';

/** The subset of the Appwrite Functions runtime context EVE's functions use. */
export interface FunctionContext {
  req: {
    headers: Record<string, string | undefined>;
    method?: string;
    bodyJson?: unknown;
    bodyText?: string;
  };
  res: {
    json(body: unknown, statusCode?: number): unknown;
  };
  log(message: unknown): void;
  error(message: unknown): void;
}

/**
 * Server client authenticated with the execution's dynamic API key
 * (`x-appwrite-key`), scoped to the function's configured `scopes`.
 * APPWRITE_FUNCTION_API_ENDPOINT / _PROJECT_ID are injected by the runtime.
 * EVE_API_ENDPOINT overrides the endpoint: on self-hosted Docker the injected
 * one is http://localhost/v1, which a runtime container cannot reach, so the
 * local project sets it to http://host.docker.internal/v1. Unset on Cloud.
 */
export function serverClient(context: FunctionContext): Client {
  return new Client()
    .setEndpoint(process.env.EVE_API_ENDPOINT || process.env.APPWRITE_FUNCTION_API_ENDPOINT || '')
    .setProject(process.env.APPWRITE_FUNCTION_PROJECT_ID ?? '')
    .setKey(context.req.headers['x-appwrite-key'] ?? '');
}

export function serverMessaging(context: FunctionContext): Messaging {
  return new Messaging(serverClient(context));
}

/** The signed-in user who created this execution, or null (events, schedule, anonymous). */
export function callerId(context: FunctionContext): string | null {
  const id = context.req.headers['x-appwrite-user-id'];
  return id ? id : null;
}

export function readJsonBody<T = Record<string, unknown>>(context: FunctionContext): T | null {
  if (context.req.bodyJson !== undefined && context.req.bodyJson !== null && typeof context.req.bodyJson === 'object') {
    return context.req.bodyJson as T;
  }
  if (!context.req.bodyText) return null;
  try {
    return JSON.parse(context.req.bodyText) as T;
  } catch {
    return null;
  }
}

export function eventName(context: FunctionContext): string | null {
  return context.req.headers['x-appwrite-event'] ?? null;
}
