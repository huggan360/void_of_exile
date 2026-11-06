# Audio implementation and review

Open Options > Audio for Headphones, Speakers or Surround, a spatial listening test, master/music/effects/ambience levels, ally mute and volume, interface mute, and Balanced/Night/Wide dynamics. Preferences save immediately in user://settings.cfg independently of characters.

Headphones use a lightweight binaural approximation: paired ear channels, up to 0.62 ms of interaural delay, continuous ear level differences, high-frequency head shadow and front/back spectral shaping in twelve directional sectors. This is an analytic approximation rather than a measured, personalized HRTF. Speakers use stereo directional levels without ear delays or spectral emulation. Surround uses Godot's native AudioStreamPlayer3D channel panner and an AudioListener3D at the character, aligned with the camera. The operating system must expose a 5.1/7.1 device; the status describes the actual driver mode. The listening test moves through front-left, center, front-right, rear-right, rear-left and low rumble. It is a directional listening test rather than an isolated hardware channel calibration.

## Sources and processing

All 76 supplied files from /home/hugo/Downloads/sound are mapped in assets/audio/manifest.json. Originals are untouched. Run python3 tools/import_audio.py to regenerate the imported versions and synthesis assets, then let Godot import changes.

Positional effects and close fire ambience are mono. Music and global ambience retain stereo. Short effects use 48 kHz PCM; longer loops and music use Vorbis. Effects have leading silence removed only when it begins at the file start, with 10 ms of attack protection. Gentle 35 Hz high-pass and 19 kHz low-pass filters remove unnecessary extremes. Shield audio has a stronger 180 Hz source high-pass and a dedicated runtime 280 Hz filter. Peak adjustment preserves the original dynamics. Ambience and shield loops use an 80 ms equal-power tail/head overlap with seam rotation. Music remains full length. The DOT sound's near-silent tail is shortened to 240 ms; each arriving visual dot triggers its own pop.

The manifest records source paths, original and processed durations, channels, gain changes and trim amounts. Alternate takes are randomized without immediate repeats. Surface-specific impacts stay with the matching weapon rather than being randomly interchanged. Dragon vocalizations stay on the dragon.

## Runtime mix and cues

scripts/audio/game_audio.gd owns playback, buses, concurrency limits and cleanup. scripts/audio/sound_synth.gd generates missing trident release, projectile air, portal presence, pickup/test tones and fallback cues. The importer also generates UI click/hover, boss charge/riser and warning assets. There is no external synthesis dependency at runtime.

Recurring actions use at most +/-3.5% playback-rate variation. Loops, timed risers, alarms and boss death rumbles keep their original pitch. Death rumbles use preprocessed builds from the source start through its peak, fitted to the boss death duration without changing pitch. Riser windows fit the windup time the same way. Boss hurt calls are limited to avoid screaming on every pellet. Ally actions have both a separate volume multiplier and an additional reduction.

Music uses the Tavern theme in all public/private Taverns and the Japanese track elsewhere. Music changes crossfade. Assigned encounters use independent exploration/combat recordings, with the combat layer starting from its original opening at boss activation. Goblins Cave uses battle 2, the winter stronghold battle 1, and the Hollow Castle battle 3. Other boss fights fade location music to silence while retaining ambience. See docs/audio_usage.md for routing and loop preparation. Realm ambience samples the current biome and four points 14 meters away, blending over 3.5 seconds so a neighboring biome can be heard before crossing its edge. Close fire and portal loops start and fade by proximity; only the nearest eight are active. Magic projectile air follows its projectile with six concurrent layers maximum. Freed source nodes and travel release their loops.

Stone caves use a larger, brighter echo; interiors use a smaller room; outdoors remain mostly dry. The shared effects EQ reduces low-end buildup and a little upper-mid harshness. Balanced compression is gentle (-8 dB threshold, 1.3:1); Wide uses 1:1; Night uses -18 dB and 2.5:1 without makeup gain. The Music bus has a +6 dB mix trim, and important cues duck it by at most 2 dB. An output limiter at -1 dB controls peaks. Tavern ambience is 2 dB quieter. This is an initial implementation mix; artistic judgments about the supplied AI recordings still benefit from listening on the intended equipment.

Local magic shield activation sweeps the entire GameMix low-pass from 20 kHz to 1.25 kHz and releases smoothly. Only that player's shield controls the bubble filter. Remote shields remain quiet positional sources. UI mute does not mute combat warnings. Effects volume also controls interface and reward sounds.

Server-authoritative enemy/boss cues use trusted realm-scoped sfx events; clients play the local spatial mix. Projectile packets already carry firing information and are sounded locally rather than duplicated through this relay. The Hollow King's red floor warning alarm is driven by the same client clock and pulse as its visible warning_fill hazards, including the final coronation.

## Validation

Run the integration scene with isolated settings:

```bash
env XDG_DATA_HOME=/home/hugo/tmp/void_audio_userdata /home/hugo/Godot/godot_voxel_editor --headless --audio-driver Dummy --path "$PWD" tools/test_audio.tscn
```

It loads every mapped audio resource, checks all three output routes, mutes and saved preferences, alternate takes and pitch bounds, fixed-pitch rumble timing, shield filter sweep/release, actual recorded left/right mixer energy, server/client sound packet handling, source cleanup and Audio page creation. Add -- --preview in a graphical run to write /home/hugo/Desktop/Void-of-Exile-Audio-Settings.png. Hardware rear-channel verification requires the actual surround device.

## Continuity and headphone width update

Headphone stereo width is saved separately, defaults to 35%, and ranges from mono to the full image. A zero-delay mid/side width effect narrows the whole headphone mix, including music and recorded stereo ambience; surround bypasses it. Directional ear processing now shares one six-band bank across categories rather than three duplicate ten-band banks. Headphone category levels are applied to each voice before this bank. The source high-pass remains on remote shield loops; the dedicated runtime shield high-pass remains on the local bubble loop.

All mapped recordings and procedural utility/footstep PCM are warmed before world generation. Unchanged bus assignments, volumes, music gain and filter settings are no longer repeatedly submitted to the mixer. Spatial updates are limited to 30 Hz; audio samples continue on the native mixer thread. The requested output buffer increases from 15 to 60 ms, trading some response latency for deadline headroom. Voxel workers reserve at least two logical CPU threads where hardware permits; the existing half-core allocation is retained. Restart the game to apply the driver and voxel startup settings.

Generated footsteps use four variants per wood/stone/grass/sand surface, low heel tones with two low-pass noise stages, actual distance traveled, and subtle pitch variation. Peak normalization is 0.30 with a -7 dB playback offset, approximately 11 dB quieter than the earlier bright grit mix. Local footsteps require grounded movement; ally footsteps follow replicated movement and respect ally mute/volume. Teleports and long frame stalls reset cadence instead of emitting a catch-up burst. The continuity test records the mixer through a deliberate 400 ms main-thread stall. This tests game-thread independence, not an absolute guarantee against operating-system or audio-device underruns.
