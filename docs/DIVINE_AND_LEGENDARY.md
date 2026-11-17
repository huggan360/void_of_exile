# Divine and Legendary equipment

Divine (`D`, tier 0) items belong to boss-themed sets. Legendary (`L`, tier -1)
items are standalone boss signatures. Artifacts (`A`, tier -2) are collectible
weapons and armor focused on spectacle. All three rarities are soulbound.

Divine inventory slots glow pink and Divine items always use white chests.
Legendary slots glow blue (`#4ba9ff`), Artifact slots green (`#65ef89`), and both
use black chests. Black ranks exactly one step above white. A mixed drop uses
one black chest and preserves every distinct Divine, Legendary and Artifact
item, including several special weapons of the same kind.

There are 26 Divine sets with 147 pieces, 42 Legendary items across 29 bosses,
and six Artifacts on selected bosses. Each Legendary source has one or two
items. See [the standalone item catalog](SIGNATURE_ITEMS.md) for names, sources,
per-item chances, damage and fire rates. Legendary chances range from 1.75% to
3%; Artifacts roll at 1% before contributor share and loot modifiers.

Every Divine set has four to seven pieces. Storm, Frost, Venom, Eclipse and
Stormeye have three weapons, a cloak, a robe, one spell and one signature relic.
Each weapon has a class-compatible four-slot loadout. Cloaks and robes share
one armor slot. Divine primary damage retains its 10% reduction. On top of the
previous Divine stat pass, all equipment now reduces positive Attack by 60%
(capped at +7 per item), Magic by 20% (cap +32), Dexterity by 25% (cap +12),
Speed by 20% (cap +8), and health/mana by 10%, rounded to integers with a minimum
of +1. Defense keeps its current values and negative drawbacks remain intact.
Graded constructors, Divine definitions and signature items each apply this
shared pass once. Set-stage bonuses are separate and do not undergo this pass.

Divine sets now grant cumulative stages at 2, 3 and 4 different **equipped**
pieces. Backpack, quickslot and bag contents never count. Mixing two sets can
grant both first stages. Bonuses are derived on read, never written into base
stats or saves; losing a stage immediately clamps health and mana. Spell hover
previews account for gaining or losing stages when replacing the spell.
See [all stage bonuses](DIVINE_SET_BONUSES.md) and the shared source
`items/divine_set_bonuses.json`.

New spells keep each set's role: Dragon Fire burns, Madness stuns and slows,
Fallenwood slows enemies and heals through its shield, Blood trades health for
power, Afterlife favors speed over attack, and Unmade favors durable shielding
and silences. Iron's existing spell now has a working ring attack.

## The seven-piece sets' signature relics

| Set | Retained relic | Bonuses | Effect |
| --- | --- | --- | --- |
| Storm | Heart of the Storm | +3 dexterity, +45 hp, +4 magic, +6 speed | mp_regen = 1.2 |
| Frost | Heart of the Rime | +5 defense, +3 dexterity, +11 magic, +57 mp | shield_drain = 0.9 |
| Venom | Eye of the Swarm | +2 attack, -3 defense, +10 dexterity, +4 magic, +2 speed | Stat bonuses |
| Eclipse | Flame of the Dark Sun | +4 attack, -30 hp, +10 magic, +49 mp | Stat bonuses |
| Stormeye | The Stormeye | +8 dexterity, -20 hp, +7 magic, +41 mp, +3 speed | Stat bonuses |

## Current sets

