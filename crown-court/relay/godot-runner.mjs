import { spawn } from 'node:child_process';
import { resolve } from 'node:path';
import { mkdirSync,writeFileSync,readFileSync,existsSync,readdirSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { parseArgs } from 'node:util';
import { createRelay } from './server.mjs';
import { tcpImpairment } from './tcp-impairment.mjs';
const workspace=resolve(import.meta.dirname,'../..');
const hash=path=>createHash('sha256').update(readFileSync(path)).digest('hex').toUpperCase();
export async function runGodotTest(mode){
 const {values}=parseArgs({options:{pack:{type:'string'},'client-pack':{type:'string'},evidence:{type:'string'},url:{type:'string'}}});
 const endpoint=values.url||null;
 if(endpoint){const u=new URL(endpoint);if(u.protocol!=='wss:'||u.username||u.password||u.pathname!=='/rooms'||u.search||u.hash)throw new Error('Public probe requires a credential-free wss://host/rooms endpoint');if(mode!=='rpc')throw new Error('Public endpoint cannot be combined with loopback impairment');}
 const pack=values.pack?resolve(values.pack):null;
 const clientPack=values['client-pack']?resolve(values['client-pack']):pack;
 const clientHashBefore=clientPack?hash(clientPack):null;
 const evidence=resolve(values.evidence||resolve(workspace,`build/crown-court-evidence/room-relay-${mode}-${Date.now()}`));
 if(existsSync(evidence)&&readdirSync(evidence).length)throw new Error('Evidence destination must be new or empty');
 mkdirSync(evidence,{recursive:true});
 const probe=resolve(import.meta.dirname,mode==='wan'?'room_wan_probe.gd':'room_rpc_probe.gd');
 const implementation=pack||resolve(workspace,'crown-court/room_peer.gd');
 const before=hash(implementation);
 const relay=endpoint?null:createRelay({port:30220});if(relay)await relay.listen();
 const proxy=mode==='wan'?tcpImpairment():null;if(proxy)await proxy.listen();
 const children=[];let launchClients=false;
 function launch(role,code=''){
  const rolePack=role==='host'?pack:clientPack;
  const args=['--headless','--path',resolve(workspace,'crown-court')];if(rolePack)args.push('--main-pack',rolePack);args.push('--script',probe,'--',`role=${role}`,`code=${code}`);
  if(endpoint)args.push(`url=${endpoint}`);
  const roaming=resolve(evidence,'profiles',role,'Roaming'),local=resolve(evidence,'profiles',role,'Local');mkdirSync(roaming,{recursive:true});mkdirSync(local,{recursive:true});
  const child=spawn(process.env.GODOT_ENGINE||resolve(workspace,'.tools/godot/Godot_v4.7.2-stable_win64_console.exe'),args,{windowsHide:true,env:{...process.env,APPDATA:roaming,LOCALAPPDATA:local}});
  children.push(child);let output='';
  child.stdout.on('data',data=>{output+=data;process.stdout.write(`${role}: ${data}`.replace(/ROOM_TEST_CODE [A-Z2-9]+/g,'ROOM_TEST_CODE [redacted]'));const match=output.match(/ROOM_TEST_CODE ([A-Z2-9]{26})/);if(role==='host'&&match&&!launchClients){launchClients=true;launch('client1',match[1]);launch('client2',match[1]);}});
  child.stderr.on('data',data=>{output+=data;process.stderr.write(`${role}: ${data}`);});
  child.done=new Promise(resolveDone=>child.on('exit',code=>{writeFileSync(resolve(evidence,role+'.log'),output.replace(/ROOM_TEST_CODE [A-Z2-9]+/g,'ROOM_TEST_CODE [redacted]'));let report=null;try{report=JSON.parse(output.match(/ROOM_WAN_RESULT (.+)/)?.[1]||'null');}catch{}const complete=mode==='wan'?report?.ok:output.includes('ROOM_RPC_PASS');resolveDone({role,code,report,pass:code===0&&complete&&!/SCRIPT ERROR|ERROR:|WARNING:/.test(output)});}));return child;
 }
 let result=[];const timeout=setTimeout(()=>{for(const child of children)child.kill();},25000);
 try{const host=launch('host');result.push(await host.done);for(const child of children)if(child!==host)result.push(await child.done);}finally{clearTimeout(timeout);for(const child of children)if(child.exitCode===null)child.kill();if(proxy)await proxy.close();if(relay)await relay.close();}
 const after=hash(implementation);
 const clientHashAfter=clientPack?hash(clientPack):null;
 const scope=endpoint?'Three native Godot processes on one PC through a public WSS endpoint; not separate-household or full-match evidence':mode==='wan'?'Three native Godot processes, loopback TCP byte-stream delay40..60ms per direction on both relay legs, one1.2s downstream stall; not TCP packet-loss emulation, real internet, or performance proof':'Three native Godot processes and one loopback WebSocket relay; not internet or performance proof';
 const receipt={ok:result.length===3&&result.every(r=>r.pass)&&before===after&&clientHashBefore===clientHashAfter&&(!proxy||proxy.stats.peakDirectionBytes<=1048576),scope,endpoint,pack,client_pack:clientPack,client_pack_sha256_before:clientHashBefore,client_pack_sha256_after:clientHashAfter,native_macos_execution:false,implementation_sha256_before:before,implementation_sha256_after:after,external_probe_sha256:hash(probe),local_relay_source_sha256:hash(resolve(import.meta.dirname,'server.mjs')),results:result,proxy:proxy?.stats,relay:relay?.stats};
 writeFileSync(resolve(evidence,mode==='wan'?'wan-result.json':'rpc-result.json'),JSON.stringify(receipt,null,2));console.log(JSON.stringify(receipt));console.log(`EVIDENCE ${evidence}`);process.exitCode=receipt.ok?0:1;
}
