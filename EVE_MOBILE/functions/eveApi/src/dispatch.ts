import { readJsonBody, type FunctionContext } from '../../shared/src/appwrite.js';
import { API_ROUTES, type ApiRoute } from '../../shared/src/ids.js';

export type RouteHandler = (context: FunctionContext) => Promise<unknown>;

/**
 * The free Cloud plan allows two functions, so every call the app makes
 * goes to this one. The body's `route` picks the handler (the unchanged
 * default export of the original function); the handler sees the body
 * without `route`, exactly as when it was its own function.
 */
export function createApiHandler(routes: Record<ApiRoute, RouteHandler>) {
  return async (context: FunctionContext) => {
    const body = readJsonBody(context);
    const route = body?.route;
    if (typeof route !== 'string' || !(Object.values(API_ROUTES) as string[]).includes(route)) {
      return context.res.json({ error: 'Unknown request.' }, 400);
    }
    const { route: _route, ...rest } = body as Record<string, unknown>;
    return routes[route as ApiRoute]({ ...context, req: { ...context.req, bodyJson: rest, bodyText: JSON.stringify(rest) } });
  };
}
