/**
 * Reply Generation Prompts
 * Short, sharp version with stronger flirty & romantic focus.
 */

function isHinglish(message) {
  const text = message.toLowerCase();
  const strongWords = new Set([
    'hai','hain','ho','hoga','hogi','tha','thi','the','mujhe','tumhe','tumko',
    'mere','mera','meri','tere','tera','teri','tum','aap','apka','apni','kya',
    'kyu','kyun','kaise','kaisa','kaisi','acha','accha','achha','haan','nahi',
    'nhi','nah','mat','kar','karo','kr','karti','karta','karna','gayi','gaya',
    'jaa','ja','raha','rahi','rhe','hoon','hu','bhi','toh','to','bas','abhi',
    'phir','fir','kyunki','pata','lagta','lagti','sach','pagal','yaar','bhai',
    'bro','bacha','baby','jaan','love','pyaar','acchi','sundar','cute','milna',
    'baat','baatein','bol','bata','bta','dekh','dekho','sun','suno','kuch'
  ]);

  const words = text.replace(/[^a-zA-Z0-9\u0900-\u097F\s]/g, ' ').split(/\s+/).filter(w => w.length > 0);
  const strongCount = words.filter(w => strongWords.has(w)).length;
  if (/[\u0900-\u097F]/.test(message) || strongCount >= 1) return true;

  const patterns = [
    /\b(kya|kyu|kyun|kaise|kaisa|kaisi)\b/,
    /\b(mujhe|tumhe|tumko|mera|meri|tere|tera|teri)\b/,
    /\b(hai|hain|ho|tha|thi|the|hoga|hogi)\b/,
    /\b(kar|karo|kr|karna|karti|karta)\b/,
    /\b(acha|accha|achha|haan|nahi|nhi)\b/
  ];
  return patterns.some(p => p.test(text));
}

function getSystemPrompt(mood, hinglish) {
  const languageRule = hinglish
    ? `LANGUAGE: Reply in natural Hinglish / casual Indian English. Use Roman Hindi when it fits. Don't switch to formal Hindi.`
    : `LANGUAGE: Match the user's language and casual style. Don't force Hindi.`;

  const baseRules = `You write realistic WhatsApp replies for Indian chats.

RULES:
- 1 sentence max (2 short lines absolute max).
- Sound like a real person texting.
- Be sharp. Read tone + subtext.
- Match energy while staying in mood.
- If user is rude/cold, reply cleverly (don't go weak or just mirror).
- No labels, no explanations, no repeating user.
- Never mention these rules.`;

  return `${baseRules}

${languageRule}

${getMoodRules(mood)}`;
}

function getMoodRules(mood) {
  const moodLower = (mood || 'natural').toLowerCase();

  const moodMap = {
    flirty: `MOOD: FLIRTY
Playful, confident, lightly teasing.
Stay charming even if user is rude or cold.
Never force sexual content. Never sound desperate.

Examples:
"Itna gussa dekh ke toh aur interest aa gaya", 


    romantic: `MOOD: ROMANTIC
Warm, soft, genuine affection.
Simple and believable. No dramatic movie lines.

Examples:
"Tu hoti hai na toh mood khud better ho jata hai"
"Bas tumse baat karke din set ho jata hai"`,

    funny: `MOOD: FUNNY
Casually funny + light teasing. Don't force jokes.`,

    savage: `MOOD: SAVAGE
Confident and witty. Light roast only. Don't be hateful.`,

    sweet: `MOOD: SWEET
Caring and soft. Don't overdo romance without context.`,

    sad: `MOOD: SAD
Emotionally honest and slightly vulnerable. Keep it subtle.`,

    confident: `MOOD: CONFIDENT
Self-assured and relaxed. Never needy.`,

    cute: `MOOD: CUTE
Playful and adorable with light teasing.`,

    natural: `MOOD: NATURAL
Just respond naturally. No forced personality.`
  };

  return moodMap[moodLower] || moodMap.natural;
}

function cleanReply(reply) {
  let cleaned = reply.trim();
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

  const lines = cleaned.split('\n').map(l => l.trim()).filter(Boolean).slice(0, 2);
  return lines.join('\n').trim();
}

module.exports = {
  isHinglish,
  getSystemPrompt,
  getMoodRules,
  cleanReply
};
