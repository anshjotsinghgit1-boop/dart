const test = require('node:test');
const assert = require('node:assert/strict');

const {
  detectInputLanguage,
  getSystemPrompt,
} = require('./reply_prompt');

test('detects Hindi written in Devanagari', () => {
  assert.equal(detectInputLanguage('तुम क्या कर रहे हो?'), 'hindi');
});

test('detects Roman-script Hinglish', () => {
  assert.equal(detectInputLanguage('Tum kya kar rahe ho?'), 'hinglish');
});

test('does not classify ordinary English affection words as Hinglish', () => {
  assert.equal(detectInputLanguage('I love you baby, bro.'), 'english');
});

test('Premium prompt supports both Flirty and Romantic moods', () => {
  assert.match(getSystemPrompt('flirty', false, 'premium'), /MOOD: FLIRTY/);
  assert.match(getSystemPrompt('romantic', false, 'premium'), /MOOD: ROMANTIC/);
});

test('Premium prompt rejects moods outside Flirty and Romantic', () => {
  assert.throws(
    () => getSystemPrompt('sad', false, 'premium'),
    /flirty or romantic/i,
  );
});
