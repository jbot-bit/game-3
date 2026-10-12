import { spawn } from 'node:child_process';
import { resolve } from 'node:path';
import { createRelay } from './server.mjs';
const root=resolve(import.meta.dirname,'../..');
const relay=createRelay({port:30220});await relay.listen();
const child=spawn(resolve(root,'.tools/godot/Godot_v4.7.2-stable_win64_console.exe'),['--headless','--path',resolve(root,'crown-court'),'--script','res://relay/room_lifecycle_probe.gd'],{windowsHide:true,stdio:'inherit'});
const timeout=setTimeout(()=>child.kill(),10000);
const code=await new Promise(resolve=>child.on('exit',resolve));clearTimeout(timeout);await relay.close();process.exit(code===0?0:1);
