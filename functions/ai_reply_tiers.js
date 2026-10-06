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

const AICREDITS_API_KEY =
  process.env.AICREDITS_API_KEY;

const TIERS = {
  basic: {
    name: 'basic',
    cost: 1,
    apiKey: AICREDITS_API_KEY,
    baseUrl: AICREDITS_BASE_URL,
    model: 'openai/gpt-4o-mini',
  },

  smart: {
    name: 'smart',
    cost: 3,
    apiKey: AICREDITS_API_KEY,
    baseUrl: AICREDITS_BASE_URL,
    model: 'deepseek/deepseek-v3.2',
  },

  premium: {
    name: 'premium',
    cost: 6,
    apiKey: AICREDITS_API_KEY,
    baseUrl: AICREDITS_BASE_URL,
    model: 'gpt-5-mini',
  },
};

/**
 * Get tier configuration by name.
 */
function getTierConfig(tierName) {
  const normalizedTier = tierName?.toLowerCase();

  const tier = TIERS[normalizedTier];

  if (!tier) {
    throw new Error(`Unknown tier: ${tierName}`);
  }

  return tier;
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
  const normalizedTier = tierName?.toLowerCase();

  return [
    'basic',
    'smart',
    'premium',
  ].includes(normalizedTier);
}

module.exports = {
  TIERS,
  getTierConfig,
  isTierConfigured,
  getTierCost,
  isValidTier,
};