import json,os,platform,subprocess
from pathlib import Path
base=Path('build/native-mac-audit').resolve()
engine=base/'engine/Godot.app/Contents/MacOS/Godot'
pack=base/'app/Crown Court.app/Contents/Resources/Crown Court.pck'
script=Path('crown-court/relay/cross_platform_match.gd').resolve()
code=os.environ['TEST_ROOM_CODE'];assert len(code)==26 and code.isalnum()
jobs=[];results=[]
try:
    for index in range(2):
        folder=base/('intel-match-'+str(index));folder.mkdir()
        log=(folder/'game.log').open('w')
        args=['arch','-x86_64',str(engine),'--max-fps','60','--main-pack',str(pack),'--script',str(script)]
        if index==1:args+=['--headless']
        args+=['--','--room-url=wss://direct-metro.bnr.la/rooms','--room-code='+code,'--evidence-dir='+str(folder),'--max-seconds=600']
        jobs.append((subprocess.Popen(args,stdout=log,stderr=subprocess.STDOUT),log,folder))
    for process,log,folder in jobs:
        rc=process.wait(timeout=650);log.close()
        summary=json.loads((folder/'peer.json').read_text())['summary']
        results.append({'exitCode':rc,'summary':summary})
        assert rc==0 and summary['completed'] and summary['reward_correct'] and summary['peak_roster']==3
    render=json.loads((base/'intel-match-0/rendering.json').read_text())
    assert render['features_x86_64'] and render['frames']>100 and render['captures']>=2
finally:
    for process,log,folder in jobs:
        if process.poll() is None:process.kill();process.wait()
        log.close()
    (base/'rosetta-match.json').write_text(json.dumps({'hostPlatform':platform.platform(),'executedArchitecture':'x86_64 via Rosetta','physicalIntelHardware':False,'results':results},indent=2)+'\n')
