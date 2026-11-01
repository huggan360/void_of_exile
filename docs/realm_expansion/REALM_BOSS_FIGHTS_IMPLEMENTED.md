# Realm boss fights — implementation report (31 October 2026)

Implements `CLAUDE_REALM_BOSS_FIGHTS.md`. **All five stronghold encounters are live**: Blue Dragon (Azure Crucible), Rimeheart Prism (Crown of the Rime), Vharok (Cinder Bastion), Aureate Scarab Regent (Court of the Sun) and The Hollow Crown (Hollow Throne). One encounter per stronghold, placed by the stronghold feature itself (never by biome spawns), with a permanent no-respawn clear.

## Shared lifecycle (`scripts/enemies/boss.gd`)

- **Sealed shell**: each boss sleeps in its own shell model. Walking near is safe. Player hits wear down a separate shell health (defense 0, scaled +20% per extra player at the first hit). Cracks appear at 75/50/25%: real gaps are carved into the shell and the light inside shows through. Shell damage gives no loot credit, XP or contribution. The boss bar shows a stone-gray "SEALED" bar.
- **Hatch**: harmless shell fragments, a light pulse, a restrained camera shake, and the boss unfolding over its hatch time while its bar fills. Health is scaled once at the end (`base × (1 + 0.2 × (N−1))`, players within 45 m) and frozen for the attempt. No damaging attack for 1 s after that.
- **Phases** move only forward. A hit that crosses a threshold stops at it. Support HP scales by `1 + 0.35 × (N−1)`.
- **Support registries**:
  - `objective`: crystal conduits and Cinder Sentinels.
  - `guard`: Blue's dragonlings, shown as bar pips.
  - `add`: shardlings, pact mites, Dawn Scarabs and Mirror Shades.

  Encounter cleanup uses `Enemy.despawn()`, which never pays rewards. Blue's dragonlings still give their normal rewards when a player kills them.
