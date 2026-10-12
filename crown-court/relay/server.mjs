import http from 'node:http';
import https from 'node:https';
import { readFileSync } from 'node:fs';
import { randomBytes } from 'node:crypto';
import { fileURLToPath } from 'node:url';
import WebSocket, { WebSocketServer } from 'ws';

export const PROTOCOL=1;
export const MAX_PACKET=131072;
const ALPHABET='ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
const SOFT_BUFFER=32768;
const HARD_BUFFER=262144;
function roomCode(){let bits=0,value=0,result='';for(const byte of randomBytes(16)){value=(value<<8)|byte;bits+=8;while(bits>=5){bits-=5;result+=ALPHABET[(value>>>bits)&31];}}if(bits)result+=ALPHABET[(value<<(5-bits))&31];return result;}
export function encodeFrame(sender,target,channel,mode,payload){const b=Buffer.allocUnsafe(12+payload.length);b[0]=1;b[1]=channel;b[2]=mode;b[3]=0;b.writeUInt32LE(sender,4);b.writeInt32LE(target,8);Buffer.from(payload).copy(b,12);return b;}
export function sendBounded(ws,bytes,disposable=false,stats={dropped:0,slow:0}){
  if(!ws||ws.readyState!==WebSocket.OPEN)return false;
  stats.maxBufferedBytes=Math.max(stats.maxBufferedBytes||0,ws.bufferedAmount);
  if(disposable&&ws.bufferedAmount>SOFT_BUFFER){stats.dropped++;return false;}
  if(ws.bufferedAmount+bytes.length>HARD_BUFFER){stats.slow++;ws.close(1013,'Slow connection');return false;}
  ws.send(bytes,{binary:true});return true;
}

