# Supplied audio usage

Audit date: 2026-11-03. Source folder: `/home/hugo/Downloads/sound/`.

All 76 supplied files are imported: 46 SFX, 6 ambience tracks, 8 music tracks,
and 16 minion voice clips. Original source files are left unchanged.
Runtime events are in `assets/audio/manifest.json`, with surface-specific
overrides and aliases in `scripts/audio/game_audio.gd`.

Burning characters now carry a positional `ambience.fire_close` loop with
their voxel flames, using the Ambience bus at -16 dB. The source follows the
actor and stops when the effect ends or water extinguishes it. No additional
audio file was needed; see [Burning](BURNING.md).

## Unused supplied effects

`sfx/hit_shield.wav` is retained in the manifest but currently has no gameplay
playback call. Physical and magical shield contacts now both use the supplied
`magic_hit_shield1.wav` / `magic_hit_shield_2.wav` variations.

All other supplied SFX have gameplay playback paths. This is a code usage
audit: some effects only occur with particular bosses, equipment or actions.

The generated utility `boss_charge.wav` also has no playback call. It is
synthesized by the importer and is not one of the supplied files.

## Supplied effects with playback paths

| Source files in `sfx/` | Playback |
| --- | --- |
| `bow.wav`, `wand.wav` | Player weapon shots, including remote player copies |
| `enemy_wind_shot.wav`, `fireball.wav` | Enemy projectile launch and applicable projectile endings |
| `arrow_projectile_hit_wall_or_object.wav`, `trident_projectile_hit_wall_or_object.wav`, `wand_projectile_hit_wall_or_object.wav` | Weapon-specific projectile impacts |
| `hurt_1.wav`, `hurt_2.wav` | Player damage only |
| `enemy_hurt1.mp3` through `enemy_hurt4.mp3` | Ordinary enemy damage, with four positional variations |
| `enemiy_die_sound_1.wav` | Normal-size enemy deaths |
| `smalle_enemy_die.wav` | Small enemy deaths (body height times model scale at most 1.5 metres) |
| `magichitenemy.wav` | Magical projectile hits |
| `boss_dragon_hurt_sound.wav` | Blue Dragon damage |
| `boss_hurt_screem_short_1.wav`, `boss_hurt_screem_short_2.wav`, `boss_hurt_screem_short_3.wav` | Non-dragon boss damage |
| `boss_hurt_screem_long.wav`, `boss_hurt_screem_long_2.wav`, `boss_hurt_screem_long_3.wav` | Boss deaths |
| `boss_kill_rumble_riser_1.wav`, `boss_kill_rumble_riser_2.wav`, `boss_kill_rumble_riser_3.wav`, `boss_kill_rumble_riser_4.wav`, `boss_kill_rumble_riser_5.wav` | Boss death builds from the recording's start through its peak, fitted to the death sequence without changing pitch |
| `heavy_boss_impact.wav` | Boss slams and heavy impacts |
| `Cinematic_horror_impact_1.wav` | Boss intro reveal, limited to the intro duration |
| `magic_hit_shield1.wav`, `magic_hit_shield_2.wav` | Physical and magical shield hits, projectile/ring contact and opposing ring clashes |
| `magic_projectioes_boom.wav` | Magical enemy projectile launches, terminal projectile releases, ripple explosions and player projectile magical bursts |
| `shield up.wav`, `shield.wav` | Shield raise and sustained shield loop |
| `magic_ring.wav` | Local and remote player casts, plus expanding enemy rings including Drowned Cantor, Abyssal Siren, Goblin King and Vharok; positional cast audio plays on each client |
| `death` (extensionless MP3) | Local player death, online and offline, centered with the original pitch |
| `heal.wav`, `potion.wav` | Healing, level-up healing cue, consumable use |
| `equip_item.wav` | Gear changes and backpack upgrade consumption |
| `forge.wav`, `forge_dismantle.wav` | Forge interaction and confirmed dismantling |
| `dot_gain_shouldbeloopedforeachdot.wav` | Repeated Dots gain animation ticks |
| `notification_party_invite.wav` | Party invitation |
| `campaign complete.wav` | Campaign completion |

## Ambience and music

All six supplied ambience recordings are used. Tavern, desert, fire-biome,
cinematic/deep-dark and wind loops blend according to location. Dungeons use
the cinematic ambience, including magma and pyre dungeons. Nearby voxel
fires play the proximity fire loop. `Music_1_tavern.wav` plays in Taverns;
`Music_2_japanese.wav` plays outside them.

The headphone width control affects only sound effects. Music and ambience,
including nearby fire emitters, bypass the effects-width bus. Local weapon
firing is centered; other players' shots retain positional audio. Both the
shield raise clip and sustain loop fade out immediately on release.

Boss death builds are baked into 2, 3 and 5 second variants, covering every
authored boss death duration. `python tools/import_boss_rumbles.py` finds the
strongest 40 ms RMS peak, keeps the build from the start through that peak,
and fits it with Rubber Band at pitch 1. Playback begins at zero with no
seek or pitch randomization. The source recordings remain intact.

