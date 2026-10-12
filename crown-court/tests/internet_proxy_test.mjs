import assert from 'node:assert/strict';
import {scheduleDecision} from './internet_proxy.mjs';

// A broken loss threshold, asymmetric scheduler, or unseeded jitter must fail.
const sequence = seed => Array.from({length:10000}, (_, index) => scheduleDecision(seed, index, 50, 10, .01));
const first=sequence(7123), repeated=sequence(7123), other=sequence(7124);
assert.deepEqual(first,repeated,'A seed must produce the same impairment schedule');
assert.notDeepEqual(first,other,'Independent directions must have independent schedules');
const dropped=first.filter(x=>x.drop).length;
assert.ok(dropped>=60 && dropped<=140,`Expected about 1% seeded loss, saw ${dropped}/10000`);
assert.ok(first.every(x=>x.delayMs>=40 && x.delayMs<=60),'One-way jitter must stay in 40–60 ms');
assert.ok(first.some(x=>x.delayMs<45) && first.some(x=>x.delayMs>55),'Jitter must actually vary');
console.log(`INTERNET_PROXY_UNIT PASS deterministic 40–60ms one-way; ${dropped}/10000 dropped`);
