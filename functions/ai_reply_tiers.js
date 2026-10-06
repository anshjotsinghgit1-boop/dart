/**
 * AI Reply Generation System - Tier Configurations
 *
 * Basic   = 1 coin  → GPT-4o-mini
 * Smart   = 3 coins → DeepSeek V3.2
 * Premium = 6 coins → GPT-5-mini
 *
 * All three use the AICredits OpenAI-compatible API.
 */

const AICREDITS_BASE_URL =
  'https://api.aicredits.in/v1/chat/completions';

const TIER_MODELS = {
  basic: {
    name: 'basic',
    cost: 1,
    model: 'openai/gpt-4o-mini',
  },

  smart: {
    name: 'smart',
    cost: 3,
    model: 'deepseek/deepseek-v3.2',
  },

  premium: {
    name: 'premium',
    cost: 6,
    model: 'gpt-5-mini',
  },
};

/**
 * Get the API key at runtime.
 *
 * Firebase injects AICREDITS_API_KEY into the
 * function environment when generateReply runs.
 */
function getApiKey() {
  return process.env.AICREDITS_API_KEY || null;
}

/**
 * Get tier configuration by name.
 */
function getTierConfig(tierName) {
  const normalizedTier =
    tierName?.toLowerCase();

  const tier =
    TIER_MODELS[normalizedTier];

  if (!tier) {
    throw new Error(
      `Unknown tier: ${tierName}`
    );
  }

  return {
    ...tier,
    apiKey: getApiKey(),
    baseUrl: AICREDITS_BASE_URL,
  };
}

/**
 * Check whether the tier has everything required
 * to make an AI request.
 */
function isTierConfigured(tier) {
  return Boolean(
    tier &&
    tier.apiKey &&
    tier.baseUrl &&
    tier.model
  );
}

/**
 * Get the coin cost of a tier.
 */
function getTierCost(tierName) {
  return getTierConfig(tierName).cost;
}

/**
 * Check whether a tier name is valid.
 */
function isValidTier(tierName) {
  const normalizedTier =
    tierName?.toLowerCase();

  return [
    'basic',
    'smart',
    'premium',
  ].includes(normalizedTier);
}

module.exports = {
  TIER_MODELS,
  getTierConfig,
  isTierConfigured,
  getTierCost,
  isValidTier,
};