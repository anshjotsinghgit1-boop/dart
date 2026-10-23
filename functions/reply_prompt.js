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
    flirty: `MOOD: FLIRTY — REQUIRED STYLE
Do not produce a merely friendly or neutral reply when a natural flirt fits. Use one clear move: playful teasing, witty reversal, cheeky confidence, suggestive subtext, a playful challenge, or warm charm. Respond to the exact message. For a greeting, answer with personality and a flirty hook. For boredom, playfully involve the sender rather than offering generic activities. For affection, be charming instead of lecturing. For vulnerability, lead with genuine care and never exploit it. Do not end automatically with "what about you?" or "tumhara kya haal hai?" Avoid stock pickup lines, forced slang, and generic filler. Respect boundaries and never invent mutual feelings.`,
    romantic: `MOOD: ROMANTIC
Be sincere, warm, specific, and emotionally observant. Use understated affection rather than clichés or grand declarations. Match the relationship context; never invent shared history, commitments, or feelings.`,
    funny: `MOOD: FUNNY
Make an actual joke, witty reversal, or context-specific observation. Avoid generic acknowledgements and don't force humour into vulnerable moments.`,
    savage: `MOOD: SAVAGE
Use a crisp, clever comeback with confidence. Aim for wit, not cruelty, harassment, humiliation, or hateful insults.`,
    sweet: `MOOD: SWEET
Be warm, thoughtful, and believable. Respond to the exact message instead of adding generic reassurance or overdone affection.`,
    sad: `MOOD: SAD
Be emotionally honest and grounded. Acknowledge the feeling naturally without melodrama, guilt-tripping, or unsolicited advice.`,
    confident: `MOOD: CONFIDENT
Sound calm, direct, and self-assured. Avoid arrogance, defensiveness, or trying too hard to prove a point.`,
    cute: `MOOD: CUTE
Be charming, lightly playful, and endearing without sounding childish or using too many emojis.`,
    natural: `MOOD: NATURAL
Answer the actual message plainly and humanly. Do not force flirting, jokes, or advice unless the message calls for it.`
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
