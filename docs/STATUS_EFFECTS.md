# Timed buffs and debuffs

Grant effects on the server (or offline GameServer). Clients cannot grant buffs.
Durations accept seconds as numbers, or strings such as `"3s"`, `"2m"`, `"250ms"`, `"1h"`.

```gdscript
GameServer.apply_buff(player_id, "speed", "10s", 3, "fountain")
GameServer.apply_buff(player_id, "attack", "5s", -3, "curse")
GameServer.apply_buff(player_id, "stasis", "3s")
GameServer.apply_buff(player_id, "quiet", "3s")
GameServer.apply_buff(player_id, "armour_broken", "8s")
GameServer.apply_buff(player_id, "regeneration", "20s", 2.3) # 230% healing rate
GameServer.apply_buff(player_id, "loot_chance", "2m", .25) # +25% relative drop chance
GameServer.apply_buff(player_id, "loot_tier", "2m", .50) # 50% chance of a one-grade upgrade
GameServer.remove_buff(player_id, "speed", "fountain")
```

Attach metadata to any EnemyBullets attack, including a terminal child's attack:

```gdscript
attack.effects = [
    {id = "stasis", duration = "3s"},
    {id = "speed", amount = -3, duration = "8s"},
]
attack.effect_source = "ice_trap" # optional; otherwise the enemy's id/name
bullets.fire(origin, direction, attack, self)
```

For melee, a zone, a consumable or a scripted reward, call `GameServer.apply_buff` /
`GameServer.apply_effects` from server code when contact is confirmed. Player and
NetPlayerProxy both expose `player_id`. Existing enemies do not acquire new crowd
control attacks automatically; choose the attacks by setting the metadata above.

| Effect id | Amount | Gameplay | Banner |
| --- | --- | --- | --- |
| speed | signed points | Movement speed | green / red |
| attack | signed points | Weapon damage | green / red |
| dexterity | signed points | Shot rate | green / red |
| defense (or defence) | signed points | Normal-hit mitigation | green / red |
| magic | signed points | Spell damage and MAG-based shield protection | green / red |
| hp (or health) | signed points | Maximum health | green / red |
| mp (or magic_points) | signed points | Maximum magic points | green / red |
| regeneration (or regen) | multiplier, 2.3 = 230% | Health regeneration; beneficial regeneration bypasses hurt delay | green if >=1, red otherwise |
| mana_regeneration (or mp_regen) | multiplier | Magic regeneration | green if >=1, red otherwise |
| static (or stasis/frozen/freeze) | omitted | Stops horizontal movement and knockback; still allows attacks | blue |
| quiet (or silence) | omitted | Blocks weapons, charge, windup and queued bursts; shield/spells remain usable | blue |
| armour_broken (or armor_broken) | omitted | Removes equipped-item defence, preserves base defence and direct buffs | purple |
| loot_chance | fraction, .25 or "25%" | Multiplies drop probability by 1.25, capped at 100% | yellow |
| loot_tier | probability, .5 or "50%" | Already-dropped graded gear can rise exactly one grade | yellow |

Stat amounts also accept `"+max"` and `"-max"`. Since this game has no fixed stat cap,
these add/subtract the current **unbuffed total**: +max doubles it, -max removes it.
Stats are floored at zero, max health at one and max mana at zero. Max-health
increases grant capacity, not free healing. Expiry/removal clamps current resources.
Changing gear recalculates the underlying values without baking buffs into gear or base stats.

The same effect id + source refreshes/replaces its value and duration. Different
sources coexist, add stat points/loot probabilities, and multiply regeneration rates.
Expiry is independent per source. Effects continue while traveling, but clear on
death, character changes and disconnect; they are never saved into character data.
Limits: 64 concurrent sources/effects, durations at most 24 hours.

Public loot rolls once using the highest damage contributor's loot bonus. Personal
rolls use each eligible player's bonus, preserving existing damage eligibility.
An upgraded public item becoming soulbound is put in its contributor's personal bag.
Tier upgrades keep the same item family, stop at G8, and leave consumables, Divine
items and gear without a next grade unchanged. An upgrade can exceed the enemy's
normal drop cap by one grade; this is the purpose of the tier bonus.

The server owns amounts, expirations and loot rolls. Reliable revision updates send
current effects to the owner and nearby observers, including players entering view.
Clocks account for network transit time. Enemy impact reports reference server-issued
projectile ids, checked for realm, lifetime, reach and duplicate claims, using the
existing client-hit/server-resolution combat model. Terminal children are supported.
Matching client/server builds are required: protocol 3.

HUD: four flags per row in the gap between HP/MP and the minimap; extra rows grow
upward. At narrow UI sizes the strip fits above the minimap. Timers show s/m/h, with
pop-in and shrink/fade-out effects. Authored 8x8 icons are centered at (4,4) in the
16x16 banners. Icons have white outlines and flags have black outlines; the
extra outer pixel makes each rendered composite 18x18 without cropping source art. The same composites appear above player names. Static grows voxel
ice; Quiet adds a blue voxel seal; other effects show small colored orbiting voxels.

## Art and verification

Source: `/home/hugo/Documents/Voidrealm_textures/buffs/` (Pixelorama + PNG icons).
Runtime: `res://buffs/`. Reimport just buffs after editing Pixelorama files:

```sh
python tools/import_textures.py --buffs-only
```

Focused regression scene: `res://tools/test_status_effects.tscn`.
Interactive visual preview: `res://tools/buff_watch/preview.tscn`.

Verification: 72 focused status checks, 52 shield-combat regression checks, and 29
checks across a real ENet server and two clients. Run the network fixture with
`python tools/net/check_status_effects.py` (localhost port 24783).

The two loot icons used the built-in image_gen tool; the final prompt set is saved
in `/home/hugo/Documents/Voidrealm_textures/buffs/icons/loot_generation_prompts.json`.
