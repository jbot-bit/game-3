import net from 'node:net';
import { performance } from 'node:perf_hooks';
// TCP stream impairment, not packet loss: preserve byte order while delaying
// each direction 40..60ms and holding downstream bytes during one 1.2s stall.
export function tcpImpairment({port=30221,target=30220,stallStartMs=1800,stallEndMs=3000}={}){
 const started=performance.now(),sockets=new Set(),timers=new Set();
 const stats={connections:0,peakQueuedBytes:0,peakDirectionBytes:0,deliveredBytes:0,stallStartMs,stallEndMs,oneWayDelayMs:[40,60],droppedBytes:0};
 let totalQueued=0,ordinal=0;
 const server=net.createServer(client=>{
  stats.connections++;const upstream=net.connect({host:'127.0.0.1',port:target});
  sockets.add(client);sockets.add(upstream);client.setNoDelay(true);upstream.setNoDelay(true);
  function pipe(source,destination,downstream){let lastDue=0,queued=0,ended=false,timer=null;const queue=[];
   function pump(){
    if(timer){timers.delete(timer);timer=null;}
    while(queue.length&&queue[0].due<=performance.now()){
     const item=queue.shift();queued-=item.buffer.length;totalQueued-=item.buffer.length;
     if(!destination.destroyed){destination.write(item.buffer);stats.deliveredBytes+=item.buffer.length;}else stats.droppedBytes+=item.buffer.length;
    }
    if(queue.length){timer=setTimeout(pump,Math.max(1,Math.ceil(queue[0].due-performance.now())));timers.add(timer);}
    else if(ended&&!destination.destroyed)destination.end();
   }
   source.on('data',buffer=>{
    const now=performance.now(),jitter=((++ordinal*17)%21)-10;
    let due=Math.max(now+50+jitter,lastDue);
    if(downstream&&due-started>=stallStartMs&&due-started<stallEndMs)due=started+stallEndMs;
    due=Math.max(due,lastDue);lastDue=due;queued+=buffer.length;totalQueued+=buffer.length;
    stats.peakQueuedBytes=Math.max(stats.peakQueuedBytes,totalQueued);stats.peakDirectionBytes=Math.max(stats.peakDirectionBytes,queued);
    if(queued>1048576){source.destroy(new Error('Test proxy queue exceeded 1 MiB'));destination.destroy();return;}
    queue.push({buffer,due});if(!timer)pump();
   });
   source.on('end',()=>{ended=true;if(!timer)pump();});
  }  pipe(client,upstream,false);pipe(upstream,client,true);
  client.on('error',()=>upstream.destroy());upstream.on('error',()=>client.destroy());
  client.on('close',()=>{sockets.delete(client);upstream.destroy();});upstream.on('close',()=>{sockets.delete(upstream);client.destroy();});
 });
 return{stats,listen:()=>new Promise(resolve=>server.listen(port,'127.0.0.1',resolve)),close:()=>new Promise(resolve=>{for(const timer of timers)clearTimeout(timer);for(const socket of sockets)socket.destroy();server.close(resolve);})};
}

