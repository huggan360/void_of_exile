#!/usr/bin/env python3
"""Fit each supplied death rumble's start-to-peak build without changing pitch."""
from __future__ import annotations

import array
import json
import re
import wave

from import_audio import OUT, RATE, ROOT, run


def import_rumbles():
    manifest_path = OUT / 'manifest.json'
    manifest = json.loads(manifest_path.read_text())
    # Cover every authored boss duration, including the BossDef default.
    durations = {float(value) for folder in ('scripts/enemies', 'scripts/dungeons')
                 for path in (ROOT / folder).rglob('*.gd')
                 for value in re.findall(r'\bdeath_time\s*(?::=|=)\s*([\d.]+)', path.read_text())}
    destination = OUT / 'sfx' / 'death_rumbles'
    destination.mkdir(parents=True, exist_ok=True)
    stats = []
    for duration in sorted(durations):
        paths = []
        for source in sorted((OUT / 'sfx').glob('boss_kill_rumble_riser_*.wav')):
            with wave.open(str(source)) as stream:
                rate = stream.getframerate()
                assert stream.getnchannels() == 1 and stream.getsampwidth() == 2
                samples = array.array('h', stream.readframes(stream.getnframes()))
            window = round(rate * .04)
            energies = [sum(x*x for x in samples[i:i+window]) / window
                        for i in range(0, len(samples)-window, window)]
            peak = (max(range(len(energies)), key=energies.__getitem__) + 1) * window / rate
            target = destination / f'{source.stem}_{round(duration*1000)}ms.wav'
            filters = [f'atrim=end={peak:.6f}', 'asetpts=PTS-STARTPTS',
                       f'rubberband=tempo={peak/duration:.9f}:pitch=1:pitchq=quality',
                       'apad', f'atrim=duration={duration}',
                       'afade=t=in:st=0:d=0.005',
                       f'afade=t=out:st={duration-.012:.6f}:d=0.012']
            run(['ffmpeg', '-y', '-v', 'error', '-i', str(source), '-af', ','.join(filters),
                 '-ar', str(RATE), '-ac', '1', '-c:a', 'pcm_s16le', str(target)])
            paths.append('res://' + str(target.relative_to(ROOT)))
            stats.append({'source': str(source.relative_to(ROOT)), 'output': str(target.relative_to(ROOT)),
                          'start_s': 0, 'peak_end_s': round(peak, 3), 'duration_s': duration, 'pitch': 1.0})
        manifest['events'][f'combat.boss_rumble_{round(duration*1000)}ms'] = {
            'paths': paths, 'gain_db': -5, 'pitch_variance': 0, 'positional': True, 'loop': False}
    manifest['processing']['boss_death_rumbles'] = {
        'method': 'Start through the strongest 40 ms RMS peak; Rubber Band tempo fit with pitch=1; no runtime seeking or repitching',
        'durations_s': sorted(durations), 'variants': stats}
    manifest_path.write_text(json.dumps(manifest, indent=2) + '\n')
    print(f'Baked {len(stats)} boss death builds at {sorted(durations)} seconds, original pitch')


if __name__ == '__main__':
    import_rumbles()
