const fs = require('node:fs');
const path = require('node:path');

const PROMPTS_DIR = path.join(__dirname, 'prompts');
const NORMAL_PROMPT_PATH = path.join(PROMPTS_DIR, 'normal.txt');
const PREMIUM_PROMPT_PATH = path.join(PROMPTS_DIR, 'premium.txt');

function isHinglish(message) {
  const original = String(message ?? '');
  const text = original.toLowerCase();
  const strongWords = new Set([
    'hai', 'hain', 'ho', 'hoga', 'hogi', 'tha', 'thi', 'mujhe', 'tumhe', 'tumko',
    'mere', 'mera', 'meri', 'tere', 'tera', 'teri', 'tum', 'aap', 'apka', 'apni', 'kya',
    'kyu', 'kyun', 'kaise', 'kaisa', 'kaisi', 'acha', 'accha', 'achha', 'haan', 'nahi',
    'nhi', 'nah', 'mat', 'kar', 'karo', 'kr', 'karti', 'karta', 'karna', 'gayi', 'gaya',
    'jaa', 'ja', 'raha', 'rahi', 'rhe', 'hoon', 'hu', 'bhi', 'toh', 'bas', 'abhi',
    'phir', 'fir', 'kyunki', 'pata', 'lagta', 'lagti', 'sach', 'pagal', 'yaar', 'bhai',
    'bacha', 'jaan', 'pyaar', 'acchi', 'sundar', 'milna',
    'baat', 'baatein', 'bol', 'bata', 'bta', 'dekh', 'dekho', 'sun', 'suno', 'kuch'
  ]);
  const words = text.replace(/[^a-zA-Z0-9\u0900-\u097F\s]/g, ' ').split(/\s+/).filter(Boolean);
  if (/[\u0900-\u097F]/.test(original) || words.some(word => strongWords.has(word))) return true;
  return false;
}

function detectInputLanguage(message) {
  const original = String(message ?? '');
  if (/[\u0900-\u097F]/.test(original)) return 'hindi';
  if (isHinglish(original)) return 'hinglish';
  return 'english';
}

function getMoodRules(mood) {
  const moodLower = String(mood || 'natural').trim().toLowerCase();
  const moodMap = {
    flirty: 'MOOD: FLIRTY\nBe playful, confident, witty, and naturally charming. Use teasing, subtext, or a clever double meaning when it fits the message. Avoid generic pickup lines, forced slang, and crude language. Do not automatically deflect a flirtatious message; respond to its actual vibe while staying respectful.',
    romantic: 'MOOD: ROMANTIC\nBe warm, sincere, and emotionally attentive. Use specific, understated affection rather than grand declarations or clichés. Match the closeness of the conversation and never invent feelings or shared history.',
    funny: 'MOOD: FUNNY\nFind a fresh, context-specific joke, playful reversal, or dry observation. Keep the timing natural; do not force a punchline into serious messages.',
    savage: 'MOOD: SAVAGE\nBe sharp, self-assured, and witty. Use a clever comeback rather than generic insults. Keep it playful rather than cruel, hateful, or humiliating.',
    sweet: 'MOOD: SWEET\nBe gentle, thoughtful, and genuinely kind. Keep affection believable and specific; do not overdo romance without context.',
    sad: 'MOOD: SAD\nBe emotionally honest, calm, and understated. Avoid melodrama, guilt-tripping, or turning the reply into a performance.',
    confident: 'MOOD: CONFIDENT\nSound self-assured and relaxed. Use clear, direct wording without arrogance, desperation, or unnecessary aggression.',
    cute: 'MOOD: CUTE\nBe endearing, playful, and lightly teasing. Keep it natural rather than childish or overloaded with emojis.',
    natural: 'MOOD: NATURAL\nRespond to the situation in a relaxed, human way. Let the message determine the tone instead of forcing a personality.'
  };
  return moodMap[moodLower] || moodMap.natural;
}

function getNormalModePrompt(mode) {
  const source = fs.readFileSync(NORMAL_PROMPT_PATH, 'utf8');
  const tag = mode.toUpperCase();
  const startTag = `[[${tag}]]`;
  const endTag = `[[/${tag}]]`;
  const start = source.indexOf(startTag);
  const end = start < 0 ? -1 : source.indexOf(endTag, start + startTag.length);
  if (start < 0 || end < 0) {
    throw new Error(`Missing ${mode} section in prompts/normal.txt`);
  }
  const prompt = source.slice(start + startTag.length, end).trim();
  if (!prompt) throw new Error(`The ${mode} prompt section is empty.`);
  return prompt;
}

function getSystemPrompt(mood, hinglish, tier = 'basic') {
  const selectedTier = String(tier || 'basic').trim().toLowerCase();
  const selectedMood = String(mood || 'natural').trim().toLowerCase();

  if (!['basic', 'smart', 'premium'].includes(selectedTier)) {
    throw new Error(`Invalid AI tier: ${selectedTier}`);
  }

  if (selectedTier === 'premium') {
    if (!['flirty', 'romantic'].includes(selectedMood)) {
      throw new Error('Premium mode is available only with flirty or romantic mood.');
    }
    const premiumPrompt = fs.readFileSync(PREMIUM_PROMPT_PATH, 'utf8').trim();
    if (!premiumPrompt) throw new Error('The Premium prompt file is empty.');
    return [
      premiumPrompt,
      getMoodRules(selectedMood),
      'LANGUAGE: Generate the reply in English only. The input has already been translated to English. Do not switch languages.',
    ].join('\n\n');
  }

  const languageRule = hinglish
    ? 'LANGUAGE: Reply in natural Hinglish / casual Indian English. Use Roman Hindi when it fits; do not switch to formal Hindi.'
    : "LANGUAGE: Reply in natural conversational English only. The latest user message is in English, translated from the original when needed. Do not switch to Hindi or Hinglish.";

  return [getNormalModePrompt(selectedTier), languageRule, getMoodRules(selectedMood)].join('\n\n');
}

function cleanReply(reply) {
  let cleaned = String(reply ?? '').trim();
  cleaned = cleaned.replace(/^(reply|response|answer)\s*:\s*/i, '');
  if (cleaned.length >= 2) {
    const first = cleaned[0];
    const last = cleaned[cleaned.length - 1];
    if ((first === '"' && last === '"') || (first === "'" && last === "'")) {
      cleaned = cleaned.slice(1, -1).trim();
    }
  }
  cleaned = cleaned.replace(/^\*\*(.*?)\*\*$/, '$1');
  cleaned = cleaned.replace(/[ \t]+/g, ' ').trim();
  return cleaned.split('\n').map(line => line.trim()).filter(Boolean).slice(0, 2).join('\n').trim();
}

module.exports = { isHinglish, detectInputLanguage, getSystemPrompt, getMoodRules, cleanReply };
