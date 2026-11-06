#!/usr/bin/env python3
"""Bake NPC voices without modifying the source MP3s or existing game effects."""
from __future__ import annotations

import json
import pathlib
import shutil
import tempfile

from import_audio import OUT, RATE, ROOT, SOURCE, leading_trim, peak_db, probe, run

TEMPO = 1.5
PITCH = 1.3  # About 4.5 semitones, independent of the speaking speed.
GROUPS = {
    'angry': ['minion_angry', 'minion_angry2', 'minion_angry3'],
    'cheering': ['minion_chearing'],
    'curious': ['minion_curious', 'minion_curious2', 'minion_curious3'],
    'excited': ['minion_exited1', 'minion_exited2', 'minion_exited3'],
    'gasp': ['minion_gasps'],
    'laugh': ['minion_laughtojoke'],
    'joking': ['minion_really_joking'],
    'sad': ['minion_sad'],
    'scream': ['minion_screems'],
    'surprised': ['minion_surprised'],
}


def import_voices():
    if not shutil.which('ffmpeg') or not shutil.which('ffprobe'):
        raise SystemExit('ffmpeg and ffprobe are required')
    if 'rubberband' not in run(['ffmpeg', '-hide_banner', '-filters']).stdout:
        raise SystemExit('ffmpeg with the Rubber Band filter is required')
    manifest_path = OUT / 'manifest.json'
    manifest = json.loads(manifest_path.read_text())
    stats = [s for s in manifest['process_stats'] if not s['source'].startswith('minions/')]
    target_dir = OUT / 'voices'
    target_dir.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='void_minion_audio_') as temporary:
        intermediate = pathlib.Path(temporary) / 'voice.wav'
        for mood, names in GROUPS.items():
            paths = []
            for name in names:
                source = SOURCE / 'minions' / (name + '.mp3')
                duration, channels = probe(source)
                trim = leading_trim(source)
                # Work in float PCM until final normalization. High quality
                # resampling/time stretching avoids crude sample-rate tricks.
                filters = [f'atrim=start={trim:.5f}', 'asetpts=PTS-STARTPTS',
                           'highpass=f=70', 'lowpass=f=16000',
                           f'rubberband=tempo={TEMPO}:pitch={PITCH}:transients=smooth:detector=soft:pitchq=quality']
                run(['ffmpeg', '-y', '-v', 'error', '-i', str(source), '-af', ','.join(filters),
                     '-ar', str(RATE), '-ac', '1', '-c:a', 'pcm_f32le', str(intermediate)])
                processed_duration, _ = probe(intermediate)
                gain = -3.0 - peak_db(intermediate)
                target = target_dir / (name + '.wav')
                finish = [f'volume={gain:.3f}dB', 'afade=t=in:st=0:d=0.008',
                          f'afade=t=out:st={max(0, processed_duration - .025):.5f}:d=0.025']
                run(['ffmpeg', '-y', '-v', 'error', '-i', str(intermediate), '-af', ','.join(finish),
                     '-ar', str(RATE), '-ac', '1', '-c:a', 'pcm_s16le', str(target)])
                paths.append('res://' + str(target.relative_to(ROOT)))
                stats.append({'source': str(source.relative_to(SOURCE)),
                              'output': str(target.relative_to(ROOT)),
                              'input_duration_s': round(duration, 3), 'leading_trim_s': round(trim, 3),
                              'output_duration_s': round(processed_duration, 3),
                              'input_channels': channels, 'output_channels': 1,
                              'gain_applied_db': round(gain, 2), 'codec': 'pcm_s16le',
                              'tempo': TEMPO, 'pitch': PITCH})
            manifest['events']['voice.minion.' + mood] = {
                'paths': paths, 'gain_db': -8, 'pitch_variance': 0, 'positional': False, 'loop': False}
    manifest['process_stats'] = stats
    manifest['processing']['minion_voices'] = (
        'Mono 48 kHz PCM; Rubber Band quality mode at 1.5x tempo and 1.3x pitch; '
        'float intermediate, peak normalized to -3 dBFS after processing; 8/25 ms fades; sources unchanged')
    manifest_path.write_text(json.dumps(manifest, indent=2) + '\n')
    print(f'Imported {sum(map(len, GROUPS.values()))} minion voices into {target_dir}')


if __name__ == '__main__':
    import_voices()
