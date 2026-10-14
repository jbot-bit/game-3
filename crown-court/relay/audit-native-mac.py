"""Execute the immutable public release on an actual macOS runner. Never re-sign it."""
import hashlib
import json
import platform
import os
import subprocess
import time
import urllib.request
from pathlib import Path

base = Path('build/native-mac-audit').resolve()
base.mkdir(parents=True, exist_ok=True)
receipt = {'platform': platform.platform(), 'architecture': platform.machine(),
           'actualChildMac': False, 'checks': {}}

def command(label, args, timeout=60):
    start = time.monotonic()
    try:
        p = subprocess.Popen(args, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        output, _ = p.communicate(timeout=timeout)
        (base / (label + '.log')).write_text(output)
        ok = p.returncode == 0 and 'SCRIPT ERROR' not in output and 'ERROR:' not in output
        receipt['checks'][label] = {'passed': ok, 'exitCode': p.returncode, 'seconds': time.monotonic()-start}
        print(label, p.returncode, output[-3000:], flush=True)
        if not ok:
            raise RuntimeError(label + ' FAILED')
    except subprocess.TimeoutExpired as e:
        receipt['checks'][label] = {'passed': False, 'timeout': timeout}
        try:
            subprocess.run(['sample', str(p.pid), '1', '10', '-file', str(base / (label+'-sample.log'))], timeout=90)
        finally:
            p.kill()
            p.communicate()
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
    manifest = json.loads(Path('crown-court/release-evidence/0.17.0-internet/current-packages.json').read_text())
    commit = os.environ['GITHUB_SHA']
    archive = download(f'https://media.githubusercontent.com/media/jbot-bit/game-3/{commit}/CrownCourt-macOS.zip',
                       'CrownCourt-macOS.zip', manifest['macZipSha256'].lower())
    command('extract', ['ditto', '-x', '-k', str(archive), str(base / 'app')])
    app = base / 'app/Crown Court.app'
    executable = str(app / 'Contents/MacOS/Crown Court')
    command('signature', ['codesign', '--verify', '--deep', '--strict', '--verbose=2', str(app)])
    command('headless-startup', [executable, '--headless', '--quit-after', '180'])
    command('display-hardware', ['system_profiler', 'SPDisplaysDataType'])
    try:
        # Launch the owned executable so a timeout samples and kills the game,
        # not the LaunchServices wrapper (which can leave the game running).
        command('graphical-startup', [executable, '--verbose', '--quit-after', '30', '--log-file', str(base / 'game-native.log')], timeout=90)
        native_log = (base / 'game-native.log').read_text()
        if 'Godot Engine' not in native_log or 'ERROR:' in native_log or 'SCRIPT ERROR' in native_log:
            receipt['checks']['graphical-startup']['passed'] = False
            raise RuntimeError('Native launch log failed')
    except (RuntimeError, subprocess.TimeoutExpired):
        # Preserve the failure, but still investigate native network support.
        print('FAIL: default graphical startup; continuing independent network diagnostics', flush=True)
        try:
            command('graphical-angle-diagnostic', [executable, '--verbose', '--rendering-driver', 'opengl3_angle', '--quit-after', '30'], timeout=90)
        except (RuntimeError, subprocess.TimeoutExpired):
            print('FAIL: explicit ANGLE diagnostic too', flush=True)
    editor = download('https://github.com/godotengine/godot-builds/releases/download/4.7.2-stable/Godot_v4.7.2-stable_macos.universal.zip',
                      'Godot-macOS.zip', 'c58a24e31d720be9d62f60cb5627c4e695fb72f21b0cfe1bc9ccaa9a3b3ba63e')
    command('extract-engine', ['ditto', '-x', '-k', str(editor), str(base / 'engine')])
finally:
    (base / 'native-release.json').write_text(json.dumps(receipt, indent=2) + '\n')
