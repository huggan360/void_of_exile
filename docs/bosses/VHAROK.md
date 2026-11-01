# Vharok, the Cinder Tyrant

The existing Lava Boss Fight Watcher uses this fight automatically.

- Phase 1, 100–65% HP: stationary in the center. Six white voxel embers fire every 0.5 seconds, with each volley rotated 15 degrees into a six-arm spiral. Each ember deals 45–60 raw damage. Fans, full-size swept-back flame cleaves and brands repeat on a 5.2-second cycle.
- Phase 2, 65–30% HP: returns to the center only if displaced; normally already centered. Four Cinder Sentinels occupy diagonal sockets at a 10-meter radius. Vharok remains stationary and immune while any sentinel survives. Small flame crescents fire in eight equally spaced directions every 0.8 seconds; successive rings alternate between 0 and 22.5 degrees. This continues through the guarded and charging portions, with no firing during intermissions or the initial summon delay. Shards deal 55–70 raw damage and use the same curved collision silhouette as the large flame shard at 32% scale. Bounded Ember Mite summons remain centered during the guarded portion.
- After the sentinels die: a three-second kneeling intermission, then 0.8-second marked charge windups. Charges travel up to 24 meters at 12 meters/second within a 24-meter arena radius. Contact deals 135–160 armor-piercing damage once per player per charge, before shield absorption, and knocks them perpendicular to the charge at 14 meters/second. Player bodies cannot stop the charge; terrain and structures still can. Contact is swept across each movement step so fast motion cannot miss a player. Aimed fans follow each charge, with shorter recovery.
- Phase 3, below 30% HP: slams, fans, wide cleaves and crossing molten lanes repeat on a 7.5-second cycle. Larger range and placement bounds use the expanded stronghold.

Damage is before player defense. Existing HP scaling, phase thresholds, helper HP scaling and loot remain in effect.

## Art and animation

Vharok retains a coarse 32-cell design expanded into the 256-cell canvas. His native geometry now has bent knees, staggered feet, a lower forward-set torso, jagged shoulder armor and a heavier brow. Dedicated replicated poses cover casting, summoning, cleave anticipation/release, charge anticipation/travel/recovery, slam and stagger. The tyrant profile suppresses idle flapping, waddling, elastic scale and hopping.

`python3 tools/update_vharok_art.py` regenerates only Vharok and the small flame shard/white ember assets. `tools/bake_realm_boss_art.gd -- --only=vharok_cinder_tyrant` updates his editable Godot scenes and meshes.

Implementation and asset generation only; no combat tests or fight previews were run for this pass.

## Intermissions, summons and jointed legs

Every HP phase transition now cancels pending attacks, hazards, charges and existing encounter bullets, and holds Vharok stationary and invulnerable for three seconds. He drops to one knee, briefly flashes white with voxel fragments at 2.25 seconds, then rises over the final 0.75 seconds. The same pause separates the sentinel section from the charging section. The final death sequence holds the one-knee defeated pose until the voxel burst.

At the start of Furnace Pact, the four sentinels materialize through glowing cinders and a short light pulse. Vharok and the sentinels hold their attacks for two seconds after summoning. Ember Mite summons use the same entrance and two-second first-volley delay. The boss remains in the center for these summons.

Vharok now has separate thigh and shin bones. Sprinting uses alternating long hip strides, bent-knee recovery and opposing arm swings; the kneeling and rising poses use the same joints. The native low-resolution masters and editable Godot scenes include the new leg hierarchy.

## Large shard penetration

The full-size flame cleaves pierce players and shields and ignore armor. They continue flying after contact; the shield still flashes, scatters impact voxels and absorbs its normal share of the hit. Each player takes damage once per cleave attack, shared across its two large shards. Terrain and structures still stop them. Small ring shards retain their existing hit behavior.
