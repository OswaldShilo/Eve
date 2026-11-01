import { afterEach, describe, expect, it } from 'vitest';
import { callerId, eventName, readJsonBody, serverClient, type FunctionContext } from '../src/appwrite.js';

function context(headers: Record<string, string>, body: { bodyJson?: unknown; bodyText?: string } = {}): FunctionContext {
  return {
    req: { headers, method: 'POST', ...body },
    res: { json: (b: unknown, status = 200) => ({ b, status }) },
    log: () => undefined,
    error: () => undefined,
  };
}

describe('execution helpers', () => {
  it('reads the caller from x-appwrite-user-id and treats empty as anonymous', () => {
    expect(callerId(context({ 'x-appwrite-user-id': 'u1' }))).toBe('u1');
    expect(callerId(context({ 'x-appwrite-user-id': '' }))).toBeNull();
    expect(callerId(context({}))).toBeNull();
  });

  it('parses the JSON body from bodyJson or bodyText, null when invalid', () => {
    expect(readJsonBody(context({}, { bodyJson: { feature: 'ping' } }))).toEqual({ feature: 'ping' });
    expect(readJsonBody(context({}, { bodyText: '{"feature":"ping"}' }))).toEqual({ feature: 'ping' });
    expect(readJsonBody(context({}, { bodyText: 'not json' }))).toBeNull();
  });

  it('exposes the triggering event name', () => {
    expect(eventName(context({ 'x-appwrite-event': 'users.u1.create' }))).toBe('users.u1.create');
    expect(eventName(context({}))).toBeNull();
  });
});

describe('serverClient endpoint', () => {
  afterEach(() => {
    delete process.env.EVE_API_ENDPOINT;
    delete process.env.APPWRITE_FUNCTION_API_ENDPOINT;
  });

  it('uses the runtime-injected endpoint by default', () => {
    process.env.APPWRITE_FUNCTION_API_ENDPOINT = 'http://localhost/v1';
    expect(serverClient(context({})).config.endpoint).toBe('http://localhost/v1');
  });

  it('prefers EVE_API_ENDPOINT (local Docker: the runtime cannot reach localhost)', () => {
    process.env.APPWRITE_FUNCTION_API_ENDPOINT = 'http://localhost/v1';
    process.env.EVE_API_ENDPOINT = 'http://host.docker.internal/v1';
    expect(serverClient(context({})).config.endpoint).toBe('http://host.docker.internal/v1');
  });
});
