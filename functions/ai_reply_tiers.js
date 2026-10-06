/**
 * AI Reply Generation System - Tier Configurations
 * 
 * This module defines the three tiers of AI reply generation:
 * - Basic (1 coin): Uses API #1
 * - Smart (3 coins): Uses API #2
 * - Premium (6 coins): Uses API #3
 */

// TIER CONFIGURATION
const TIERS = {
  basic: {
    name: 'basic',
    cost: 1,
    apiKey: process.env.AICREDITS_API_KEY,
    baseUrl: 'https://api.aicredits.in/v1/chat/completions',
    model: 'openai/gpt-5-mini',
  },
  smart: {
    name: 'smart',
    cost: 3,
    // TODO: Configure Smart tier API credentials
    // apiKey: process.env.SMART_AI_API_KEY,
    // baseUrl: process.env.SMART_AI_BASE_URL,
    // model: process.env.SMART_AI_MODEL,
    apiKey: null,
    baseUrl: null,
    model: null,
  },
  premium: {
    name: 'premium',
    cost: 6,
    // TODO: Configure Premium tier API credentials
    // apiKey: process.env.PREMIUM_AI_API_KEY,
    // baseUrl: process.env.PREMIUM_AI_BASE_URL,
    // model: process.env.PREMIUM_AI_MODEL,
    apiKey: null,
    baseUrl: null,
    model: null,
  },
};

/**
 * Get tier configuration by name
 * @param {string} tierName - 'basic', 'smart', or 'premium'
 * @returns {object} Tier configuration
 */
function getTierConfig(tierName) {
  const tier = TIERS[tierName?.toLowerCase()];
  if (!tier) {
    throw new Error(`Unknown tier: ${tierName}`);
  }
  return tier;
}

/**
 * Validate that a tier is fully configured
 * @param {object} tier - Tier configuration
 * @returns {boolean} True if tier is configured
 */
function isTierConfigured(tier) {
  return tier.apiKey && tier.baseUrl && tier.model;
}

/**
 * Get the cost in coins for a tier
 * @param {string} tierName - 'basic', 'smart', or 'premium'
 * @returns {number} Cost in coins
 */
function getTierCost(tierName) {
  return getTierConfig(tierName).cost;
}

/**
 * Validate tier name
 * @param {string} tierName - 'basic', 'smart', or 'premium'
 * @returns {boolean} True if valid tier
 */
function isValidTier(tierName) {
  return tierName && ['basic', 'smart', 'premium'].includes(tierName?.toLowerCase());
}

module.exports = {
  TIERS,
  getTierConfig,
  isTierConfigured,
  getTierCost,
  isValidTier,
};