- **Hazards** (`boss_hazards.gd`): circles that erupt once, burning patches with a tick, lanes, curtains between towers, and sweeping rays. Each shows a warning whose fill grows until it fires. Positions lock when marked. Hit groups mean any one hazard system hits a player at most once per tick.
- **Projectiles** (`enemy_bullets.gd`):
  - explicit collision radii
  - returning discs, which fly back to the throw point and hit at most once per leg, 0.6 s apart
  - orbs that contract for 0.4 s, then release needles that skip whoever the orb hit
  - shared hit lists for multi-piece attacks (a cleave's two crescents hit once)
  - new shapes: needle, disc, crescent, shard, comet
  - encounter-owned shots, retired on death or reset
- **Death**: every hazard, scheduled windup, owned shot and summon is switched off before the glow/burst. Rewards are rolled once, with eligibility judged against the attempt's **scaled** maximum HP (the old base-HP mismatch is fixed).
- **Abandon**: 15 s with no player within 28 m removes everything the encounter owns and restores a fresh shell (a retry, not a respawn).

## Encounters

| Boss | Shell | Shell HP | Hatch | HP | Phases (as specified) |
|---|---|---:|---:|---:|---|
| Blue Dragon | Azure egg, scales and cyan seams, stone nest | 2,000 | 5.0 s | 40,000 | Existing three phases unchanged; guard pips; summons now despawn silently at death |
| Rimeheart Prism | Squat hex frost geode | 1,500 | 4.5 s | 44,000 | Sealed Heart → Hexagonal Conduit (6 towers on fixed 6.2 m sockets, 0.15%/s heal each up to 70%, 35% floor, defense 14 + 2/tower, alternating curtains 0.8 + 2.0 + 3.2 s, shardlings ≤6, 3 s stun at defense 4) → Rime Tempest (8 rad/s visual spin, 0.55 rad/s streams, comets) |
| Vharok | Black cocoon in a red rock cradle | 2,200 | 5.0 s | 48,000 | Obsidian Warden → Furnace Pact (2 Sentinels hold an immunity shield; branded circles only; mites in pairs, ≤4 alive, ≤8 total; 2.5 s kneel; marked charges) → Heart Unbound (marked slams + shield-blockable ring that skips slam victims, 7-fireball fans, crossing lanes, no permanent lava) |
| Scarab Regent | Gold/ivory reliquary with a pink slit | 1,800 | 4.2 s | 42,000 | Gilded March (clockwise 3 m circle, needle fans, returning disc) → Wings of Noon (6 optional Dawn Scarabs, two opposite 45° sweeping rays) → Exposed Sunheart (locked charge lanes, 2.5 s heart exposure at defense 6, gapped rings, staggered comets) |
| Hollow Crown | Black reliquary bound by floating crown shards | 1,600 | 4.6 s | 46,000 | Veiled Monarch → Court of Echoes (3 optional Mirror Shades; teleport = sigil 0.85 s ahead, dissolve, ≤0.15 s untouchable transit, reassembly, then 0.6 s with no attacks; seams; orb) → Crown Unbound (spirals, cyan null-ring, hollow cross, crown-collapse circles) |

Damage values, timings, defenses, summon caps and loot match the brief. Every listed attack is normally mitigated except the deliberately magic, shield-blockable ones: Blue's wing beats, Vharok's slam ring and the Crown's null-ring.

## Models (`tools/make_realm_bosses.py` → `creatures/<id>/`, editor scenes rebaked)

- **New shells**: `egg_blue_dragon`, `egg_rimeheart`, `egg_vharok`, `egg_scarab`, `egg_hollow_crown`, each with crack1–3 variants.
- **New forms**: Vharok `heart_unbound` (opened chest, exposed heart, chipped horn, torn wings); Scarab `sunwings` (opened elytra, wider wings, four lenses) and `sunheart` (cracked breast, pink/white heart, damaged wing tips, broken halo); Crown `fractured_court` and `unbound` (split or detached crown, displaced tablets, larger core, opened robe seams).
- **New minions**: `cinder_sentinel`, `dawn_scarab`, `mirror_shade`. Shardling and conduit are promoted from staging; the conduit has new lower attack ports.
- **Refinements**:
  - Crystal: fracture veins, chipped facets, asymmetric rime.
  - Demon: brow ridge, jaw, irregular teeth, horn grooves, hooked claws, split hooves, shoulder blades, wing veins.
  - Scarab: chitin segments, knee/hip joints, kohl-carved mask, jewels.
  - Crown: genuinely hollow hood, bony fingers, asymmetric torn robes, etched tablets.

  These are additive refinements, not full re-sculpts.

## Loot

Every set item rolls an independent 3% per eligible player, in personal white bags:
- Frost: 11 items
- Satan: 3 items
- Holy Divine: 4 items
- Void: 5 items
- The Blue: 5 items

The aliases are `D_bonus_crucifix_ofsatan` and `D_bonus_flame_ofthedivine`. The allowlist (`Items.BOSS_DIVINE_SET`) is used by the item catalog, the importer and `Loot._allowed()`, so only a boss's own set can drop.

Non-divine rewards and stat potions follow the brief's tables, including the 90% rate for non-top contributors on personal non-divine rolls. The Void set's dark items now use white bags, as the brief requires. Documentation is regenerated from the live tables by `tools/document_divine_boss_sets.py`.

## Tests

- `tools/test_realm_boss_fights.tscn` (new): 171,837 checks, 0 failures. Covers:
  - per-item 3% rates and whole-set rates over 6,000 seeded kills per boss
  - scaled-HP eligibility
  - shell safety, cracks and hatch
  - debug skips into every phase, with each phase's objectives checked: exact hexagon sockets, heal rate and 70% cap, the 35% floor, the stun, Sentinel-only immunity, the mite cap, optional adds removed before final phases, teleport bounds
  - death clearing all hazards and summons first, rewards once, permanent clear
  - abandon reset
- Updated and passing:
  - `test_realm_boss_art` (715 checks, live models)
  - `test_realm_integration` (102,704 checks)
  - `test_settlements` (7,159 checks)
  - `test_god_batch_02`, `test_outdoor_towns`, `test_home_village`

Debug captures: `--world=realm --boss=blue|frost|lava|desert|dark [--hatch] [--boss-phase=N] [--wait=S] [--overview=34]`.

## Not done / differences from the brief

- **No audio cues**: the project has no audio system yet.
- **Shared choreography**: hatch and death sequences use a shared procedural unfold and burst, tinted per boss; the Rimeheart rises from its geode and Vharok flaps on death. Bespoke per-boss choreography (six geode wedges, horns tearing the cocoon, cloak peeling into ribbons) is not authored.
- **Vharok's aerial slam** hops him to the locked spot at impact instead of flying a visible arc.
- **No afterimages**: the Hollow Crown's teleport leaves dissolving voxels only.
- **Cycles pause during locks**: teleports and the post-hatch window pause a boss's cycle clock, so cycles run slightly longer than written.
- **Not playtested**: balance was not playtested with weak/high-level gear. Values match the brief, and visuals were checked in gameplay captures.
- **Not network-authoritative**: hits are still detected client-side, as before.
