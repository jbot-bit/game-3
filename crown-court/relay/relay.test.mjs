import test from 'node:test';
import assert from 'node:assert/strict';
import { once } from 'node:events';
import WebSocket from 'ws';
import { createRelay, encodeFrame, sendBounded } from './server.mjs';

async function setup(t, options={}) {
  const relay=createRelay({host:'127.0.0.1',port:0,handshakeMs:400,...options});
  await relay.listen();
  const clients=[];
  t.after(async()=>{for(const c of clients)c.terminate();await relay.close();});
  const url=`ws://127.0.0.1:${relay.address().port}/rooms`;
  async function connect(registration) {
    const ws=new WebSocket(url);clients.push(ws);
    ws.messages=[];ws.waiters=[];
    ws.on('message',(data,binary)=>{const value=binary?Buffer.from(data):JSON.parse(data);if(ws.waiters.length)ws.waiters.shift()(value);else ws.messages.push(value);});
    ws.next=()=>new Promise((resolve,reject)=>{if(ws.messages.length)return resolve(ws.messages.shift());const timeout=setTimeout(()=>reject(new Error('message timeout')),1500);ws.waiters.push(v=>{clearTimeout(timeout);resolve(v);});});
    await once(ws,'open');
    if(registration)ws.send(JSON.stringify({protocol:1,version:'test-v1',...registration}));
    return ws;
  }
  return {relay,connect};
}

test('three real clients: room identity, version, full room, opaque routing, channels and sender isolation',async t=>{
  const {connect}=await setup(t);
  const host=await connect({type:'create'});const ready=await host.next();
  assert.equal(ready.type,'ready');assert.equal(ready.id,1);assert.match(ready.code,/^[A-HJ-NP-Z2-9]{26}$/);
  const bad=await connect({type:'join',code:ready.code,version:'wrong'});assert.equal((await bad.next()).code,'VERSION_MISMATCH');
  const invalid=await connect({type:'join',code:'invalid'});assert.equal((await invalid.next()).code,'INVALID_CODE');
  const a=await connect({type:'join',code:ready.code});const ar=await a.next();assert.equal(ar.id,2);assert.deepEqual(ar.peers,[1]);assert.equal((await host.next()).id,2);
  const b=await connect({type:'join',code:ready.code});const br=await b.next();assert.equal(br.id,3);assert.equal((await host.next()).id,3);
  const full=await connect({type:'join',code:ready.code});assert.equal((await full.next()).code,'ROOM_FULL');
  for(let channel=0;channel<5;channel++){
    const payload=Buffer.from([0,255,channel,88]);a.send(encodeFrame(2,1,channel,channel%3,payload));
    const packet=await host.next();assert.equal(packet.readUInt32LE(4),2);assert.equal(packet[1],channel);assert.equal(packet[2],channel%3);assert.deepEqual(packet.subarray(12),payload);
    host.send(encodeFrame(1,3,channel,2,payload));assert.deepEqual((await b.next()).subarray(12),payload);
  }
  a.send(encodeFrame(2,3,0,2,Buffer.from('forbidden')));assert.equal((await a.next()).code,'FORBIDDEN_TARGET');assert.equal((await host.next()).type,'peer_left');
  const replacement=await connect({type:'join',code:ready.code});const rr=await replacement.next();assert.equal(rr.id,4);assert.equal((await host.next()).id,4);
  replacement.send(encodeFrame(1,1,0,2,Buffer.from('spoof')));assert.equal((await replacement.next()).code,'SPOOFED_SENDER');assert.equal((await host.next()).id,4);
  const closed=once(b,'close');host.close();await closed;
});

test('rooms remain isolated; host expiry deletes room; registration and frame limits enforced',async t=>{
  const {connect}=await setup(t);
  const h=await connect({type:'create'});const r=await h.next();
  const other=await connect({type:'create'});const or=await other.next();assert.notEqual(or.code,r.code);
  const malformed=await connect();malformed.send('{bad');assert.equal((await malformed.next()).code,'BAD_REGISTRATION');
  const idle=await connect();assert.equal((await idle.next()).code,'REGISTRATION_TIMEOUT');
  h.close();await once(h,'close');
  const absent=await connect({type:'join',code:r.code});assert.equal((await absent.next()).code,'ROOM_NOT_FOUND');
  const c=await connect({type:'join',code:or.code});const cr=await c.next();await other.next();
  c.send(encodeFrame(cr.id,1,5,2,Buffer.from('bad channel')));assert.equal((await c.next()).code,'BAD_FRAME');
});

test('backpressure is bounded: drop disposable packets; disconnect instead of growing a reliable queue',()=>{
  const fake={readyState:WebSocket.OPEN,bufferedAmount:40000,sent:[],send(v){this.sent.push(v);},close(code,reason){this.closed={code,reason};}};
  const stats={dropped:0,slow:0};
  assert.equal(sendBounded(fake,Buffer.alloc(10),true,stats),false);assert.equal(stats.dropped,1);assert.equal(fake.sent.length,0);
  fake.bufferedAmount=262144;
  assert.equal(sendBounded(fake,Buffer.alloc(10),false,stats),false);assert.equal(fake.closed.code,1013);assert.equal(stats.slow,1);
});

test('malicious traffic cannot register twice or flood frame budget',async t=>{
  const {connect}=await setup(t,{maxFramesPerSecond:5});
  const h=await connect({type:'create'});const r=await h.next();
  const a=await connect({type:'join',code:r.code});const ar=await a.next();await h.next();
  a.send(JSON.stringify({type:'create',protocol:1,version:'test-v1'}));assert.equal((await a.next()).code,'BAD_CONTROL');await h.next();
  const b=await connect({type:'join',code:r.code});const br=await b.next();await h.next();
  for(let i=0;i<10;i++)b.send(encodeFrame(br.id,1,2,1,Buffer.from([i])));
  assert.equal((await b.next()).code,'RATE_LIMIT');
});

test('kick/refuse, expired rooms and connection registration limits',async t=>{
  const {connect}=await setup(t,{maxRoomAgeMs:150,heartbeatMs:25,deadMs:500});
  const h=await connect({type:'create'});const r=await h.next();
  h.send(JSON.stringify({type:'refuse',value:true}));
  await new Promise(resolve=>setTimeout(resolve,20));
  const denied=await connect({type:'join',code:r.code});assert.equal((await denied.next()).code,'ROOM_LOCKED');
  h.send(JSON.stringify({type:'refuse',value:false}));await new Promise(resolve=>setTimeout(resolve,20));
  const a=await connect({type:'join',code:r.code});const ar=await a.next();await h.next();
  h.send(JSON.stringify({type:'kick',id:ar.id}));assert.equal((await a.next()).type,'room_closed');assert.equal((await h.next()).type,'peer_left');
  assert.equal((await h.next()).type,'room_closed');
});

test('oversized messages are rejected by WebSocket parser; public plaintext bind cannot start',async t=>{
  assert.throws(()=>createRelay({host:'0.0.0.0'}),/requires TLS/);
  const {connect}=await setup(t);
  const ws=await connect();const closed=once(ws,'close');ws.send(Buffer.alloc(131085));const [code]=await closed;assert.equal(code,1009);
});
