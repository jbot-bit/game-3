"""Verify the public DMG and its app without changing signing or quarantine rules."""
import hashlib
import json
import os
import platform
import subprocess
import time
import urllib.request
from pathlib import Path

base = Path('build/installer-audit').resolve()
base.mkdir(parents=True, exist_ok=True)
manifest = json.loads(Path('crown-court/release-evidence/0.17.0-internet/current-packages.json').read_text())
receipt = {'platform': platform.platform(), 'architecture': platform.machine(),
           'physicalChildMac': False, 'notarized': False, 'checks': {}}
mount = base / 'mounted'
process = None
mounted = False
try:
    dmg = base / 'CrownCourt.dmg'
    urllib.request.urlretrieve(f'https://media.githubusercontent.com/media/jbot-bit/game-3/{os.environ["GITHUB_SHA"]}/CrownCourt.dmg', dmg)
    actual = hashlib.sha256(dmg.read_bytes()).hexdigest().upper()
    assert actual == manifest['macDmgSha256'], 'DMG hash mismatch'
    receipt['sha256'] = actual
    subprocess.run(['hdiutil', 'verify', str(dmg)], check=True, timeout=45)
    subprocess.run(['hdiutil', 'attach', '-readonly', '-nobrowse', '-mountpoint', str(mount), str(dmg)], check=True, timeout=45)
    mounted = True
    app = mount / 'Crown Court.app'
    assert (mount / 'Applications').is_symlink()
    subprocess.run(['codesign', '--verify', '--deep', '--strict', str(app)], check=True, timeout=30)
    receipt['checks']['installerStructureAndSignature'] = True
    exe = str(app / 'Contents/MacOS/Crown Court')
    headless = subprocess.run([exe, '--headless', '--quit-after', '30'], capture_output=True, text=True, timeout=60)
    (base / 'headless.log').write_text(headless.stdout + headless.stderr)
    assert headless.returncode == 0 and 'ERROR:' not in headless.stdout+headless.stderr
    receipt['checks']['nativeHeadless'] = True
    # A deliberately small-window diagnostic for the software-rendered Intel VM.
    # This is NOT the normal-resolution startup/performance acceptance test.
    log = (base / 'graphical-small-window.log').open('w')
    start = time.monotonic()
    process = subprocess.Popen([exe, '--verbose', '--resolution', '640x400', '--quit-after', '3'], stdout=log, stderr=subprocess.STDOUT)
    try:
        process.wait(timeout=45)
    except subprocess.TimeoutExpired:
        subprocess.run(['screencapture', '-x', str(base / 'screen-at-45-seconds.png')], timeout=15)
        process.wait(timeout=135)
    finally:
        log.close()
    output = (base / 'graphical-small-window.log').read_text()
    receipt['checks']['smallWindowThreeFrames'] = process.returncode == 0 and 'ERROR:' not in output
    receipt['graphicalSeconds'] = time.monotonic()-start
    assert receipt['checks']['smallWindowThreeFrames']
except Exception as error:
    receipt['error'] = str(error)
    raise
finally:
    if process is not None and process.poll() is None:
        process.kill()
        process.wait()
    if mounted:
        subprocess.run(['hdiutil', 'detach', str(mount)], timeout=30)
    (base / 'receipt.json').write_text(json.dumps(receipt, indent=2)+'\n')
