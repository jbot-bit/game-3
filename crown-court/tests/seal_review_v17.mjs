import fs from 'node:fs/promises';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
const project=path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const raw=path.resolve(project,'../build/crown-court-evidence/v17-presentation-final');
const pack=path.resolve(project,'../build/crown-court-0.17.0/CrownCourt.exe');
const {GAME_DEV_RUN_DIR:out,GAME_DEV_RUN_ID:runId,GAME_DEV_ADAPTER_ID:adapterId,GAME_DEV_SCENARIO_ID:scenarioId}=process.env;
if(!out||!runId)throw Error('Game Development Studio run context required');
const frames=[];
for(const label of ['intro-flyover','intro-card','lineup','kickoff-flight','live-play','score-slowmo','score-cam','score-lineup','fulltime-cam','fulltime-card']) {
 const file=`presentation-${label}.png`;
 await fs.copyFile(path.join(raw,file),path.join(out,file));
 frames.push({index:frames.length,label,attachments:[{kind:'color',path:file,encoding:'png'}]});
}
const packSha256=crypto.createHash('sha256').update(await fs.readFile(pack)).digest('hex');
await fs.writeFile(path.join(out,'provenance.json'),JSON.stringify({raw,pack,packSha256,kind:'Controlled native presentation fixtures, full cinematics enabled; not ordinary gameplay or enjoyment evidence.'},null,2));
frames[0].attachments.push({kind:'custom',label:'provenance',path:'provenance.json',encoding:'json'});
await fs.writeFile(process.env.GAME_DEV_CAPTURE_MANIFEST??path.join(out,'capture.json'),JSON.stringify({schema:'game_dev.capture.v1',runId,adapterId,scenarioId,sourceFormat:'game-dev-capture-v1',frames,measurements:[],adapterEvidence:{rendererClass:'unknown',windowless:true,graphicsApi:'cpu-import',gpuExecutionReported:false,gpuCompletionIdentityReported:false,hardwarePerformanceReported:false,pixelVisualInspectionPerformed:false,notes:['Seals retained native Godot screenshots; does not execute renderer.']}},null,2));
