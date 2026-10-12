import dgram from 'node:dgram';
import fs from 'node:fs';
import path from 'node:path';
import {pathToFileURL} from 'node:url';
import {performance} from 'node:perf_hooks';

function mix(value) {
  value = Math.imul(value ^ (value >>> 16), 0x7feb352d);
  value = Math.imul(value ^ (value >>> 15), 0x846ca68b);
  return (value ^ (value >>> 16)) >>> 0;
}
export function scheduleDecision(seed, ordinal, delayMs, jitterMs, loss) {
  const state=mix((seed ^ Math.imul(ordinal+1,0x9e3779b9)) >>> 0);
  return {drop:state/4294967296<loss,delayMs:delayMs+(mix(state^0x68bc21eb)/4294967296*2-1)*jitterMs};
}

async function main() {
  const options=Object.fromEntries(process.argv.slice(2).map(arg=>arg.replace(/^--/,'').split('=')));
  const base=Number(options.port??30180),seed=Number(options.seed??7123);
  const delay=Number(options.delay??50),jitter=Number(options.jitter??10),loss=Number(options.loss??.01);
  const folder=path.resolve(options.output),scenario=options.scenario??'actions';
  if (!Number.isInteger(base)||base<1024||base>65530||delay<jitter||jitter<0||loss<0||loss>1) throw Error('Invalid isolated proxy settings');
  fs.mkdirSync(folder,{recursive:true});
  const started=performance.now(),timers=new Set(),sockets=[],flows={};
  let stopping=false;
  const bind=(socket,port)=>new Promise((resolve,reject)=>{socket.once('error',reject);socket.bind(port,'127.0.0.1',()=>{socket.removeListener('error',reject);resolve();});});
  const percentile=(values,p)=>values.length?[...values].sort((a,b)=>a-b)[Math.min(values.length-1,Math.floor(p*values.length))]:0;
  function report(final=false) {
    const summary={label:'SIMULATED_INTERNET',scenario,seed,base_port:base,host:'127.0.0.1',one_way_delay_ms:delay,jitter_ms:jitter,loss_probability:loss,elapsed_seconds:(performance.now()-started)/1000,final,flows:{}};
    for (const [key,f] of Object.entries(flows)) summary.flows[key]={received:f.received,forwarded:f.forwarded,dropped:f.dropped,cancelled:f.cancelled,bytes:f.bytes,max_datagram_bytes:f.maxBytes,observed_delay_ms:{min:f.delays.length?Math.min(...f.delays):0,p50:percentile(f.delays,.5),p95:percentile(f.delays,.95),max:f.delays.length?Math.max(...f.delays):0},decision_digest:f.digest>>>0};
    fs.writeFileSync(path.join(folder,'proxy-stats.json'),JSON.stringify(summary,null,2));
  }
  function forward(flow,buffer,deliver) {
    const ordinal=flow.received++;
    flow.bytes+=buffer.length;flow.maxBytes=Math.max(flow.maxBytes,buffer.length);
    const decision=scheduleDecision(flow.seed,ordinal,delay,jitter,loss);
    flow.digest=mix(flow.digest^(decision.drop?1:0)^Math.round(decision.delayMs*1000));
    if(decision.drop){flow.dropped++;return;}
    const queued=performance.now();
    const timer=setTimeout(()=>{timers.delete(timer);if(stopping){flow.cancelled++;return;}deliver();flow.forwarded++;flow.delays.push(performance.now()-queued);},decision.delayMs);
    timers.add(timer);
  }
  for(let index=0;index<2;index++) {
    const front=dgram.createSocket('udp4'),upstream=dgram.createSocket('udp4');
    sockets.push(front,upstream);
    await bind(front,base+index+1);await bind(upstream,base+index+3);
    let client=null;
    for(const [direction,number] of [['up',0],['down',1]]) flows[`client${index+1}_${direction}`]={seed:seed+index*101+number*17,received:0,forwarded:0,dropped:0,cancelled:0,bytes:0,maxBytes:0,delays:[],digest:0};
    front.on('message',(buffer,sender)=>{
      if(client&&(client.port!==sender.port||client.address!==sender.address))return;
      client=sender;
      forward(flows[`client${index+1}_up`],buffer,()=>upstream.send(buffer,base,'127.0.0.1'));
    });
    upstream.on('message',(buffer,sender)=>{
      if(!client||sender.port!==base||sender.address!=='127.0.0.1')return;
      forward(flows[`client${index+1}_down`],buffer,()=>front.send(buffer,client.port,client.address));
    });
    for(const socket of [front,upstream])socket.on('error',error=>{console.error(error);shutdown(1);});
  }
  const poll=setInterval(()=>{report();if(fs.existsSync(path.join(folder,'stop-proxy')))shutdown(0);},200);
  function shutdown(code) {
    if(stopping)return;stopping=true;clearInterval(poll);
    for(const timer of timers)clearTimeout(timer);
    for(const socket of sockets)socket.close();
    report(true);process.exitCode=code;
  }
  process.on('SIGINT',()=>shutdown(0));process.on('SIGTERM',()=>shutdown(0));
  report();fs.writeFileSync(path.join(folder,'proxy-ready.json'),JSON.stringify({ready:true,base,scenario}));
  console.log(`INTERNET_PROXY_READY ${base+1},${base+2} -> ${base}; seeded ${delay} +/-${jitter}ms each way, loss ${loss}`);
}
if(process.argv[1]&&import.meta.url===pathToFileURL(path.resolve(process.argv[1])).href)main().catch(error=>{console.error(error);process.exitCode=1;});
