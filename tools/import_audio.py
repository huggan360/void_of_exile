#!/usr/bin/env python3
"""Read-only audio asset importer for VoxelRealms. Sources are never modified."""
from __future__ import annotations
import json, math, pathlib, shutil, struct, subprocess, sys, wave

ROOT = pathlib.Path(__file__).resolve().parents[1]
SOURCE = pathlib.Path('/home/hugo/Downloads/sound')
OUT = ROOT / 'assets/audio'
RATE = 48000

# Semantic event: (source relative paths, target gain dB, pitch variance, positional, loop)
EVENTS = {
 'projectile.arrow': (['sfx/bow.wav'], -4, .06, True, False),
 'projectile.fireball': (['sfx/fireball.wav'], -3, .05, True, False),
 'projectile.enemy_wind': (['sfx/enemy_wind_shot.wav'], -4, .04, True, False),
 'projectile.wand': (['sfx/wand.wav'], -4, .07, True, False),
 'projectile.impact': (['sfx/arrow_projectile_hit_wall_or_object.wav','sfx/trident_projectile_hit_wall_or_object.wav','sfx/wand_projectile_hit_wall_or_object.wav'], -3, .07, True, False),
 'combat.enemy_hurt': (['sfx/enemy_hurt1.mp3','sfx/enemy_hurt2.mp3','sfx/enemy_hurt3.mp3','sfx/enemy_hurt4.mp3'], -7, .025, True, False),
 'combat.hit': (['sfx/hurt_1.wav','sfx/hurt_2.wav'], -4, .05, True, False),
 'combat.enemy_death': (['sfx/enemiy_die_sound_1.wav'], -3, .025, True, False),
 'combat.small_enemy_death': (['sfx/smalle_enemy_die.wav'], -3, .025, True, False),
 'combat.magic_hit': (['sfx/magichitenemy.wav'], -3, .05, True, False),
 'combat.boss_hurt': (['sfx/boss_dragon_hurt_sound.wav','sfx/boss_hurt_screem_short_1.wav','sfx/boss_hurt_screem_short_2.wav','sfx/boss_hurt_screem_short_3.wav'], -4, .03, True, False),
 'combat.boss_death': (['sfx/boss_hurt_screem_long.wav','sfx/boss_hurt_screem_long_2.wav','sfx/boss_hurt_screem_long_3.wav'], -5, .02, True, False),
 'combat.boss_impact': (['sfx/heavy_boss_impact.wav','sfx/Cinematic_horror_impact_1.wav'], -4, 0, True, False),
 'combat.boss_rumble': (['sfx/boss_kill_rumble_riser_1.wav','sfx/boss_kill_rumble_riser_2.wav','sfx/boss_kill_rumble_riser_3.wav','sfx/boss_kill_rumble_riser_4.wav','sfx/boss_kill_rumble_riser_5.wav'], -5, 0, True, False),
 'magic.shield_hit': (['sfx/hit_shield.wav','sfx/magic_hit_shield1.wav','sfx/magic_hit_shield_2.wav'], -3, .04, True, False),
 'magic.shield_loop': (['sfx/shield.wav'], -5, 0, True, True),
 'magic.shield_cast': (['sfx/shield up.wav'], -5, .02, True, False),
 'magic.ring': (['sfx/magic_ring.wav'], -4, .03, True, False),
 'magic.explosion': (['sfx/magic_projectioes_boom.wav'], -4, .03, True, False),
 'player.death': (['sfx/death'], -5, 0, False, False),
 'player.heal': (['sfx/heal.wav'], -4, .03, False, False),
 'item.potion': (['sfx/potion.wav'], -4, .04, False, False),
 'item.equip': (['sfx/equip_item.wav'], -5, .04, False, False),
 'item.forge': (['sfx/forge.wav','sfx/forge_dismantle.wav'], -5, .04, False, False),
 'progression.dot_gain': (['sfx/dot_gain_shouldbeloopedforeachdot.wav'], -6, .04, False, False),
 'notification.party_invite': (['sfx/notification_party_invite.wav'], -5, .02, False, False),
 'notification.campaign_complete': (['sfx/campaign complete.wav'], -5, .02, False, False),
 'ambience.cinematic': (['ambiance/ambiance_loop_cinematic.wav'], -8, 0, False, True),
 'ambience.fire_dungeon': (['ambiance/ambiance_loop_for_fire_dungeons.wav'], -8, 0, False, True),
 'ambience.tavern': (['ambiance/ambiance_loop_in_tavern.wav'], -8, 0, False, True),
 'ambience.desert': (['ambiance/ambience_loop_dessert.wav'], -8, 0, False, True),
 'ambience.fire_close': (['ambiance/ambience_loop_fire_close_proximity.wav'], -9, 0, True, True),
 'ambience.wind': (['ambiance/ambience_loop_wind.wav'], -9, 0, False, True),
 'music.tavern': (['music/Music_1_tavern.wav'], -8, 0, False, True),
 'music.japanese': (['music/Music_2_japanese.wav'], -8, 0, False, True),
}

