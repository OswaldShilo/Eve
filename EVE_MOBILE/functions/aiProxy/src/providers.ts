export interface AiPrompt {
  system: string;
  user: string;
  maxOutputTokens: number;
}

export interface AiResult {
  text: string;
  provider: 'gemini' | 'openrouter';
  model: string;
}

export interface AiProvider {
  readonly name: AiResult['provider'];
  readonly timeoutMs: number;
  generate(prompt: AiPrompt, signal: AbortSignal): Promise<AiResult>;
}

export class ProviderError extends Error {
  constructor(message: string, readonly status?: number) {
    super(message);
  }
}

export class AllProvidersFailedError extends Error {}

type FetchFn = typeof fetch;

async function postJson(fetchFn: FetchFn, url: string, headers: Record<string, string>, body: unknown, signal: AbortSignal) {
  const response = await fetchFn(url, {
    method: 'POST',
    headers: { 'content-type': 'application/json', ...headers },
    body: JSON.stringify(body),
    signal,
  });
  if (!response.ok) throw new ProviderError(`HTTP ${response.status}`, response.status);
  return (await response.json()) as unknown;
}

export function geminiProvider(opts: { apiKey: string; model: string; fetchFn?: FetchFn; timeoutMs?: number }): AiProvider {
  const fetchFn = opts.fetchFn ?? fetch;
  return {
    name: 'gemini',
    timeoutMs: opts.timeoutMs ?? 12_000,
    async generate(prompt, signal) {
      const json = (await postJson(
        fetchFn,
        `https://generativelanguage.googleapis.com/v1beta/models/${opts.model}:generateContent`,
        { 'x-goog-api-key': opts.apiKey },
        {
          systemInstruction: { parts: [{ text: prompt.system }] },
          contents: [{ role: 'user', parts: [{ text: prompt.user }] }],
          generationConfig: { maxOutputTokens: prompt.maxOutputTokens },
        },
        signal,
      )) as { candidates?: { content?: { parts?: { text?: string }[] } }[] };
      const text = (json.candidates?.[0]?.content?.parts ?? []).map((part) => part.text ?? '').join('').trim();
      if (!text) throw new ProviderError('empty response');
      return { text, provider: 'gemini', model: opts.model };
    },
  };
}

export function openRouterProvider(opts: {
  apiKey: string;
  models: string[];
  fetchFn?: FetchFn;
  timeoutMs?: number;
}): AiProvider {
  const fetchFn = opts.fetchFn ?? fetch;
  return {
    name: 'openrouter',
    timeoutMs: opts.timeoutMs ?? 15_000,
    async generate(prompt, signal) {
      const json = (await postJson(
        fetchFn,
        'https://openrouter.ai/api/v1/chat/completions',
        { Authorization: `Bearer ${opts.apiKey}`, 'X-Title': 'EVE' },
        {
          models: opts.models,
          messages: [
            { role: 'system', content: prompt.system },
            { role: 'user', content: prompt.user },
          ],
          max_tokens: prompt.maxOutputTokens,
        },
        signal,
      )) as { model?: string; choices?: { message?: { content?: string } }[] };
      const text = (json.choices?.[0]?.message?.content ?? '').trim();
      if (!text) throw new ProviderError('empty response');
      return { text, provider: 'openrouter', model: json.model ?? opts.models[0] };
    },
  };
}

/** Tries each provider in order with its own timeout; first non-empty answer wins. */
export async function generateWithFallback(
  providers: AiProvider[],
  prompt: AiPrompt,
  log: (message: string) => void = () => undefined,
): Promise<AiResult> {
  const failures: string[] = [];
  for (const provider of providers) {
    try {
      return await provider.generate(prompt, AbortSignal.timeout(provider.timeoutMs));
    } catch (e) {
      const reason =
        e instanceof ProviderError
          ? e.message
          : e instanceof Error && (e.name === 'TimeoutError' || e.name === 'AbortError')
            ? `timeout after ${provider.timeoutMs}ms`
            : 'network error';
      failures.push(`${provider.name}: ${reason}`);
      log(`aiProxy: ${provider.name} failed (${reason}), trying next provider`);
    }
  }
  throw new AllProvidersFailedError(`All AI providers failed — ${failures.join('; ') || 'none configured'}`);
}

/** Gemini first (when keyed), then OpenRouter (when keyed and models are listed). */
export function providersFromEnv(env: Record<string, string | undefined>, fetchFn?: FetchFn): AiProvider[] {
  const providers: AiProvider[] = [];
  if (env.GEMINI_API_KEY) {
    providers.push(geminiProvider({ apiKey: env.GEMINI_API_KEY, model: env.GEMINI_MODEL || 'gemini-3.8-flash', fetchFn }));
  }
  const models = (env.OPENROUTER_MODELS ?? '')
    .split(',')
    .map((m) => m.trim())
    .filter(Boolean);
  if (env.OPENROUTER_API_KEY && models.length > 0) {
    providers.push(openRouterProvider({ apiKey: env.OPENROUTER_API_KEY, models, fetchFn }));
  }
  return providers;
}
