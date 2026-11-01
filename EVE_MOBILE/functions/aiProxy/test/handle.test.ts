import { describe, expect, it } from 'vitest';
import { EVE_SYSTEM_PROMPT, handleAiRequest } from '../src/handle.js';
import type { AiPrompt, AiProvider } from '../src/providers.js';

function fakeProvider(reply: string, seen: AiPrompt[] = []): AiProvider {
  return {
    name: 'gemini',
    timeoutMs: 1000,
    async generate(prompt) {
      seen.push(prompt);
      return { text: reply, provider: 'gemini', model: 'fake' };
    },
  };
}

describe('handleAiRequest', () => {
  it('rejects anonymous callers', async () => {
    const result = await handleAiRequest({ providers: [fakeProvider('x')] }, null, { feature: 'ping' });
    expect(result.status).toBe(401);
  });

  it('ping reports configured providers without calling them', async () => {
    const seen: AiPrompt[] = [];
    const result = await handleAiRequest({ providers: [fakeProvider('x', seen)] }, 'u1', { feature: 'ping' });
    expect(result).toEqual({ status: 200, body: { ok: true, providers: ['gemini'] } });
    expect(seen).toHaveLength(0);
  });

  it('checkIn sends the Eve system prompt and returns the reply with its provider', async () => {
    const seen: AiPrompt[] = [];
    const result = await handleAiRequest({ providers: [fakeProvider('Thank you for sharing.', seen)] }, 'u1', {
      feature: 'checkIn',
      message: 'I slept badly.',
    });
    expect(result).toEqual({ status: 200, body: { reply: 'Thank you for sharing.', provider: 'gemini' } });
    expect(seen[0].system).toBe(EVE_SYSTEM_PROMPT);
    expect(seen[0].user).toBe('I slept badly.');
  });

  it('validates input and unknown features', async () => {
    expect((await handleAiRequest({ providers: [] }, 'u1', { feature: 'checkIn' })).status).toBe(400);
    expect((await handleAiRequest({ providers: [] }, 'u1', { feature: 'nope' })).status).toBe(400);
    expect((await handleAiRequest({ providers: [] }, 'u1', null)).status).toBe(400);
  });

  it('returns 503 when every provider fails', async () => {
    const failing: AiProvider = {
      name: 'gemini',
      timeoutMs: 1000,
      generate: async () => {
        throw new Error('down');
      },
    };
    const result = await handleAiRequest({ providers: [failing] }, 'u1', { feature: 'checkIn', message: 'hi' });
    expect(result.status).toBe(503);
  });

  it('the system prompt forbids diagnoses and emojis', () => {
    expect(EVE_SYSTEM_PROMPT).toContain('Never state or suggest a diagnosis');
    expect(EVE_SYSTEM_PROMPT).toContain('Do not use emojis');
  });
});
