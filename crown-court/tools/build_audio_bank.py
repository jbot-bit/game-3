"""Build the small CC0 sample bank from retained, hashed upstream archives.

No provider calls or generated tones. Sources stay in build/, and only decoded,
trimmed mono PCM is admitted to the game after validation and hash verification.
"""
import argparse
import array
import hashlib
import json
import math
import os
from pathlib import Path
import shutil
import subprocess
import wave

ROOT = Path(__file__).resolve().parents[2]
STAGE = ROOT / 'build/crown-court-audio-v7'
DEST = ROOT / 'crown-court/assets/audio'

def resolve_ffmpeg(override=''):
    if override:
        path = Path(override).expanduser()
        if path.is_file():
            return path.resolve()
        command = shutil.which(override)
        if command:
            return Path(command).resolve()
        raise FileNotFoundError(f'FFmpeg override was not found: {override}')
    command = shutil.which('ffmpeg')
    if command:
        return Path(command).resolve()
    local_app_data = os.environ.get('LOCALAPPDATA')
    if local_app_data:
        packages = Path(local_app_data) / 'Microsoft/WinGet/Packages'
        candidates = [exe for package in packages.glob('*FFmpeg*') if package.is_dir()
                      for exe in package.rglob('ffmpeg.exe') if exe.is_file()]
        if candidates:
            return max(candidates, key=lambda exe: (exe.stat().st_mtime_ns, str(exe))).resolve()
    raise FileNotFoundError('FFmpeg was not found. Install it on PATH or pass --ffmpeg with its executable path.')


parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--ffmpeg', default=os.environ.get('FFMPEG', ''), help='FFmpeg executable path or command (default: PATH, then current-user WinGet).')
FFMPEG = resolve_ffmpeg(parser.parse_args().ffmpeg)
RATE = 44100
SOURCES = {
    'impact': {'archive': 'kenney_impact-sounds.zip', 'author': 'Kenney', 'url': 'https://kenney.nl/assets/impact-sounds', 'license': 'CC0-1.0'},
    'interface': {'archive': 'kenney_interface-sounds.zip', 'author': 'Kenney', 'url': 'https://kenney.nl/assets/interface-sounds', 'license': 'CC0-1.0'},
    'swishes': {'archive': 'swishes.zip', 'author': 'artisticdude', 'url': 'https://opengameart.org/content/swishes-sound-pack', 'license': 'CC0-1.0'},
}

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def decode(path):
    pcm = subprocess.check_output([str(FFMPEG), '-v', 'error', '-i', str(path), '-ac', '1', '-ar', str(RATE), '-f', 's16le', '-'])
    return array.array('h', pcm)

