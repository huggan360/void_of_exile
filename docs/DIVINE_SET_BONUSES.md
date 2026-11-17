# Divine set bonuses

Equip different pieces of a matching Divine set in weapon, armor, spell and
bonus slots. Stages I, II and III unlock at 2, 3 and 4 equipped pieces. Every
unlocked row adds to the previous rows and to each item's own stats. A cloak
and a robe share one slot; inventory copies and Legendary/Artifact pieces do
not count. Two pieces from each of two sets grant both first stages.

The game hover footer shows a 20px red banner, gold trim, a pink 8x8 D icon,
and Roman stage pills. Active rows are bright; locked rows are muted. The wiki
uses the same definitions below item stats and on the set index. Player-page
hovers use actual equipped counts, while wiki pages show all possible stages.

Most stages have at most four stat types. Madness deliberately uses five on
stages II and III, matching its small all-round bonuses. Holy Divine favors
health and mana; Iron favors attack and movement. Sets have deliberately uneven
power and distinct roles. This is an initial balance pass, not a claim of equal
combat performance across every build.

| Set | I: 2 equipped | II: 3 equipped | III: 4 equipped |
| --- | --- | --- | --- |
| Spirit | +1 SPD | +1 SPD, +2 MAG | +2 DEX, +3 MAG, +15 MP |
| Iron | +2 ATK | +2 ATK, +1 SPD | +3 ATK, +2 SPD, +1 DEX |
| Storm | +1 SPD | +2 MAG, +15 MP | +2 SPD, +3 MAG, +20 MP |
| Silver | +1 DEF | +2 MAG, +15 MP | +2 DEF, +2 MAG, +20 MP |
| Dragon Fire | +1 ATK | +2 MAG, +10 MP | +2 ATK, +3 MAG, +15 MP |
| Fallenwood | +10 HP | +1 SPD | +20 HP, +1 SPD, +1 DEX |
| The Blue | +15 MP | +2 MAG, +15 MP | +4 MAG, +25 MP |
| Frost | +1 MAG | +1 DEF, +15 MP | +3 MAG, +2 DEX |
| Satan | +2 ATK | +2 ATK, +1 MAG | +2 ATK, +3 MAG |
| Holy Divine | +20 HP | +25 HP, +2 MAG | +35 HP, +20 MP, +3 MAG |
| Void | +20 MP | +2 MAG, +20 MP | +4 MAG, +25 MP |
| Venom | +1 DEX | +1 SPD, +1 DEX | +3 DEX, +2 ATK |
| Eclipse | +1 MAG | +2 MAG, +15 MP | +3 MAG, +25 MP, +1 SPD |
| Blood | +1 ATK | +15 HP, +1 ATK | +25 HP, +2 ATK |
| Stormeye | +1 DEX | +2 MAG, +1 DEX | +3 MAG, +2 DEX, +15 MP |
| Madness | +1 SPD, +1 ATK, +1 MAG | +1 SPD, +1 MAG, +1 ATK, +1 DEF, +1 DEX | +1 SPD, +1 MAG, +1 ATK, +1 DEF, +1 DEX |
| Cindrella | +1 SPD | +1 DEX | +2 SPD, +2 DEX |
| Goldslinger | +1 DEX | +1 ATK, +1 DEX | +2 ATK, +3 DEX |
| Mycelium | +15 HP | +15 HP, +15 MP | +25 HP, +20 MP, +1 MAG |
| Saltmourn | +1 DEF | +1 ATK | +2 DEF, +2 ATK |
| Jade | +1 SPD | +2 MAG | +2 SPD, +3 MAG, +15 MP |
| Afterlife | +1 SPD | +1 DEX, +10 MP | +1 SPD, +2 DEX, +15 MP |
| Barrow | +15 HP | +1 DEF, +15 HP | +2 DEF, +25 HP |
| Prism | +1 MAG | +2 MAG, +1 DEX | +3 MAG, +2 DEX |
| Requiem | +15 MP | +2 MAG, +15 MP | +3 MAG, +25 MP |
| Unmade | +1 ATK | +2 MAG, +1 DEX | +1 ATK, +2 MAG, +2 DEX |

Source: `items/divine_set_bonuses.json`; runtime: `DivineSetBonuses` and
`PlayerStats.gear_bonus`. `tools/export_review_catalog.gd` exports each item's
`set_bonus` object and the full definition table for the website data builder.

Validation: `tools/test_divine_set_bonuses.tscn` exercises every set through real
equip/unequip, cumulative thresholds, mixed sets, backpack exclusion, save/load,
resource clamping and spell preview paths. `tools/preview_divine_sets.tscn`
renders locked, partially unlocked, health-focused and Madness hover cards.
