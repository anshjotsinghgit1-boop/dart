const test = require('node:test');
const assert = require('node:assert/strict');

const { getTierCost } = require('./ai_reply_tiers');

test('Basic pricing increases by one coin per additional 20-word block', () => {
  assert.equal(getTierCost('basic', 1), 1);
  assert.equal(getTierCost('basic', 20), 1);
  assert.equal(getTierCost('basic', 21), 2);
  assert.equal(getTierCost('basic', 40), 2);
  assert.equal(getTierCost('basic', 41), 3);
  assert.equal(getTierCost('basic', 60), 3);
});

test('Smart pricing increases by two coins per additional 20-word block', () => {
  assert.equal(getTierCost('smart', 1), 3);
  assert.equal(getTierCost('smart', 20), 3);
  assert.equal(getTierCost('smart', 21), 5);
  assert.equal(getTierCost('smart', 40), 5);
  assert.equal(getTierCost('smart', 41), 7);
  assert.equal(getTierCost('smart', 60), 7);
});

test('Premium pricing increases by four coins per additional 20-word block', () => {
  assert.equal(getTierCost('premium', 1), 6);
  assert.equal(getTierCost('premium', 20), 6);
  assert.equal(getTierCost('premium', 21), 10);
  assert.equal(getTierCost('premium', 40), 10);
  assert.equal(getTierCost('premium', 41), 14);
  assert.equal(getTierCost('premium', 60), 14);
});

test('empty or missing word counts use the first block price', () => {
  assert.equal(getTierCost('basic', 0), 1);
  assert.equal(getTierCost('smart', 0), 3);
  assert.equal(getTierCost('premium', 0), 6);
});
