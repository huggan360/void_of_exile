# Legendary signatures and Artifacts

The live source is `items/signatures.json`. Each Legendary item is independent
of its boss's Divine set, including its palette, silhouette and projectiles.
Legendary inventory slots glow blue; Artifacts glow green. Both are soulbound
and use black chests. Divine items always use white. A mixed drop keeps all
distinct special items in one black chest. Collectible Artifacts also preserve
useful graded items of the same kind rather than replacing that reward.

## Legendary boss drops

42 Legendary items cover 29 bosses, one or two per boss. These are personal
per-item base chances before contributor share and loot-chance modifiers.

| Boss | Legendary items | Base chances |
| --- | --- | --- |
| `goblin_king` | Kingfisher (Bow); The Turnkey (Talisman) | 2.75%; 3% |
| `mad_farmer` | Wand of Ash (Wand); Sunday Best (Cloak) | 3%; 3% |
| `thornmaw_bloom` | Thornclock (Bow) | 2.5% |
| `blue_dragon` | Tideglass (Trident); Harborlight (Robe) | 2.25%; 2.75% |
| `rimeheart_prism` | Sunsplinter (Wand) | 2.25% |
| `vharok` | Black Comet (Bow) | 2% |
| `scarab_regent` | The Mirage Engine (Wand) | 2.25% |
| `hollow_crown` | Crownbreaker (Trident) | 2% |
| `hollow_king` | The Second Hand (Bow); The Last Word (Cloak) | 1.75%; 2.25% |
| `abyssal_siren` | The Silent Bell (Wand); A Held Breath (Crystal) | 2.25%; 2.75% |
| `drowned_cantor` | Bellwether (Trident) | 2% |
| `gilded_vizier` | False Promise (Bow); The Counterfeit King (Robe) | 2.25%; 2.75% |
| `magma_warden` | Cold Verdict (Trident) | 2.25% |
| `pyre_ent` | Seed of Tomorrow (Wand) | 2% |
| `queen_briarrose` | Heartwood Engine (Bow); Second Heart (Cloak) | 2%; 2.5% |
| `amber_colossus` | Timesunder (Trident) | 2% |
| `selenarch` | Daybreaker (Wand); No Sun at Noon (Robe) | 1.75%; 2.25% |
| `brood_matriarch` | Threadcutter (Bow); Unravelled (Cloak) | 1.75%; 2.25% |
| `stormeye_tyrant` | The Eyeless (Trident); Clear Weather (Eye) | 1.75%; 2.25% |
| `veil_herald` | Stillpoint (Wand) | 2% |
| `void_empress` | Event Horizon (Bow) | 1.75% |
| `mother_mycora` | Dewglass (Wand) | 2.75% |
| `captain_saltmourn` | Landfall (Bow); Dry Land (Cloak) | 2.5%; 3% |
| `ixalith` | Sunfeather (Trident) | 2.25% |
| `lantern_shepherd` | The Wakeful (Wand) | 2.25% |
| `jarl_hrimvald` | The Ninth Sun (Bow) | 2% |
| `solenne` | Kaleidoscope (Bow) | 1.75% |
| `choirless_seraph` | Counterhymn (Wand); Wordless (Robe) | 1.75%; 2.25% |
| `oblivara` | Worldneedle (Trident); The Whole Stitch (Cloak) | 1.75%; 2.25% |

## Artifact collectibles

Artifacts are only weapons or armor. They trade combat efficiency for display
patterns and luminous appearances; none is a bonus item or a spell.

| Artifact | Boss | Display | Base chance |
| --- | --- | --- |
| The Last Firework (Wand) | `magma_warden` | A huge, slow fireball that bursts into 28 multicolored sparks; the charged finale has 36. About 15.4 seconds between normal shots before Dexterity. | 1% |
| Midsummer (Bow) | `queen_briarrose` | Twelve curving petals around the wearer; the charged crown adds shots above them. | 1% |
| Pocket Planetarium (Wand) | `solenne` | Ten little worlds on curved paths above and around the wearer; 24 when charged. | 1% |
| A Very Bad Idea (Trident) | `veil_herald` | Fourteen wandering splinters in a sphere; the charged display has 24. | 1% |
| Star Parade (Cloak) | `void_empress` | A luminous midnight cloak, floating crown, multicolored motes and a small light source. | 1% |
| An Impossible Morning (Robe) | `oblivara` | A luminous pale-green robe, floating crown and drifting lights. | 1% |

## Weapon budgets

Legendary primary attacks have individual damage budgets, ranging from about
58% to 116% of the same weapon kind's G8 primary output. There is no rarity
floor: a Legendary can have less damage or fewer stats than a graded weapon.
Firing patterns, range, status effects and charged shots supply distinct
tradeoffs. Total projectile shares and fire rate are included in the raw
comparison; Attack, Dexterity, defense and how many shots hit affect real output.
Every primary volley has shares summing to one; radial bursts have bounded
total shares and cannot spawn recursively. A weapon switch in flight does not
substitute the newly equipped weapon's base damage into a firework burst.