| Set | Pieces | Items |
| --- | ---: | --- |
| Afterlife | 4 | Wand of the Last Breath; Shroud of the Ferryman; Lantern of the Shepherd; Spell of the Last Crossing |
| Barrow | 5 | Hrimvald's Oathspear; Wolfpelt of the Jarl; Shroud of the Barrow-Seer; Barrow Rune; Spell of the Winter Oath |
| Blood | 7 | Bow of the Blood Moon; Trident of the Blood Rose; Wand of Power; Mantle of the Blood Pact; Robe of Power; Crucifix of Blood; Spell of the Blood Rose |
| Cindrella | 4 | Cindrella's Twin Song; Flame of Cindrella; Mantle of the Twin Bloom; Spell of the Twin Bloom |
| Dragon Fire | 5 | Dragonbreath Longbow; Cloak of the Burning Man; Robe of the Dragon's Breath; Flame of the Broken Grove; Spell of the First Flame |
| Eclipse | 7 | Bow of the Total Eclipse; Wand of Sun and Moon; Trident of the Umbra; Spell of the Eclipse; Mantle of the Corona; Robe of the Moon-Eater; Flame of the Dark Sun |
| Fallenwood | 7 | Bow of the Fallen Woods; Rootkeeper's Trident; The King's Moss Scepter; Rootkeeper's Mantle; Mosslit Vestment; Spell of the Rootbound; Heartwood Knot |
| Frost | 7 | Bow of Frost; Wand of Frost; Trident of Frost; Spell of Frost; Cloak of Frost; Robe of Frost; Heart of the Rime |
| Goldslinger | 4 | The Goldslinger's Duster; Goldslinger's Repeater; Spell of the Golden Draw; Aurum's Lucky Coin |
| Holy Divine | 6 | Spell of the Divine; Trident of the Divine; The Wand of the Divine; Flame of the Divine; Mantle of the Dawn; Vestment of the Sun |
| Iron | 7 | Bow of the Iron Oath; Wand of the Iron Oath; Trident of the Iron Oath; Mantle of the Iron Oath; Vestment of the Iron Oath; Spell of the Iron Oath; Seal of the Last King |
| Jade | 4 | Coil of Ixalith; Quetzal Mantle; Eye of the Coil; Spell of the Feathered Coil |
| Madness | 4 | Trident of Unlimited Madness; Cloak of Unlimited Madness; Crucifix of Madness; Spell of Unlimited Madness |
| Mycelium | 4 | Puffcap Scepter; Mycelium Heart; Vestment of the Sporewomb; Spell of the Spore Bloom |
| Prism | 5 | Refraction; Spell of the Prism; Robe of Refracted Light; Heart of the Labyrinth; Mantle of Refracted Light |
| Requiem | 6 | Scepter of the Last Hymn; Bow of Stained Glass; Vestment of the Choirless; Hymn of Silence; The Unlit Candle; Mantle of the Last Hymn |
| Saltmourn | 5 | Broadside Longbow; Saltmourn's Harpoon; Captain's Stormcoat; Spell of the Riptide; Saltmourn's Anchor |
| Satan | 7 | Trident of Satan; The Wand of Satan; Crucifix of Satan; Hellstring; Mantle of the Cinder Pact; Vestment of Brimstone; Spell of the Cinder Pact |
| Silver | 5 | Silver Shield Cloak; Vizier's Quicksilver Rod; Thalao's Silver Seal; Robe of the Silver Court; Seal of the Silver Court |
| Spirit | 4 | Wand of the Spirit; Vestment of the Unquiet; Spell of the Unquiet; Spirit Knot |
| Storm | 7 | Bow of Storm; Cloak of Storm; Robe of Storm; Spell of Storm; Trident of Storm; Wand of Storm; Heart of the Storm |
| Stormeye | 7 | Bow of the Stormeye; Wand of the Pale Eye; Trident of the Deep Arms; Spell of the Stormeye; Cloak of the Pale One; Robe of the Stormeye; The Stormeye |
| The Blue | 5 | Cloak of the Blue; Spell of the Blue; Robe of the Blue; Trident of the Blue; Crucifix of the Blue |
| Unmade | 7 | Bow of the Mended Sky; Wand of the Golden Seam; Trident of Broken Stars; Mantle of Kintsugi; Robe of the Unmade; Eye of Oblivara; Spell of the Golden Seam |
| Venom | 7 | Stinger of the Brood; Wand of the Hive; Matriarch's Ovipositor; Spell of Venom; Brood Carapace; Robe of the Hive Queen; Eye of the Swarm |
| Void | 7 | Bow of Dark Matter; Cloak of the Void; Robe of the Galaxy; Trident of the Void; The Wand of Darkness; Spell of the Hollow Throne; Shard of the Hollow Throne |

## Existing inventory

Owned Ash wands migrate from `D_wand_thewandofash` to `L_wand_thewandofash`.
Each retired relic converts into the surviving relic of the same set. Multiple
copies stay in their original inventory/vault slots. Canonical IDs are used for
account save comparisons, so this conversion is not counted as new loot.

The 18 retired relic PNGs and their Godot import files are removed. Editable
Pixelorama originals are preserved under
`~/Documents/Voidrealm_textures/Retired_divine_relics/` outside the importer.
Legendary Ash art lives under `~/Documents/Voidrealm_textures/Legendary/Ash/`.
The 32 added pieces have 8x8 PNGs, editable Pixelorama sources and matching armor
appearance palettes. Rebuild their art with `tools/make_divine_set_additions.py`.

## Validation

Run `tools/test_divine_legendary.tscn` headlessly to check the catalog, playable
loadouts, actual ring collisions, loot restrictions, migration and rarity UI.
The account repository has `server/test_item_rarities.py` for the matching save
guard, forge values and vault migration. Nothing is published by these checks.
