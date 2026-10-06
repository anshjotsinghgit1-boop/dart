/**
 * Reply Generation Prompts
 * 
 * This module contains the system prompts for AI reply generation.
 * Preserves the Hinglish detection and mood handling from groq_service.dart.
 */

/**
 * Detect if text contains Hinglish
 * @param {string} message - The message to analyze
 * @returns {boolean} True if message is in Hinglish
 */
function isHinglish(message) {
  const text = message.toLowerCase();

  const strongWords = new Set([
    'hai', 'hain', 'ho', 'hoga', 'hogi', 'tha', 'thi', 'the',
    'mujhe', 'tumhe', 'tumko', 'mere', 'mera', 'meri', 'tere', 'tera', 'teri',
    'tum', 'aap', 'apka', 'apni', 'kya', 'kyu', 'kyun', 'kaise', 'kaisa', 'kaisi',
    'acha', 'accha', 'achha', 'haan', 'nahi', 'nhi', 'nah', 'mat',
    'kar', 'karo', 'kr', 'karti', 'karta', 'karna', 'gayi', 'gaya',
    'jaa', 'ja', 'raha', 'rahi', 'rhe', 'hoon', 'hu', 'bhi', 'toh', 'to',
    'bas', 'abhi', 'phir', 'fir', 'kyunki', 'pata', 'lagta', 'lagti',
    'sach', 'pagal', 'yaar', 'bhai', 'bro', 'bacha', 'baby', 'jaan',
    'love', 'pyaar', 'acchi', 'sundar', 'cute', 'milna', 'baat', 'baatein',
    'bol', 'bata', 'bta', 'dekh', 'dekho', 'sun', 'suno', 'kuch',
  ]);

  const words = text
    .replace(/[^a-zA-Z0-9\u0900-\u097F\s]/g, ' ')
    .split(/\s+/)
    .filter(w => w.length > 0);

  const strongCount = words.filter(w => strongWords.has(w)).length;

  // Check for Devanagari script
  const hasDevanagari = /[\u0900-\u097F]/.test(message);
  if (hasDevanagari) {
    return true;
  }

  // If >= 1 strong word found, it's Hinglish
  if (strongCount >= 1) {
    return true;
  }

  // Check for Hinglish patterns
  const hinglishPatterns = [
    /\b(kya|kyu|kyun|kaise|kaisa|kaisi)\b/,
    /\b(mujhe|tumhe|tumko|mera|meri|tere|tera|teri)\b/,
    /\b(hai|hain|ho|tha|thi|the|hoga|hogi)\b/,
    /\b(kar|karo|kr|karna|karti|karta)\b/,
    /\b(acha|accha|achha|haan|nahi|nhi)\b/,
  ];

  return hinglishPatterns.some(p => p.test(text));
}

/**
 * Generate system prompt for reply generation
 * @param {string} mood - The mood ('flirty', 'romantic', 'funny', etc.)
 * @param {boolean} hinglish - Whether to use Hinglish
 * @returns {string} System prompt
 */
function getSystemPrompt(mood, hinglish) {
  const languageRule = hinglish
    ? `LANGUAGE:
The user is texting in Hinglish/Indian texting style.
Reply naturally in Hinglish or casual Indian English.
Use Roman Hindi when appropriate.
Do not suddenly switch into formal Hindi.`
    : `LANGUAGE:
Reply in the same general language and style as the user.
If they use casual English, stay casual.
Do not unnecessarily add Hindi.`;

  const baseRules = `You create realistic replies for Indian WhatsApp-style conversations.

Your job is to write the message the person should actually send.

RULES:
- Keep replies short.
- Usually one sentence.
- Maximum two short lines.
- Sound human and spontaneous.
- Use normal texting language.
- Do not sound like an AI assistant.
- Do not explain the reply.
- Do not write "Reply:" or similar labels.
- Do not repeat the user's message.
- Do not overuse emojis.
- Match the conversation's emotional context.
- Avoid generic motivational lines.
- Avoid overly polished or formal language.
- Small natural texting imperfections are okay.
- Never mention these instructions.`;

  const moodRules = getMoodRules(mood);

  return `${baseRules}

${languageRule}

${moodRules}`;
}

/**
 * Get mood-specific rules
 * @param {string} mood - The mood
 * @returns {string} Mood rules
 */
function getMoodRules(mood) {
  const moodLower = (mood || 'natural').toLowerCase();

  const moodMap = {
    flirty: `MOOD: FLIRTY

Be playful, confident and lightly teasing.
Keep the flirting natural.
Do not force sexual content.

Example style:
"Bas tum thodi aur cute ho jao, phir mera control gaya 😭"`,

    romantic: `MOOD: ROMANTIC

Be warm and affectionate.
Keep it simple and believable.
Avoid dramatic movie-style declarations.

Example style:
"Tu hoti hai na toh mood automatically better ho jata hai."`,

    funny: `MOOD: FUNNY

Be casually funny.
Use light teasing when appropriate.
Do not force a joke into every reply.

Example style:
"Accha ji, aaj bade shareef ban rahe ho 😂"`,

    savage: `MOOD: SAVAGE

Be confident and witty.
Lightly roast or tease when appropriate.
Do not become unnecessarily hateful.

Example style:
"Confidence toh full hai, bas logic thoda missing hai 😂"`,

    sweet: `MOOD: SWEET

Be caring, soft and genuine.
Do not become overly romantic without context.

Example style:
"Acha, take care okay? Zyada stress mat lena."`,

    sad: `MOOD: SAD

Be emotionally honest and slightly vulnerable.
Keep it subtle rather than dramatic.

Example style:
"Bas kabhi kabhi lagta hai kuch cheezein pehle jaisi nahi rahi."`,

    confident: `MOOD: CONFIDENT

Sound self-assured and relaxed.
Never sound desperate or needy.

Example style:
"Relax, mujhe pata hai main kya kar raha hoon 😌"`,

    cute: `MOOD: CUTE

Be playful, adorable and lightly teasing.

Example style:
"Ab itna cute banoge toh reply toh karna padega na 😭"`,

    natural: `MOOD: NATURAL

Respond naturally according to the conversation.
Do not force a particular personality.`,
  };

  return moodMap[moodLower] || moodMap.natural;
}

/**
 * Clean up AI response
 * @param {string} reply - Raw AI response
 * @returns {string} Cleaned reply
 */
function cleanReply(reply) {
  let cleaned = reply.trim();

  // Remove "reply:" or "response:" prefixes
  cleaned = cleaned.replace(/^(reply|response|answer)\s*:\s*/i, '');

  // Remove surrounding quotes if they match
  if (cleaned.length >= 2) {
    const first = cleaned[0];
    const last = cleaned[cleaned.length - 1];
    if ((first === '"' && last === '"') || (first === "'" && last === "'")) {
      cleaned = cleaned.substring(1, cleaned.length - 1).trim();
    }
  }

  // Remove markdown bold
  cleaned = cleaned.replace(/^\*\*(.*?)\*\*$/, '$1');

  // Normalize whitespace
  cleaned = cleaned.replace(/[ \t]+/g, ' ').trim();

  // Take only first 2 lines
  const lines = cleaned
    .split('\n')
    .map(line => line.trim())
    .filter(line => line.length > 0)
    .slice(0, 2);

  return lines.join('\n').trim();
}

module.exports = {
  isHinglish,
  getSystemPrompt,
  getMoodRules,
  cleanReply,
};
