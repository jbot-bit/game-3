"""Two native Mac UI clients join an independently running Windows test host."""
import json
import os
import platform
import subprocess
from pathlib import Path

base = Path('build/native-mac-audit').resolve()
engine = base / 'engine/Godot.app/Contents/MacOS/Godot'
pack = base / 'app/Crown Court.app/Contents/Resources/Crown Court.pck'
probe = Path('crown-court/relay/lobby_discovery_probe.gd').resolve()
jobs = []
results = []
try:
    for role in ('client1', 'client2'):
        args = [str(engine), '--headless', '--max-fps', '60', '--main-pack', str(pack),
                '--script', str(probe), '--', 'role='+role,
                'label='+os.environ['TEST_HOST_LABEL'], 'url=wss://direct-metro.bnr.la/rooms']
        log = (base / ('cross-'+role+'.log')).open('w')
        jobs.append((role, subprocess.Popen(args, stdout=log, stderr=subprocess.STDOUT), log))
    for role, process, log in jobs:
        code = process.wait(timeout=140)
        log.close()
        output = (base / ('cross-'+role+'.log')).read_text()
        print(role, output, flush=True)
        results.append({'role': role, 'exitCode': code, 'passed': code == 0 and
                        'ROOM_RPC_PASS' in output and 'ERROR:' not in output})
finally:
    for role, process, log in jobs:
        if process.poll() is None:
            process.kill()
            process.wait()
        log.close()
    receipt = {'platform': platform.platform(), 'architecture': platform.machine(),
               'hostLabel': os.environ['TEST_HOST_LABEL'], 'results': results,
               'scope': 'Two native Mac clients in GitHub hosted macOS join a separate Windows host over public WSS'}
    (base / 'cross-platform.json').write_text(json.dumps(receipt, indent=2)+'\n')
assert len(results) == 2 and all(r['passed'] for r in results), receipt
