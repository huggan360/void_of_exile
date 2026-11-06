#!/usr/bin/env python3
"""Prepare battle beds/overlays without modifying the supplied recordings.

The first playback keeps the original opening. A baked tail-to-head crossfade
ends at head + CROSS seconds; subsequent loops restart at that offset, avoiding
both a click and a crossfade over the first boss-reveal notes.
"""
from __future__ import annotations
import json
import pathlib
import re
import subprocess

ROOT = pathlib.Path(__file__).resolve().parents[1]
SOURCE = pathlib.Path('/home/hugo/Downloads/sound/music')
OUT = ROOT / 'assets/audio'
RATE = 48000
CROSS = 0.35
JOIN = 0.04
PAD = 0.02


def run(args):
    return subprocess.run(args, check=True, capture_output=True, text=True)


def duration(path):
    return float(run(['ffprobe', '-v', 'error', '-show_entries', 'format=duration',
                      '-of', 'default=noprint_wrappers=1:nokey=1', str(path)]).stdout)


def active_sections(path, length):
    report = run(['ffmpeg', '-hide_banner', '-i', str(path), '-af',
                  'silencedetect=noise=-48dB:d=0.5', '-f', 'null', '-']).stderr
    quiet = []
    start = None
    for line in report.splitlines():
        found = re.search(r'silence_start:\s*([\d.]+)', line)
        if found:
            start = float(found[1])
        found = re.search(r'silence_end:\s*([\d.]+)', line)
        if found and start is not None:
            quiet.append((start, min(length, float(found[1]))))
            start = None
    if start is not None:
        quiet.append((start, length))
    sections = []
    cursor = 0.0
    for start, end in quiet:
        if start > cursor:
            sections.append((cursor, min(length, start + PAD)))
        cursor = min(length, max(cursor, end - PAD))
        if end >= length - 0.002:
            cursor = length
    if cursor < length:
        sections.append((cursor, length))
    # Ignore tiny remnants of an all-quiet section.
    return [(a, b) for a, b in sections if b - a > 0.10]


def peak_db(path):
    report = run(['ffmpeg', '-hide_banner', '-i', str(path), '-af', 'volumedetect',
                  '-f', 'null', '-']).stderr
    return float(re.search(r'max_volume:\s*(-?[\d.]+) dB', report)[1])


def import_music():
    manifest_path = OUT / 'manifest.json'
    manifest = json.loads(manifest_path.read_text())
    sources = {f'battle{battle}_layer{layer}.wav': SOURCE / f'battle{battle}_layer{layer}.wav'
               for battle in (1, 2, 3) for layer in (1, 2)}
    # One gain per pair retains the authored balance between its two recordings.
    gains = {battle: -4.0 - max(peak_db(sources[f'battle{battle}_layer{layer}.wav'])
                              for layer in (1, 2)) for battle in (1, 2, 3)}
    stats = []
    (OUT / 'music').mkdir(parents=True, exist_ok=True)
    for name, source in sources.items():
        battle = int(name[6])
        layer = int(name[13])
        length = duration(source)
        sections = active_sections(source, length)
        if not sections:
            raise ValueError(f'No audible battle music in {source}')
        clean_length = sum(b - a for a, b in sections) - JOIN * (len(sections) - 1)
        cross = min(CROSS, clean_length * 0.08)
        filters = []
        for index, (a, b) in enumerate(sections):
            filters.append(f'[0:a]atrim=start={a:.6f}:end={b:.6f},asetpts=PTS-STARTPTS[s{index}]')
        current = 's0'
        for index in range(1, len(sections)):
            following = f'join{index}'
            filters.append(f'[{current}][s{index}]acrossfade=d={JOIN}:c1=qsin:c2=qsin[{following}]')
            current = following
        filters.append(f'[{current}]volume={gains[battle]:.4f}dB,aresample={RATE},asplit=3[body][tail][head]')
        filters.append(f'[body]atrim=end={clean_length-cross:.6f},asetpts=PTS-STARTPTS[b]')
        filters.append(f'[tail]atrim=start={clean_length-cross:.6f},asetpts=PTS-STARTPTS[t]')
        filters.append(f'[head]atrim=end={cross:.6f},asetpts=PTS-STARTPTS[h]')
        filters.append(f'[t][h]acrossfade=d={cross:.6f}:c1=qsin:c2=qsin[seam]')
        filters.append('[b][seam]concat=n=2:v=0:a=1[out]')
        target = OUT / 'music' / name.replace('.wav', '.ogg')
        run(['ffmpeg', '-y', '-v', 'error', '-i', str(source), '-filter_complex',
             ';'.join(filters), '-map', '[out]', '-ar', str(RATE), '-ac', '2',
             '-c:a', 'libvorbis', '-q:a', '5', str(target)])
        event = f'music.battle{battle}.layer{layer}'
        manifest['events'][event] = {
            'paths': ['res://assets/audio/music/' + target.name],
            'gain_db': -8 if layer == 1 else -10, 'pitch_variance': 0,
            'positional': False, 'loop': True, 'loop_offset': round(cross, 6),
        }
        stats.append({
            'source': 'music/' + name, 'output': 'assets/audio/music/' + target.name,
            'input_duration_s': round(length, 3), 'output_duration_s': round(clean_length, 3),
            'kept_sections_s': [[round(a, 6), round(b, 6)] for a, b in sections],
            'silence_removed_s': round(length - sum(b-a for a, b in sections), 3),
            'loop_crossfade_s': round(cross, 6), 'loop_offset_s': round(cross, 6),
            'gain_applied_db': round(gains[battle], 3), 'input_channels': 2,
            'output_channels': 2, 'codec': 'vorbis', 'pitch': 1.0,
        })
        print(f'{event}: {length:.2f}s -> {clean_length:.2f}s; loop from {cross:.2f}s')
    names = {'music/' + name for name in sources}
    manifest['process_stats'] = [row for row in manifest.get('process_stats', [])
                                 if row.get('source') not in names] + stats
    manifest.setdefault('processing', {})['battle_music'] = (
        'Stereo Vorbis quality 5, 48 kHz. Quiet sections below -48 dB for 0.5s are '
        'removed with 20 ms protection; internal edits crossfade over 40 ms. A 350 ms '
        'tail/head overlap is baked at the end, and loop_offset skips the overlapped '
        'opening on later passes. First playback starts at the original opening. '
        'Paired stems share peak adjustment with headroom; pitch and tempo are unchanged.')
    manifest_path.write_text(json.dumps(manifest, indent=2) + '\n')


if __name__ == '__main__':
    import_music()
