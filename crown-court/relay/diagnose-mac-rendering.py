import hashlib,json,os,platform,subprocess,time,urllib.request
from pathlib import Path
base=Path('build/mac-render-diagnosis').resolve();base.mkdir(parents=True,exist_ok=True)
manifest=json.loads(Path('crown-court/release-evidence/0.17.0-internet/current-packages.json').read_text())
def fetch(url,name,sha):
    path=base/name;urllib.request.urlretrieve(url,path)
    assert hashlib.sha256(path.read_bytes()).hexdigest()==sha.lower()
    return path
archive=fetch(f'https://media.githubusercontent.com/media/jbot-bit/game-3/{os.environ["GITHUB_SHA"]}/CrownCourt-macOS.zip','game.zip',manifest['macZipSha256'])
engine_zip=fetch('https://github.com/godotengine/godot-builds/releases/download/4.7.2-stable/Godot_v4.7.2-stable_macos.universal.zip','engine.zip','c58a24e31d720be9d62f60cb5627c4e695fb72f21b0cfe1bc9ccaa9a3b3ba63e')
subprocess.run(['ditto','-x','-k',str(archive),str(base/'app')],check=True)
subprocess.run(['ditto','-x','-k',str(engine_zip),str(base/'engine')],check=True)
app=base/'app/Crown Court.app';exe=app/'Contents/MacOS/Crown Court';pack=app/'Contents/Resources/Crown Court.pck'
engine=base/'engine/Godot.app/Contents/MacOS/Godot'
results=[]
def run(label,args,timeout=90):
    log=(base/(label+'.log')).open('w');start=time.monotonic()
    p=subprocess.Popen(args,stdout=log,stderr=subprocess.STDOUT)
    try:
        code=p.wait(timeout=timeout)
        results.append({'label':label,'exitCode':code,'seconds':time.monotonic()-start})
    except subprocess.TimeoutExpired:
        subprocess.run(['screencapture','-x',str(base/(label+'-timeout.png'))],timeout=15)
        results.append({'label':label,'timeout':timeout})
    finally:
        if p.poll() is None:p.kill();p.wait()
        log.close()
    print(results[-1],flush=True)
try:
    if platform.machine()=='arm64':
        run('intel-binary-rosetta-default',['arch','-x86_64',str(exe),'--verbose','--quit-after','30'],120)
        run('intel-binary-rosetta-angle',['arch','-x86_64',str(exe),'--verbose','--rendering-driver','opengl3_angle','--quit-after','30'],120)
    else:
        probe=Path('crown-court/relay/mac_render_probe.gd').resolve()
        for mode in ['minimal','no-scenery','full']:
            run(mode,[str(engine),'--main-pack',str(pack),'--script',str(probe),'--','mode='+mode,'output='+str(base/mode)])
finally:
    (base/'diagnosis.json').write_text(json.dumps({'platform':platform.platform(),'results':results},indent=2)+'\n')
