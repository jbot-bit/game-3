import fs from 'node:fs/promises';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
const project=path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const phase=process.argv[2];
if(!['baseline','candidate'].includes(phase))throw Error('Unknown phase');
const raw=path.resolve(project,'../build/crown-court-evidence/camera-v15-native-'+(phase==='baseline'?'before':'after'));
const {GAME_DEV_RUN_DIR:out,GAME_DEV_RUN_ID:runId,GAME_DEV_ADAPTER_ID:adapterId,GAME_DEV_SCENARIO_ID:scenarioId}=process.env;
if(!out||!runId)throw Error('Game Development Studio context required');
const world=phase==='baseline'?path.resolve(project,'../build/crown-court-evidence/camera-v15-baseline-world.gd'):path.join(project,'world.gd');
const worldSha256=crypto.createHash('sha256').update(await fs.readFile(world)).digest('hex');
const frames=[];
for(const label of ['wall-grazing','wall-outward','corner-grazing','corner-outward']) {
 await fs.copyFile(path.join(raw,label+'.png'),path.join(out,label+'.png'));
 frames.push({index:frames.length,label,attachments:[{kind:'color',path:label+'.png',encoding:'png'}]});
}
await fs.writeFile(path.join(out,'provenance.json'),JSON.stringify({phase,raw,worldSha256,scenario:'Same stationary wall/corner positions, yaw, 1280x800, native Godot Compatibility renderer; no performance comparison.'},null,2));
frames[0].attachments.push({kind:'custom',label:'provenance',path:'provenance.json',encoding:'json'});
await fs.writeFile(process.env.GAME_DEV_CAPTURE_MANIFEST??path.join(out,'capture.json'),JSON.stringify({schema:'game_dev.capture.v1',runId,adapterId,scenarioId,sourceFormat:'game-dev-capture-v1',frames,measurements:[],adapterEvidence:{rendererClass:'unknown',windowless:true,graphicsApi:'cpu-import',gpuExecutionReported:false,gpuCompletionIdentityReported:false,hardwarePerformanceReported:false,pixelVisualInspectionPerformed:false,notes:['Seals retained native Godot screenshots; does not execute renderer.']}},null,2));