Player footsteps use separate stone, wood, grass and sand syntheses, with
low heel tones and two stages of filtered noise for soft, muffled thumps.
Their normalized source peak is 0.30 and playback is 4 dB lower than before,
for approximately 11 dB less peak level. Local footsteps stay centered. Stride distance survives
stationary render frames between physics moves; footsteps stop for idle,
airborne, frozen or locked players and do not catch up after teleports.

Balanced compression now uses a -8 dB threshold and 1.3:1 ratio. Wide uses
a 1:1 ratio; Night uses -18 dB and 2.5:1 without makeup gain. The output
limiter remains at -1 dB. Tavern ambience is 2 dB quieter than the prior mix.

## Layered battle music

All six supplied `battle1_layer1.wav` through `battle3_layer2.wav` recordings
are imported as stereo Vorbis at 48 kHz. `python3 tools/import_battle_music.py`
rebuilds only these tracks; the full audio importer invokes it too. Originals
are unchanged. Quiet sections below -48 dB for at least half a second are cut
with 20 ms protection. Internal edits crossfade over 40 ms. The current sources
had silent tails of roughly 4-38 seconds.

The original opening plays first. A 350 ms tail/head crossfade is baked into
the end of each file. Runtime loops then resume 350 ms into the opening, exactly
after the overlapped portion. This keeps the seam smooth while preserving the
initial reveal. The two recordings in each pair share peak adjustment and retain
their original tempo, pitch, stereo image and relative balance.

| Score | Exploration layer | Combat layer |
| --- | --- | --- |
| Battle 1 | Approaching the winter stronghold within 110 metres, before reaching its gate; fades away beyond 140 metres | Rimeheart Prism activation/intro and fight |
| Battle 2 | Throughout Goblins Cave | Its active boss encounters, starting during the intro |
| Battle 3 | Throughout the Hollow Castle in campaign seven | The Hollow King's throne-door cinematic and fight |

Layer 2 is not played silently in advance. Its voice is created at playback
position zero when the boss activates and fades in over 1.5 seconds. It fades
out over two seconds when combat ends or resets, and a new attempt starts from
the beginning. Muting music defers its start until music is audible again.
Layer 1 and ordinary location music crossfade over 2.5 seconds.

The Music bus has a +6 dB mix trim so equal category sliders leave the score
present alongside SFX and ambience. Important cues duck music by at most 2 dB
(previously 4 dB). Both battle layers receive the same trim, preserving their
balance; their existing source headroom and the output limiter remain in place.
The zero music setting stays silent.

Other boss encounters fade normal music away while ambience keeps playing.
The winter boss's death ends both battle layers and restores realm music.
A reliable defeat event and the realm's cleared-pack record prevent its score
from restarting when returning to that cleared stronghold. Goblins Cave and
Hollow Castle keep their exploration layer after their boss is defeated.

## Minion voices

All 16 MP3s are converted into mono 48 kHz WAVs in `assets/audio/voices/`.
Rebuild just the voices with `python tools/import_minion_audio.py`, or rebuild
all audio with `python tools/import_audio.py`. FFmpeg must include Rubber Band.

Processing uses Rubber Band quality mode, independent 1.5x tempo and 1.3x pitch
(about 4.5 semitones up). A float intermediate avoids clipping before final
peak adjustment to approximately -3 dBFS. Gentle filtering, a short fade-in and
fade-out preserve the phrases. Durations, trimming and settings are recorded
per file in the manifest. All 16 outputs were checked for 1.5x speed and zero
clipped samples.

`DialogueVoice` accompanies accepted NPC speech in `InteractionCard` and
shared talk pages in `SceneDialog`. Emotions use filename groups: curious,
excited, angry, cheering, gasp, laugh, joking, sad, scream and surprised.
Text selects an emotion; a shared scene may override it with `voice_mood`.
Neutral speech uses the curious group. Clips play as phrases and continue
while text reveals, rather than restarting on every word.

The speaker, page text and phrase number select variants consistently on all
clients. Existing campaign scene/page events already go to each participant;
both the driver and listeners start their voices from those events. Local
conversations remain local. Conversation audio uses SFX volume without
distance attenuation or ally/UI sound muting. No extra realm-wide sound
broadcast is sent. Dedicated servers do not play dialogue audio.

Finishing or skipping the text, changing pages, walking away, hiding the
dialogue or ending the scene fades its current voice. Player chat, vote
thoughts, object inspection and cinematic narration do not trigger NPC speech.

## Checks

- `tools/test_arrow_heading.tscn`: stationary frames, distant-world rounding,
  vertical shots, projectile scale and range expiry.
- `tools/test_quest_ui.tscn`: main/side quest state and campaign controls.
- `tools/test_dialogue_ui.tscn`: three HUD scales, local and shared voices,
  consistent party variants, phrase continuation and stopping behavior.
  Add `-- --preview` with a rendering display to save HUD screenshots in `/tmp`.
- `tools/test_audio.tscn`: asset loading, output modes, mute settings, mixer
  continuity and server-to-client sound relay.