All Legendary weapons have dedicated cut-glass projectile meshes and colored
particle trails. The shapes echo Refraction's appeal while using distinct
lances, crescents, comet clusters, open bells, seed stars and crystalline discs.
Charged attacks release controlled volleys or a central gem that splits.

| Weapon | Damage per shot before share | Projectiles | Base rate multiplier | Projectile |
| --- | ---: | ---: | ---: | --- |
| L Kingfisher | 148-174 | 2 | 1.015 | `legend_kingfisher` |
| L Wand of Ash | 121-142 | 2 | 1.0 | `legend_ash` |
| L Thornclock | 151-177 | 3 | 1.065 | `legend_thornclock` |
| L Tideglass | 238-279 | 3 | 0.915 | `legend_tideglass` |
| L Sunsplinter | 118-139 | 2 | 1.0 | `legend_sunsplinter` |
| L Black Comet | 223-263 | 1 | 1.065 | `legend_blackcomet` |
| L The Mirage Engine | 152-178 | 3 | 0.975 | `legend_mirage` |
| L Crownbreaker | 259-304 | 3 | 0.94 | `legend_crownbreaker` |
| L The Second Hand | 214-251 | 2 | 1.065 | `legend_secondhand` |
| L The Silent Bell | 131-153 | 1 | 0.975 | `legend_silentbell` |
| L Bellwether | 237-278 | 3 | 0.94 | `legend_bellwether` |
| L False Promise | 192-225 | 2 | 1.065 | `legend_falsepromise` |
| L Cold Verdict | 235-276 | 2 | 0.915 | `legend_coldverdict` |
| L Seed of Tomorrow | 135-159 | 1 | 1.0 | `legend_seed` |
| L Heartwood Engine | 175-205 | 3 | 1.065 | `legend_heartwood` |
| L Timesunder | 243-286 | 2 | 0.915 | `legend_timesunder` |
| L Daybreaker | 163-192 | 1 | 1.0 | `legend_daybreaker` |
| L Threadcutter | 218-257 | 2 | 1.065 | `legend_threadcutter` |
| L The Eyeless | 294-345 | 3 | 0.915 | `legend_eyeless` |
| L Stillpoint | 168-197 | 1 | 1.0 | `legend_stillpoint` |
| L Event Horizon | 248-291 | 3 | 1.065 | `legend_eventhorizon` |
| L Dewglass | 101-118 | 1 | 0.975 | `legend_dewglass` |
| L Landfall | 174-204 | 1 | 1.04 | `legend_landfall` |
| L Sunfeather | 215-252 | 4 | 0.965 | `legend_sunfeather` |
| L The Wakeful | 141-164 | 1 | 0.975 | `legend_wakeful` |
| L The Ninth Sun | 279-327 | 3 | 1.04 | `legend_ninthsun` |
| L Kaleidoscope | 252-297 | 3 | 1.065 | `legend_kaleidoscope` |
| L Counterhymn | 169-198 | 2 | 0.975 | `legend_counterhymn` |
| L Worldneedle | 319-375 | 1 | 0.94 | `legend_worldneedle` |
| A The Last Firework | 180-220 | 1 | 0.065 | `festival_orb` |
| A Midsummer | 82-102 | 12 | 0.46 | `petal_kite` |
| A Pocket Planetarium | 68-88 | 10 | 0.5 | `orbit_pearl` |
| A A Very Bad Idea | 72-92 | 14 | 0.4 | `clock_shard` |

## Appearance and source art

Every new weapon and armor piece has an icon and a character appearance.
Weapon variants keep the existing hand sockets and animated string fitting.
Signatures add distinctive metalwork, crystal tips, palettes and collar motifs.
Artifact garments use the existing rear-cloth vertex mask for emission, so
unequipping restores the normal material. Local players, remote players and
portraits all use `EquipmentAppearance`.

Regenerate the authored 8x8 PNG and Pixelorama files with
`python3 -B tools/make_signature_art.py`, then worn models with
`python3 -B tools/make_equipment_models.py`. Editable sources are under
`~/Documents/Voidrealm_textures/Legendary/` and `Artifacts/`.

## Checks

`tools/test_signature_items.tscn` exercises real firing, charge patterns,
projectile trails, terminal firework lifetimes, mixed loot, boss restrictions,
appearance changes and remote Artifact glow. `tools/test_divine_legendary.tscn`
covers Divine loadouts and inventory migrations. `tools/test_equipment_appearance.tscn`
covers every compatible class/weapon/armor combination. Use
`tools/preview_signature_items.tscn` for rendered figures and projectile reviews.
