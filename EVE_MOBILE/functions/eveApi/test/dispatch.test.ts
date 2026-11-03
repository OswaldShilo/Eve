import { describe, expect, it, vi } from 'vitest';
import { readJsonBody, type FunctionContext } from '../../shared/src/appwrite.js';
import { createApiHandler } from '../src/dispatch.js';

function context(body: unknown, asText = false) {
  return {
    req: {
      headers: { 'x-appwrite-user-id': 'u1' } as Record<string, string | undefined>,
      ...(asText ? { bodyText: JSON.stringify(body) } : { bodyJson: body }),
    },
    res: { json: (b: unknown, statusCode = 200) => ({ body: b, statusCode }) },
    log: vi.fn(),
    error: vi.fn(),
  } satisfies FunctionContext;
}

function routes() {
  const seen: Array<{ route: string; body: unknown; caller: string | undefined }> = [];
  const handler = (route: string) => async (ctx: FunctionContext) => {
    seen.push({ route, body: readJsonBody(ctx), caller: ctx.req.headers['x-appwrite-user-id'] });
    return ctx.res.json({ handledBy: route });
  };
  return {
    seen,
    handlers: {
      partnerInvites: handler('partnerInvites'),
      sendChatMessage: handler('sendChatMessage'),
      aiProxy: handler('aiProxy'),
    },
  };
}

describe('createApiHandler', () => {
  it('passes the body without `route` to the chosen handler, keeping the caller', async () => {
    const { seen, handlers } = routes();
    const result = await createApiHandler(handlers)(
      context({ route: 'partnerInvites', action: 'createInvite', relationshipType: 'husband' }),
    );

    expect(result).toEqual({ body: { handledBy: 'partnerInvites' }, statusCode: 200 });
    expect(seen).toEqual([
      { route: 'partnerInvites', body: { action: 'createInvite', relationshipType: 'husband' }, caller: 'u1' },
    ]);
  });

  it('routes a text body too', async () => {
    const { seen, handlers } = routes();
    await createApiHandler(handlers)(context({ route: 'aiProxy', feature: 'checkIn', message: 'hi' }, true));
    expect(seen).toEqual([{ route: 'aiProxy', body: { feature: 'checkIn', message: 'hi' }, caller: 'u1' }]);
  });

  it('rejects a missing, unknown or inherited route with 400 and runs nothing', async () => {
    const { seen, handlers } = routes();
    const handle = createApiHandler(handlers);
    for (const body of [{}, { route: 'onUserCreate' }, { route: 'toString' }, { route: 42 }, null]) {
      expect(await handle(context(body))).toEqual({ body: { error: 'Unknown request.' }, statusCode: 400 });
    }
    expect(seen).toEqual([]);
  });
});
