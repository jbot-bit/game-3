import fs from 'node:fs/promises';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';
const project=path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const phase=process.argv[2];
if(!['baseline','candidate'].includes(phase)) throw Error('Unknown phase');
const raw=path.resolve(project,'../build/crown-court-evidence/motion-poses');
const {GAME_DEV_RUN_DIR:out,GAME_DEV_RUN_ID:runId,GAME_DEV_ADAPTER_ID:adapterId,GAME_DEV_SCENARIO_ID:scenarioId}=process.env;
if(!out||!runId) throw Error('Game Development Studio context required');
const report=JSON.parse(await fs.readFile(path.join(raw,'result.json')));
if(!report.passed)throw Error('Passing native capture required');
const frames=[];
for(const [index,side] of [-1,1].entries()){
 const name=`goal-${phase==='baseline'?'obstructed':'clearance'}-${side}.png`;
 const data=await fs.readFile(path.join(raw,name));
 const file=`goal-${side}.png`; await fs.writeFile(path.join(out,file),data);
 frames.push({index,label:`goal-${side}`,attachments:[{kind:'color',path:file,encoding:'png',description:'Same native scene, actor and intended camera boom; camera constraint off versus on.'}]});
}
const sha=x=>crypto.createHash('sha256').update(x).digest('hex');
await fs.writeFile(path.join(out,'provenance.json'),JSON.stringify({phase,raw,report,world_sha256:sha(await fs.readFile(path.join(project,'world.gd'))),fixture_sha256:sha(await fs.readFile(path.join(project,'tests/motion_polish.gd'))),limits:['CPU import of actual retained native Godot screenshots; no new GPU execution by this adapter.','Matched controlled camera intervention; no performance or original-game equivalence claim.']},null,2));
frames[0].attachments.push({kind:'custom',label:'provenance',path:'provenance.json',encoding:'json'});
await fs.writeFile(process.env.GAME_DEV_CAPTURE_MANIFEST??path.join(out,'capture.json'),JSON.stringify({schema:'game_dev.capture.v1',runId,adapterId,scenarioId,sourceFormat:'game-dev-capture-v1',frames,measurements:[],adapterEvidence:{rendererClass:'unknown',windowless:true,graphicsApi:'cpu-import',gpuExecutionReported:false,gpuCompletionIdentityReported:false,hardwarePerformanceReported:false,pixelVisualInspectionPerformed:false,notes:['Seals native frames; root visual inspection is recorded separately.']}},null,2));
