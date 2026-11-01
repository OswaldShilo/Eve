import { describe, expect, it } from 'vitest';
import {
  AllProvidersFailedError,
  generateWithFallback,
  geminiProvider,
  openRouterProvider,
  providersFromEnv,
  type AiPrompt,
} from '../src/providers.js';

const prompt: AiPrompt = { system: 'Be warm.', user: 'Hello', maxOutputTokens: 200 };

type FetchArgs = [string, RequestInit];
function jsonResponse(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), { status, headers: { 'content-type': 'application/json' } });
}
function recordingFetch(responses: Response[]) {
  const calls: FetchArgs[] = [];
  const fn = async (url: string | URL | Request, init?: RequestInit) => {
    calls.push([String(url), init ?? {}]);
    const next = responses.shift();
    if (!next) throw new Error('no more responses');
    return next;
  };
  return { fn: fn as typeof fetch, calls };
}
const hangingFetch = ((_: unknown, init?: RequestInit) =>
  new Promise<Response>((_resolve, reject) => {
    init?.signal?.addEventListener('abort', () => reject(init.signal?.reason));
  })) as typeof fetch;

const geminiOk = { candidates: [{ content: { parts: [{ text: 'Hi from ' }, { text: 'Gemini' }] } }] };
const openRouterOk = { model: 'meta-llama/x:free', choices: [{ message: { role: 'assistant', content: 'Hi from OpenRouter' } }] };

describe('geminiProvider', () => {
  it('posts generateContent with the key header, system instruction and token limit', async () => {
    const { fn, calls } = recordingFetch([jsonResponse(200, geminiOk)]);
    const result = await geminiProvider({ apiKey: 'g-key', model: 'gemini-test', fetchFn: fn }).generate(
      prompt,
      AbortSignal.timeout(1000),
    );

    expect(result).toEqual({ text: 'Hi from Gemini', provider: 'gemini', model: 'gemini-test' });
    const [url, init] = calls[0];
    expect(url).toBe('https://generativelanguage.googleapis.com/v1beta/models/gemini-test:generateContent');
    expect((init.headers as Record<string, string>)['x-goog-api-key']).toBe('g-key');
    const body = JSON.parse(String(init.body));
    expect(body.systemInstruction.parts[0].text).toBe('Be warm.');
    expect(body.contents[0].parts[0].text).toBe('Hello');
    expect(body.generationConfig.maxOutputTokens).toBe(200);
  });
});

describe('openRouterProvider', () => {
  it('posts chat completions with bearer auth and the models fallback list', async () => {
    const { fn, calls } = recordingFetch([jsonResponse(200, openRouterOk)]);
    const result = await openRouterProvider({
      apiKey: 'or-key',
      models: ['a/b:free', 'c/d:free'],
      fetchFn: fn,
    }).generate(prompt, AbortSignal.timeout(1000));

    expect(result).toEqual({ text: 'Hi from OpenRouter', provider: 'openrouter', model: 'meta-llama/x:free' });
    const [url, init] = calls[0];
    expect(url).toBe('https://openrouter.ai/api/v1/chat/completions');
    expect((init.headers as Record<string, string>).Authorization).toBe('Bearer or-key');
    const body = JSON.parse(String(init.body));
    expect(body.models).toEqual(['a/b:free', 'c/d:free']);
    expect(body.messages).toEqual([
      { role: 'system', content: 'Be warm.' },
      { role: 'user', content: 'Hello' },
    ]);
    expect(body.max_tokens).toBe(200);
  });
});

describe('generateWithFallback', () => {
  it('uses Gemini when it succeeds and never calls OpenRouter', async () => {
    const gemini = recordingFetch([jsonResponse(200, geminiOk)]);
    const openRouter = recordingFetch([]);
    const result = await generateWithFallback(
      [
        geminiProvider({ apiKey: 'g', model: 'm', fetchFn: gemini.fn }),
        openRouterProvider({ apiKey: 'o', models: ['x:free'], fetchFn: openRouter.fn }),
      ],
      prompt,
    );
    expect(result.provider).toBe('gemini');
    expect(openRouter.calls).toHaveLength(0);
  });

  it.each([
    ['429 rate limit', () => jsonResponse(429, { error: { message: 'quota' } })],
    ['500 server error', () => jsonResponse(500, { error: { message: 'boom' } })],
    ['empty candidates', () => jsonResponse(200, { candidates: [] })],
  ])('falls back to OpenRouter on Gemini %s', async (_label, failure) => {
    const gemini = recordingFetch([failure()]);
    const openRouter = recordingFetch([jsonResponse(200, openRouterOk)]);
    const result = await generateWithFallback(
      [
        geminiProvider({ apiKey: 'g', model: 'm', fetchFn: gemini.fn }),
        openRouterProvider({ apiKey: 'o', models: ['x:free'], fetchFn: openRouter.fn }),
      ],
      prompt,
    );
    expect(result.provider).toBe('openrouter');
  });

  it('falls back when Gemini exceeds its timeout', async () => {
    const openRouter = recordingFetch([jsonResponse(200, openRouterOk)]);
    const result = await generateWithFallback(
      [
        geminiProvider({ apiKey: 'g', model: 'm', fetchFn: hangingFetch, timeoutMs: 20 }),
        openRouterProvider({ apiKey: 'o', models: ['x:free'], fetchFn: openRouter.fn }),
      ],
      prompt,
    );
    expect(result.provider).toBe('openrouter');
  });

  it('throws AllProvidersFailedError listing each failure, without leaking keys', async () => {
    const gemini = recordingFetch([jsonResponse(429, {})]);
    const openRouter = recordingFetch([jsonResponse(503, {})]);
    const error = await generateWithFallback(
      [
        geminiProvider({ apiKey: 'secret-g', model: 'm', fetchFn: gemini.fn }),
        openRouterProvider({ apiKey: 'secret-o', models: ['x:free'], fetchFn: openRouter.fn }),
      ],
      prompt,
    ).catch((e) => e);
    expect(error).toBeInstanceOf(AllProvidersFailedError);
    expect(error.message).toContain('gemini: HTTP 429');
    expect(error.message).toContain('openrouter: HTTP 503');
    expect(error.message).not.toContain('secret');
  });
});

describe('providersFromEnv', () => {
  it('orders Gemini first and skips providers without keys', () => {
    expect(
      providersFromEnv({ GEMINI_API_KEY: 'g', GEMINI_MODEL: 'gm', OPENROUTER_API_KEY: 'o', OPENROUTER_MODELS: 'a:free, b:free' }).map(
        (p) => p.name,
      ),
    ).toEqual(['gemini', 'openrouter']);
    expect(providersFromEnv({ OPENROUTER_API_KEY: 'o', OPENROUTER_MODELS: 'a:free' }).map((p) => p.name)).toEqual([
      'openrouter',
    ]);
    expect(providersFromEnv({ OPENROUTER_API_KEY: 'o' }).map((p) => p.name)).toEqual([]);
  });
});