def make_sample(source, duration, cutoff):
    raw = decode(source)
    peak = max(abs(x) for x in raw)
    assert peak > 100, f'Silent source: {source}'
    # Retain a short lead-in; remove source silence without chopping the attack.
    onset = next(i for i, x in enumerate(raw) if abs(x) > peak * .045)
    begin = max(0, onset - int(.003 * RATE))
    raw = raw[begin:begin + int(duration * RATE)]
    # A one-pole low-pass reduces brittle high-frequency clicks in close impacts.
    coefficient = 1 - math.exp(-2 * math.pi * cutoff / RATE)
    filtered, previous = [], 0.0
    for value in raw:
        previous += coefficient * (value - previous)
        filtered.append(previous)
    gain = .63 * 32767 / max(abs(x) for x in filtered)
    count = len(filtered)
    fade = min(int(.05 * RATE), count // 4)
    output = array.array('h')
    for i, value in enumerate(filtered):
        attack = min(1., i / (RATE * .0015))
        release = min(1., (count - 1 - i) / max(1, fade))
        output.append(round(value * gain * attack * release))
    return output, begin / RATE

# A short material-specific transient, not a long pitched cue for every action.
specs = []
for number in range(3):
    specs.extend([
        (f'ball_{number}', 'impact', f'impactSoft_heavy_00{number}.ogg', .26, 4200),
        (f'catch_{number}', 'impact', f'impactSoft_medium_00{number}.ogg', .14, 3800),
        (f'body_{number}', 'impact', f'impactPunch_medium_00{number}.ogg', .22, 3500),
        (f'step_{number}', 'impact', f'footstep_carpet_00{number}.ogg', .14, 3200),
        (f'rim_{number}', 'impact', f'impactMetal_light_00{number}.ogg', .25, 5000),
        (f'air_{number}', 'swishes', f'swish-{number + 10}.wav', .25, 6500),
    ])
specs.extend([
    ('score', 'impact', 'impactBell_heavy_000.ogg', .48, 4200),
    ('tick', 'interface', 'tick_001.ogg', .10, 3600),
    ('go', 'interface', 'confirmation_001.ogg', .32, 4800),
])

package = STAGE / 'validated-bank'
package.mkdir(exist_ok=True)
manifest = {'version': 1, 'license': 'CC0-1.0', 'sources': SOURCES, 'files': [], 'human_listening_approval': False,
            'tool_boundary': 'Game Development Studio 1.5 capabilities support GLB inspection/packages, not WAV admission. This audio-only package uses ffmpeg decoding and explicit PCM/hash validation.'}
for source in SOURCES.values():
    source['archive_sha256'] = sha(STAGE / source['archive'])
for name, family, filename, duration, cutoff in specs:
    matches = [p for p in (STAGE / family).rglob(filename) if '__MACOSX' not in str(p)]
    assert len(matches) == 1, (family, filename, matches)
    source = matches[0]
    samples, trim = make_sample(source, duration, cutoff)
    path = package / (name + '.wav')
    with wave.open(str(path), 'wb') as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(RATE)
        wav.writeframes(samples.tobytes())
    peak = max(abs(x) for x in samples) / 32768
    rms = math.sqrt(sum(x*x for x in samples) / len(samples)) / 32768
    assert .04 < peak <= .631 and rms > .001 and samples[0] == samples[-1] == 0
    manifest['files'].append({'file': path.name, 'sha256': sha(path), 'source_family': family,
        'source_file': filename, 'source_sha256': sha(source), 'trim_start_seconds': trim,
        'lowpass_hz': cutoff, 'sample_rate': RATE, 'channels': 1, 'bits': 16,
        'seconds': len(samples) / RATE, 'peak': peak, 'rms': rms})
manifest_path = package / 'manifest.json'
manifest_path.write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
license_text = 'Crown Court sample bank\n\nAll source samples: Creative Commons Zero 1.0 (CC0-1.0).\nhttps://creativecommons.org/publicdomain/zero/1.0/\n\n'
for source in SOURCES.values():
    license_text += source['author'] + ': ' + source['url'] + '\n'
license_text += '\nAdaptations: mono conversion, onset trim, low-pass, level and edge fades.\nSource archives and per-file digests are recorded in manifest.json.\nNo Crown Jam audio or other proprietary game assets are included.\n'
(package / 'LICENSE.txt').write_text(license_text, encoding='utf-8')
# Verify the entire media roster before copying it into the game.
assert {p.name for p in package.glob('*.wav')} == {f['file'] for f in manifest['files']}
for entry in manifest['files']:
    assert sha(package / entry['file']) == entry['sha256']
DEST.mkdir(parents=True, exist_ok=True)
for path in package.iterdir():
    if path.is_file():
        target = DEST / path.name
        if target.exists():
            assert sha(target) == sha(path), f'Refusing to replace different admitted bytes: {target}'
        else:
            shutil.copyfile(path, target)
        assert sha(target) == sha(path)
print(json.dumps({'passed': True, 'samples': len(manifest['files']), 'destination': str(DEST),
                  'manifest_sha256': sha(DEST / 'manifest.json'), 'total_wav_bytes': sum(p.stat().st_size for p in DEST.glob('*.wav'))}))
