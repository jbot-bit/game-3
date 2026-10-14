"""Execute the immutable public release on an actual macOS runner. Never re-sign it."""
import hashlib
import json
import platform
import subprocess
import urllib.request
from pathlib import Path

base = Path('build/native-mac-audit').resolve()
base.mkdir(parents=True, exist_ok=True)
receipt = {'platform': platform.platform(), 'architecture': platform.machine(),
           'actualChildMac': False, 'checks': {}}

def command(label, args, timeout=60):
    try:
        r = subprocess.run(args, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                           timeout=timeout, text=True)
        (base / (label + '.log')).write_text(r.stdout)
        ok = r.returncode == 0 and 'SCRIPT ERROR' not in r.stdout and 'ERROR:' not in r.stdout
        receipt['checks'][label] = {'passed': ok, 'exitCode': r.returncode}
        print(label, r.returncode, r.stdout[-3000:], flush=True)
        if not ok:
            raise RuntimeError(label + ' FAILED')
    except subprocess.TimeoutExpired as e:
        receipt['checks'][label] = {'passed': False, 'timeout': timeout}
        (base / (label + '.log')).write_bytes(e.stdout or b'')
        raise

def download(url, filename, sha):
    path = base / filename
    urllib.request.urlretrieve(url, path)
    actual = hashlib.sha256(path.read_bytes()).hexdigest()
    if actual != sha:
        raise RuntimeError(filename + ' hash mismatch: ' + actual)
    receipt[filename] = actual
    return path

try:
    archive = download('https://media.githubusercontent.com/media/jbot-bit/game-3/5e957e0928492028b6788b0dbde5b3cf3651034d/CrownCourt-macOS.zip',
                       'CrownCourt-macOS.zip', '0ce9e6c454b7134426f662977584209e6117870c9b535a098e053e879ad82ce9')
    command('extract', ['ditto', '-x', '-k', str(archive), str(base / 'app')])
    app = base / 'app/Crown Court.app'
    executable = str(app / 'Contents/MacOS/Crown Court')
    command('signature', ['codesign', '--verify', '--deep', '--strict', '--verbose=2', str(app)])
    command('headless-startup', [executable, '--headless', '--quit-after', '180'])
    command('graphical-startup', [executable, '--quit-after', '180'])
    editor = download('https://github.com/godotengine/godot-builds/releases/download/4.7.2-stable/Godot_v4.7.2-stable_macos.universal.zip',
                      'Godot-macOS.zip', 'c58a24e31d720be9d62f60cb5627c4e695fb72f21b0cfe1bc9ccaa9a3b3ba63e')
    command('extract-engine', ['ditto', '-x', '-k', str(editor), str(base / 'engine')])
finally:
    (base / 'native-release.json').write_text(json.dumps(receipt, indent=2) + '\n')