export function createRelay(options={}){
  const cfg={host:'127.0.0.1',port:30220,handshakeMs:8000,heartbeatMs:10000,deadMs:30000,maxRooms:256,maxConnections:800,maxFramesPerSecond:240,maxBytesPerSecond:1048576,maxRoomAgeMs:7200000,...options};
  const loopback=['127.0.0.1','::1','localhost'].includes(cfg.host);
  if(!loopback&&!cfg.tls&&!cfg.tlsTerminated)throw new Error('Public bind requires TLS or an explicitly configured TLS terminator');
  const rooms=new Map(),ips=new Map();
  const stats={dropped:0,slow:0,forwarded:0,rejected:0,rejections:{}};
  const handler=(req,res)=>{if(req.url!=='/healthz'){res.writeHead(404);res.end();return;}res.writeHead(200,{'content-type':'application/json','cache-control':'no-store'});res.end(JSON.stringify({ok:true,protocol:PROTOCOL,rooms:rooms.size,connections:wss.clients.size}));};
  const server=cfg.tls?https.createServer(cfg.tls,handler):http.createServer(handler);
  const wss=new WebSocketServer({noServer:true,maxPayload:MAX_PACKET+12,perMessageDeflate:false});
  function control(ws,data){if(ws&&ws.readyState===WebSocket.OPEN)ws.send(JSON.stringify(data));}
  function reject(ws,code,message){if(ws.failed)return;ws.failed=true;stats.rejected++;stats.rejections[code]=(stats.rejections[code]||0)+1;control(ws,{type:'error',code,message});ws.close(4000,message.slice(0,100));const timer=setTimeout(()=>ws.terminate(),500);timer.unref();}
  function destroyRoom(room,message='The host closed the room.'){
    if(rooms.get(room.code)!==room)return;
    rooms.delete(room.code);
    for(const member of room.members.values()){member.room=null;if(member.id!==1){control(member,{type:'room_closed',message});member.close(1001,'Host left');}}
    room.members.clear();
  }
  server.on('upgrade',(req,socket,head)=>{
    if(req.url!=='/rooms'||wss.clients.size>=cfg.maxConnections||(cfg.tlsTerminated&&!loopback&&req.headers['x-forwarded-proto']!=='https')){socket.end('HTTP/1.1 403 Forbidden\r\nConnection: close\r\n\r\n');return;}
    const ip=req.socket.remoteAddress||'unknown',now=Date.now();
    let budget=ips.get(ip);if(!budget||now-budget.since>60000){budget={since:now,count:0};ips.set(ip,budget);}budget.count++;
    if(budget.count>120){socket.end('HTTP/1.1 429 Too Many Requests\r\nConnection: close\r\n\r\n');return;}
    wss.handleUpgrade(req,socket,head,ws=>wss.emit('connection',ws,req));
  });
  wss.on('connection',ws=>{
    ws.room=null;ws.id=0;ws.failed=false;ws.lastPong=Date.now();ws.windowStart=Date.now();ws.frameCount=0;ws.byteCount=0;
    const registrationTimer=setTimeout(()=>reject(ws,'REGISTRATION_TIMEOUT','Room registration timed out.'),cfg.handshakeMs);registrationTimer.unref();
    ws.on('error',()=>{});
    ws.on('pong',()=>{ws.lastPong=Date.now();});
    ws.on('close',()=>{
      clearTimeout(registrationTimer);
      const room=ws.room;if(!room)return;ws.room=null;
      if(ws.id===1){destroyRoom(room);return;}
      room.members.delete(ws.id);control(room.members.get(1),{type:'peer_left',id:ws.id});
    });
    ws.on('message',(data,binary)=>{
      if(ws.failed)return;
      if(!ws.room){
        if(binary||data.length>2048){reject(ws,'BAD_REGISTRATION','Invalid room registration.');return;}
        let msg;try{msg=JSON.parse(data.toString());}catch{reject(ws,'BAD_REGISTRATION','Invalid room registration.');return;}
        if(!msg||msg.protocol!==PROTOCOL||typeof msg.version!=='string'||!/^[A-Za-z0-9._+-]{1,48}$/.test(msg.version)||!['create','join'].includes(msg.type)){reject(ws,'BAD_REGISTRATION','Unsupported room protocol.');return;}
        let room;
        if(msg.type==='create'){
          if(rooms.size>=cfg.maxRooms){reject(ws,'SERVICE_FULL','The room service is busy. Try again later.');return;}
          let code;do{code=roomCode();}while(rooms.has(code));
          room={code,version:msg.version,members:new Map(),nextId:2,created:Date.now()};rooms.set(code,room);ws.id=1;
        }else{
          if(typeof msg.code!=='string'||msg.code.length!==26||[...msg.code].some(c=>!ALPHABET.includes(c))){reject(ws,'INVALID_CODE','Check the room code and try again.');return;}
          room=rooms.get(msg.code);
          if(!room){reject(ws,'ROOM_NOT_FOUND','That room is no longer available.');return;}
          if(room.version!==msg.version){reject(ws,'VERSION_MISMATCH','Everyone must use the same game version.');return;}
          if(room.members.size>=3){reject(ws,'ROOM_FULL','This room already has three players.');return;}
          if(room.refuse){reject(ws,'ROOM_LOCKED','The host is not accepting joins.');return;}
          ws.id=room.nextId++;
        }
        ws.room=room;room.members.set(ws.id,ws);clearTimeout(registrationTimer);
        control(ws,{type:'ready',protocol:PROTOCOL,version:room.version,code:room.code,id:ws.id,peers:ws.id===1?[]:[1]});
        if(ws.id!==1)control(room.members.get(1),{type:'peer_joined',id:ws.id});
        return;
      }
      const now=Date.now();if(now-ws.windowStart>=1000){ws.windowStart=now;ws.frameCount=0;ws.byteCount=0;}
      if(++ws.frameCount>cfg.maxFramesPerSecond||(ws.byteCount+=data.length)>cfg.maxBytesPerSecond){reject(ws,'RATE_LIMIT','Connection sent too much data.');return;}
      const room=ws.room;
      if(!binary){
        let msg;try{msg=JSON.parse(data.toString());}catch{reject(ws,'BAD_CONTROL','Invalid room control.');return;}
        if(data.length>2048||ws.id!==1||!msg||!['kick','refuse'].includes(msg.type)){reject(ws,'BAD_CONTROL','Invalid room control.');return;}
        if(msg.type==='refuse'){room.refuse=msg.value===true;return;}
        if(!Number.isInteger(msg.id)||msg.id===1||!room.members.has(msg.id)){reject(ws,'BAD_CONTROL','Invalid peer.');return;}
        const member=room.members.get(msg.id);control(member,{type:'room_closed',message:'The host removed you from the room.'});member.close(1001,'Removed by host');return;
      }
      if(data.length<13||data.length>MAX_PACKET+12||data[0]!==1||data[1]>4||data[2]>2||data[3]!==0){reject(ws,'BAD_FRAME','Invalid game packet.');return;}
      if(data.readUInt32LE(4)!==ws.id){reject(ws,'SPOOFED_SENDER','Invalid packet sender.');return;}
      const target=data.readInt32LE(8);let recipients=[];
      if(ws.id!==1){if(target!==1&&target!==0){reject(ws,'FORBIDDEN_TARGET','Clients may only send to the host.');return;}recipients=[room.members.get(1)];}
      else if(target>0){if(target===1||!room.members.has(target))return;recipients=[room.members.get(target)];}
      else recipients=[...room.members.values()].filter(m=>m.id!==1&&m.id!==-target);
      for(const recipient of recipients){if(recipient&&sendBounded(recipient,data,data[2]!==2,stats))stats.forwarded++;}
    });
  });
  const timer=setInterval(()=>{
    const now=Date.now();
    for(const ws of wss.clients){if(now-ws.lastPong>cfg.deadMs)ws.terminate();else if(ws.readyState===WebSocket.OPEN)ws.ping();}
    for(const room of rooms.values())if(now-room.created>cfg.maxRoomAgeMs){const host=room.members.get(1);destroyRoom(room,'The room expired. Create a new room.');control(host,{type:'room_closed',message:'The room expired. Create a new room.'});host.close(1001,'Room expired');}
    for(const [ip,entry]of ips)if(now-entry.since>60000)ips.delete(ip);
  },cfg.heartbeatMs);timer.unref();
  return {stats,rooms,address:()=>server.address(),listen:()=>new Promise((resolve,reject)=>{server.once('error',reject);server.listen(cfg.port,cfg.host,resolve);}),close:()=>new Promise(resolve=>{clearInterval(timer);for(const ws of wss.clients)ws.terminate();wss.close(()=>server.close(resolve));})};
}

if(process.argv[1]&&fileURLToPath(import.meta.url)===process.argv[1]){
  const tls=process.env.TLS_CERT&&process.env.TLS_KEY?{cert:readFileSync(process.env.TLS_CERT),key:readFileSync(process.env.TLS_KEY)}:null;
  const relay=createRelay({host:process.env.HOST||'127.0.0.1',port:Number(process.env.PORT||30220),tls,tlsTerminated:process.env.TLS_TERMINATED==='1'});
  await relay.listen();console.log(`CROWN_ROOM_RELAY_READY ${relay.address().port}`);
  for(const signal of ['SIGINT','SIGTERM'])process.once(signal,async()=>{await relay.close();process.exit(0);});
}