def run(args): return subprocess.run(args, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
def probe(path):
    d=json.loads(run(['ffprobe','-v','error','-show_entries','format=duration:stream=sample_rate,channels','-of','json',str(path)]).stdout)
    return float(d['format']['duration']), int(d['streams'][0]['channels'])
def leading_trim(path):
    # Trim only a silence run that begins at time zero, retaining 10 ms before
    # its end. Silence later in an effect is intentional and stays untouched.
    result=run(['ffmpeg','-hide_banner','-i',str(path),'-af','silencedetect=noise=-45dB:d=0.03','-f','null','-']).stderr
    initial=False
    for line in result.splitlines():
        if 'silence_start:' in line:
            start=float(line.split('silence_start:')[1].split()[0])
            if start <= 0.001: initial=True
        elif 'silence_end:' in line and initial:
            end=float(line.split('silence_end:')[1].split('|')[0].strip())
            return max(0.0,end-0.010) if end > 0.030 else 0.0
        elif 'silence_end:' in line:
            break
    return 0.0

def peak_db(path):
    s=run(['ffmpeg','-hide_banner','-i',str(path),'-af','volumedetect','-f','null','-']).stderr
    for ln in s.splitlines():
        if 'max_volume:' in ln:
            v=ln.split('max_volume:')[1].split('dB')[0].strip()
            return -90.0 if v == '-inf' else float(v)
    return 0.0

def generated(name, kind):
    # Procedural utility tones are quiet, short, and fade smoothly at both ends.
    duration={'ui_click':.085,'ui_hover':.11,'warning_pulse':.42,'boss_charge':2.2,'boss_riser':2.8}[kind]
    n=int(RATE*duration); frames=[]
    for i in range(n):
        t=i/RATE; x=i/max(1,n-1); env=min(1,x*30,(1-x)*25)
        if kind=='ui_click': y=(math.sin(2*math.pi*(1050-350*x)*t)+.35*math.sin(2*math.pi*2100*t))*math.exp(-t*48)
        elif kind=='ui_hover': y=math.sin(2*math.pi*(660+190*x)*t)*math.sin(math.pi*x)**1.5
        elif kind=='warning_pulse': y=math.sin(2*math.pi*(730+80*math.sin(2*math.pi*3*t))*t)*(.35+.65*abs(math.sin(2*math.pi*2.4*t)))
        else:
            f0=110 if kind=='boss_charge' else 75
            freq=f0+700*x*x
            y=(math.sin(2*math.pi*freq*t)+.32*math.sin(2*math.pi*freq*.5*t)+.15*math.sin(2*math.pi*freq*1.5*t))*(x**1.5 if kind=='boss_riser' else (1-.5*x))
            y += .12*math.sin(2*math.pi*37*t)*(x if kind=='boss_riser' else 1)
        y=max(-.95,min(.95,y*env*.32)); frames.append(struct.pack('<hh',int(y*32767),int(y*32767)))
    p=OUT/'generated'/f'{name}.wav'; p.parent.mkdir(parents=True,exist_ok=True)
    with wave.open(str(p),'wb') as w: w.setnchannels(2); w.setsampwidth(2); w.setframerate(RATE); w.writeframes(b''.join(frames))
    return p

def main():
    if not shutil.which('ffmpeg') or not shutil.which('ffprobe'): raise SystemExit('ffmpeg and ffprobe are required')
    OUT.mkdir(parents=True,exist_ok=True); manifest={}; stats=[]
    generated_specs={'ui.click':'ui_click','ui.hover':'ui_hover','ui.warning_pulse':'warning_pulse','boss.charge':'boss_charge','boss.riser':'boss_riser'}
    for event,(sources,gain,pitch,positional,loop) in EVENTS.items():
        outputs=[]
        for src in sources:
            source=SOURCE/src
            if not source.is_file(): raise SystemExit(f'Missing source: {source}')
            dur,ch=probe(source); trim=0.0 if src.startswith(('music/','ambiance/')) else leading_trim(source); is_music=src.startswith('music/'); is_amb=src.startswith('ambiance/')
            folder='music' if is_music else ('ambience' if is_amb else 'sfx')
            stem=pathlib.Path(src).stem.lower().replace(' ','_')
            ext='.ogg' if is_music else '.wav'
            target=OUT/folder/(stem+ext); target.parent.mkdir(parents=True,exist_ok=True)
            # Peak adjustment is fixed peak normalization, preserving the source dynamics.
            target_peak=-2.0 if folder=='sfx' else -3.0
            vol=target_peak-peak_db(source)
            filters=[]
            if trim: filters += [f'atrim=start={trim:.5f}','asetpts=PTS-STARTPTS']
            if src == 'sfx/shield.wav': filters += ['highpass=f=180']
            elif not (is_music or is_amb): filters += ['highpass=f=35']
            if not (is_music or is_amb): filters += ['lowpass=f=19000']
            processed_duration=dur-trim
            if event=='progression.dot_gain':
                # The measured tail falls below -50 dB after 200 ms. Keep the
                # pop and its decay, avoiding dozens of silent active voices.
                processed_duration=min(processed_duration,.24)
                filters += [f'atrim=end={processed_duration}']
            filters += [f'volume={vol:.3f}dB','afade=t=in:st=0:d=0.008',f'afade=t=out:st={max(.01,processed_duration-.012):.5f}:d=0.012']
            if positional and ch>1: filters += ['pan=mono|c0=0.5*c0+0.5*c1']
            codec=['-c:a','libvorbis','-q:a','4'] if is_music else ['-c:a','pcm_s16le','-ar',str(RATE),'-ac','1' if positional else '2']
            if loop and not is_music and dur-trim>.5:
                # Bake the seam once; short loops stay PCM so many spatial
                # emitters do not run parallel Vorbis decoders in the mixer.
                end=dur-trim; cross=.08
                graph=','.join(filters)+',asplit=3[tail][head][body];'
                graph+=f'[tail]atrim=start={end-cross:.5f},asetpts=PTS-STARTPTS[t];'
                graph+=f'[head]atrim=end={cross},asetpts=PTS-STARTPTS[h];'
                graph+=f'[t][h]acrossfade=d={cross}:c1=qsin:c2=qsin[x];'
                graph+=f'[body]atrim=start={cross}:end={end-cross:.5f},asetpts=PTS-STARTPTS[b];'
                graph+='[x][b]concat=n=2:v=0:a=1[out]'
                cmd=['ffmpeg','-y','-v','error','-i',str(source),'-filter_complex',graph,'-map','[out]']+codec+[str(target)]
            else:
                cmd=['ffmpeg','-y','-v','error','-i',str(source),'-af',','.join(filters)]+codec+[str(target)]
            run(cmd)
            outdur,outch=probe(target); outputs.append('res://assets/audio/'+str(target.relative_to(OUT)))
            stats.append({'source':str(src),'output':str(target.relative_to(ROOT)),'input_duration_s':round(dur,3),'leading_trim_s':round(trim,3),'output_duration_s':round(outdur,3),'input_channels':ch,'output_channels':outch,'gain_applied_db':round(vol,2),'codec':'vorbis' if ext=='.ogg' else 'pcm_s16le'})
        manifest[event]={'paths':outputs,'gain_db':gain,'pitch_variance':pitch,'positional':positional,'loop':loop}
    for event,kind in generated_specs.items():
        src=generated(event.replace('.','_'),kind); target=OUT/'sfx'/(event.replace('.','_')+'.wav'); target.parent.mkdir(parents=True,exist_ok=True)
        d,_=probe(src); filters=['highpass=f=35','lowpass=f=17000','afade=t=in:st=0:d=0.005',f'afade=t=out:st={d-.01:.4f}:d=0.01']
        run(['ffmpeg','-y','-v','error','-i',str(src),'-af',','.join(filters),'-ac','1','-c:a','pcm_s16le',str(target)])
        src.unlink()
        manifest[event]={'paths':['res://assets/audio/sfx/'+target.name],'gain_db':-6 if event.startswith('ui.') else -8,'pitch_variance':0,'positional':event.startswith('boss.'),'loop':False}
    (OUT/'manifest.json').write_text(json.dumps({'schema_version':1,'source_root':str(SOURCE),'processing':{'source_immutable':True,'sample_rate_hz':RATE,'sfx':'mono PCM; peak adjusted to -2 dBFS, 35 Hz high-pass / 19 kHz low-pass, 8 ms fade-in and 12 ms fade-out','ambience_music':'music: stereo Vorbis quality 4; ambience/shield loops: predecoded PCM to avoid decoder contention; source dynamics retained','leading_silence':'SFX only: detected at -45 dB for at least 30 ms, retaining 10 ms before the detected end; durations recorded per source','shield_cleanup':'shield.wav gets a stronger 180 Hz high-pass before the root runtime 280 Hz shield-only filter','loop_source':'Ambience and shield use an 80 ms equal-power tail/head overlap with seam rotation; music remains full length; loop hint set for runtime','generated':'offline synthesized utility effects; see generated event names'},'events':manifest,'process_stats':stats},indent=2)+'\n')
    print(f'Imported {len(stats)} source files and {len(generated_specs)} generated effects into {OUT}')
    from import_minion_audio import import_voices
    import_voices()
    from import_boss_rumbles import import_rumbles
    import_rumbles()
    from import_battle_music import import_music
    import_music()
if __name__=='__main__': main()
