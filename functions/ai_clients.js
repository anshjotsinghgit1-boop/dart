/**
 * AI Client Module
 *
 * Handles API calls to AI providers for reply generation.
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
          data = responseText ? JSON.parse(responseText) : null;
        } catch (_) {
          data = null;
        }

        // SUCCESS
        if (response.status === 200) {
          const content = data?.choices?.[0]?.message?.content;

          if (
            typeof content === 'string' &&
            content.trim().length > 0
          ) {
            return content.trim();
          }

          throw new Error('AI returned an empty response.');
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

        // INSUFFICIENT PROVIDER CREDITS
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
            `AI model not found: ${tier.model}`
          );
        }

        // OTHER API ERROR
        const providerMessage =
          data?.error?.message ||
          `AI provider returned HTTP ${response.status}.`;

        throw new Error(providerMessage);
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
          'AI request timed out after 45 seconds.'
        );
      }

      throw new HttpsError(
        'unavailable',
        error?.message || 'Unable to reach AI provider.'
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