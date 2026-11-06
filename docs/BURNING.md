# Burning

Burning affects players, party members and ordinary enemies, including gods.
Every Boss / BossDef target rejects it. Existing friendly-fire rules still
decide who a projectile can hit.

- Each full second of fire deals a random 10-15 HP of damage. It bypasses
  armour; holding a shield does not reduce an already active burn.
- Normal fire shots burn for 3-6 seconds according to their size. Heavy fire
  shots burn for 10 seconds, including Vharok's broad cleaves and authored
  flame shards. Dragonbreath's charged inferno also burns for 10 seconds.
- Firepits, campfires and lava contact apply 3.5 seconds of Burning, refreshed
  while the actor remains in the fire. The old separate 40 HP lava tick has
  been replaced, rather than stacked on top of Burning.
- Damaging fire eruptions and pools from the fire bosses also ignite players.
  Harmless floor warnings do not.
- Repeated hits refresh a single burn. Short fire effects cannot shorten a
  longer active burn, multiply its damage, or reset its one-second cadence.
- Stepping into water extinguishes fire. Water contact and ground fires are
  checked on the authority, including on the dedicated server. Immune and
  Invincible protections clear Burning with the other harmful effects.

The new 8x8 flame icon is `buffs/icons/burning.svg`, composited into the existing
red pixel-art badge. Local and remote players use their normal status flags;
burning enemies also display the badge. Their attached glowing voxel flames
use `VoxelFire`, scaled for the actor's height, with contact ignition disabled
so a burning actor is never another firepit.

The existing `ambience.fire_close` recording loops at the attached flames,
following the actor and stopping when the flames disappear. It uses the
Ambience bus at -16 dB, with a short fade and an 18 m audible range. Remote
party fire respects the ally-sounds setting. The dedicated server creates
neither the presentation nor audio.

`Burning.projectile` adds fire metadata before network shot authorization,
including terminal child attacks. It recognizes literal fireballs, flame
shards, the authored fire models and the older fire sources. Volcanic enemies
also explicitly mark their attacks as fire, including their bolt/orb shapes.
Player fire weapons derive the same effect from the server's equipped item;
inferno explosion rings retain it. Clients cannot submit an arbitrary burn
through an enemy-hit report.

New fire projectiles should set `element = "fire"` in the attack dictionary,
or in `Item.projectile` for a player weapon. Optional `burn_duration` supplies
an explicit duration up to 10 seconds; zero disables projectile ignition.
The effect can also be applied through the existing buff API as `burning`
(alias `burn`). Damage ticks and enemy kill credit remain authoritative.

The follow-up short headless check passed 102 boss/Burning assertions across
all 13 bosses and 81 existing status-effect assertions. It exercises intros,
phase attacks, joint transforms, death transitions, boss fire immunity, player
and enemy damage through armour, water, firepit contact and icon loading.
The check caught and fixed an inferred-type error in the new tail animation.
It also updated an older signed-stat test fixture to use a positive baseline
after the game's starting stats changed to zero. Headless shutdown still
reports resource cleanup warnings; no visual or audio playthrough was done.
