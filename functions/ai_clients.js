/**
 * AI Client Module
 *
 * Handles API calls to AICredits for all AI reply tiers.
 *
 * The selected model comes from ai_reply_tiers.js:
 * - Basic   → GPT-4o-mini
 * - Smart   → DeepSeek V3.2
 * - Premium → GPT-5-mini
 */

const { HttpsError } = require('firebase-functions/v2/https');

const REQUEST_TIMEOUT_MS = 45000;
const MAX_RETRIES = 2;

async function callAI(tier, messages) {
  if (!tier || typeof tier !== 'object') {
    throw new HttpsError(
      'internal',
      'Invalid AI tier configuration.'
    );
  }

  if (!tier.apiKey) {
    throw new HttpsError(
      'failed-precondition',
      `${tier.name || 'AI'} tier is not configured.`
    );
  }

  if (!tier.baseUrl || !tier.model) {
    throw new HttpsError(
      'failed-precondition',
      `${tier.name || 'AI'} tier configuration is incomplete.`
    );
  }

  if (!Array.isArray(messages) || messages.length === 0) {
    throw new HttpsError(
      'invalid-argument',
      'AI messages are missing.'
    );
  }

  for (let attempt = 0; attempt <= MAX_RETRIES; attempt++) {
    try {
      const controller = new AbortController();

      const timeout = setTimeout(() => {
        controller.abort();
      }, REQUEST_TIMEOUT_MS);

      try {
        const response = await fetch(tier.baseUrl, {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${tier.apiKey}`,
            'Content-Type': 'application/json',
            Accept: 'application/json',
          },
          body: JSON.stringify({
            model: tier.model,
            messages,
            temperature: 0.7,
            max_tokens: 512,
            frequency_penalty: 0.2,
            presence_penalty: 0.0,
          }),
          signal: controller.signal,
        });

        const responseText = await response.text();

        let data = null;

        try {
          data = responseText
              ? JSON.parse(responseText)
              : null;
        } catch (_) {
          data = null;
        }

        // SUCCESS
        if (response.ok) {
          const content =
              data?.choices?.[0]?.message?.content;

          if (
            typeof content === 'string' &&
            content.trim().isNotEmpty
          ) {
            return content.trim();
          }

          throw new Error(
            'AI returned an empty response.'
          );
        }

        // RATE LIMIT
        if (response.status === 429) {
          if (attempt < MAX_RETRIES) {
            await sleep(800 * (attempt + 1));
            continue;
          }

          throw new HttpsError(
            'resource-exhausted',
            'Rate limit reached. Please try again later.'
          );
        }

        // INVALID API KEY
        if (response.status === 401) {
          throw new HttpsError(
            'failed-precondition',
            'AI API key is invalid or expired.'
          );
        }

        // PROVIDER BALANCE
        if (response.status === 402) {
          throw new HttpsError(
            'resource-exhausted',
            'AI provider balance is insufficient.'
          );
        }

        // MODEL NOT FOUND
        if (response.status === 404) {
          throw new HttpsError(
            'failed-precondition',
            `AI model is unavailable: ${tier.model}`
          );
        }

        // OTHER PROVIDER ERROR
        throw new HttpsError(
          'unavailable',
          'AI provider returned an error. Please try again.'
        );
      } finally {
        clearTimeout(timeout);
      }
    } catch (error) {
      if (error instanceof HttpsError) {
        throw error;
      }

      if (error?.name === 'AbortError') {
        throw new HttpsError(
          'deadline-exceeded',
          'AI request timed out. Please try again.'
        );
      }

      throw new HttpsError(
        'unavailable',
        'Unable to reach the AI provider. Please try again.'
      );
    }
  }

  throw new HttpsError(
    'unavailable',
    'Unable to reach AI provider.'
  );
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

module.exports = {
  callAI,
};