const fs = require('node:fs');
const path = require('node:path');

const PROMPTS_DIR = path.join(__dirname, 'prompts');
const NORMAL_PROMPT_PATH = path.join(PROMPTS_DIR, 'normal.txt');
const PREMIUM_PROMPT_PATH = path.join(PROMPTS_DIR, 'premium.txt');

function isHinglish(message) {
  const original = String(message ?? '');
  const text = original.toLowerCase();
  const strongWords = new Set([
    'hai', 'hain', 'ho', 'hoga', 'hogi', 'tha', 'thi', 'the', 'mujhe', 'tumhe', 'tumko',
    'mere', 'mera', 'meri', 'tere', 'tera', 'teri', 'tum', 'aap', 'apka', 'apni', 'kya',
    'kyu', 'kyun', 'kaise', 'kaisa', 'kaisi', 'acha', 'accha', 'achha', 'haan', 'nahi',
    'nhi', 'nah', 'mat', 'kar', 'karo', 'kr', 'karti', 'karta', 'karna', 'gayi', 'gaya',
    'jaa', 'ja', 'raha', 'rahi', 'rhe', 'hoon', 'hu', 'bhi', 'toh', 'to', 'bas', 'abhi',
    'phir', 'fir', 'kyunki', 'pata', 'lagta', 'lagti', 'sach', 'pagal', 'yaar', 'bhai',
    'bro', 'bacha', 'baby', 'jaan', 'love', 'pyaar', 'acchi', 'sundar', 'cute', 'milna',
    'baat', 'baatein', 'bol', 'bata', 'bta', 'dekh', 'dekho', 'sun', 'suno', 'kuch'
  ]);
  const words = text.replace(/[^a-zA-Z0-9\u0900-\u097F\s]/g, ' ').split(/\s+/).filter(Boolean);
  if (/[\u0900-\u097F]/.test(original) || words.some(word => strongWords.has(word))) return true;
  return false;
}

function getMoodRules(mood) {
  const moodLower = String(mood || 'natural').trim().toLowerCase();
  const moodMap = {
    flirty: 'MOOD: FLIRTY\nPlayful, confident and lightly teasing. Stay charming without sounding desperate. Never force sexual content.',
    romantic: 'MOOD: ROMANTIC\nWarm, soft and genuinely affectionate. Keep it simple and believable, not dramatic.',
    funny: 'MOOD: FUNNY\nUse casual humor and light teasing. Do not force jokes.',
    savage: 'MOOD: SAVAGE\nBe confident and witty. Keep roasts light; do not be hateful.',
    sweet: 'MOOD: SWEET\nBe caring, gentle and sincere. Do not overdo romance without context.',
    sad: 'MOOD: SAD\nBe emotionally honest and subtly vulnerable. Avoid melodrama.',
    confident: 'MOOD: CONFIDENT\nSound self-assured and relaxed, never needy or arrogant.',
    cute: 'MOOD: CUTE\nBe playful, sweet and lightly teasing.',
    natural: 'MOOD: NATURAL\nRespond naturally to the situation. Do not force a personality.'
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
    if (selectedMood !== 'flirty') {
      throw new Error('Premium mode is available only with flirty mood.');
    }
    // Premium is intentionally standalone: do not load or append normal.txt,
    // language rules, mood rules, or examples from the Basic/Smart prompt.
    const premiumPrompt = fs.readFileSync(PREMIUM_PROMPT_PATH, 'utf8').trim();
    if (!premiumPrompt) throw new Error('The Premium prompt file is empty.');
    return premiumPrompt;
  }

  const languageRule = hinglish
    ? 'LANGUAGE: Reply in natural Hinglish / casual Indian English. Use Roman Hindi when it fits; do not switch to formal Hindi.'
    : "LANGUAGE: Match the user's language and casual style. Do not force Hindi.";

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

module.exports = { isHinglish, getSystemPrompt, getMoodRules, cleanReply };
