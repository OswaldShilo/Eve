import { AllProvidersFailedError, generateWithFallback, type AiProvider } from './providers.js';

export const EVE_SYSTEM_PROMPT = [
  'You are Eve, a warm and formal health companion inside the EVE app for women.',
  'Reply in two to four short sentences. Do not use emojis.',
  'Never state or suggest a diagnosis. When something sounds medically concerning, recommend discussing it with a healthcare professional.',
  'Do not invent facts about the user beyond what she tells you.',
].join(' ');

export interface AiDeps {
  providers: AiProvider[];
  log?: (message: string) => void;
}

export interface AiResponse {
  status: number;
  body: Record<string, unknown>;
}

const MAX_MESSAGE_LENGTH = 2000;

export async function handleAiRequest(deps: AiDeps, uid: string | null, body: Record<string, unknown> | null): Promise<AiResponse> {
  if (!uid) return { status: 401, body: { error: 'Sign in required to use the AI assistant.' } };
  if (!body || typeof body.feature !== 'string') return { status: 400, body: { error: 'Missing "feature".' } };

  try {
    switch (body.feature) {
      case 'ping':
        return { status: 200, body: { ok: true, providers: deps.providers.map((p) => p.name) } };
      case 'checkIn': {
        const message = typeof body.message === 'string' ? body.message.trim() : '';
        if (!message || message.length > MAX_MESSAGE_LENGTH) {
          return { status: 400, body: { error: 'checkIn requires a "message" of 1-2000 characters.' } };
        }
        const result = await generateWithFallback(
          deps.providers,
          { system: EVE_SYSTEM_PROMPT, user: message, maxOutputTokens: 300 },
          deps.log,
        );
        return { status: 200, body: { reply: result.text, provider: result.provider } };
      }
      default:
        return { status: 400, body: { error: `Unknown feature "${body.feature}".` } };
    }
  } catch (e) {
    if (e instanceof AllProvidersFailedError) {
      deps.log?.(e.message);
      return { status: 503, body: { error: 'The assistant is unavailable right now. Please try again shortly.' } };
    }
    throw e;
  }
}
