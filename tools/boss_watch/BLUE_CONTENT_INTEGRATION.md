# Blue dungeon enemy contract

Dungeon layout/server integration belongs to the concurrent dungeon job.

- `azure_grotto`: Bluelay, flooded crystal grotto, 5.5/10. Low: `grotto_crab`, `tide_wisp`, `coral_skitter`. Mid: `deep_angler`, `reef_guardian`. Miniboss: `brine_matron`. Boss: `abyssal_siren`.
- `drowned_spire`: Bluelay, sunken bell tower, 6.5/10. Low: `drowned_acolyte`, `spire_eel`, `bubble_jelly`. Mid: `tide_knight`, `choir_wraith`. Miniboss: `bell_warden`. Boss: `drowned_cantor`.
- Both boss cycles assume at least 14m of clear floor around their spawn; projectiles reach 26m. No damaging water floor is required.
- Campaign packs: `tide_heralds` (4–6), `spire_keeper` (leader `spire_keeper`, The Spire Keeper), `dark_stalkers` (4–6), `hollow_ambush` (6).
- Portal gods: `blue_genie` -> `azure_grotto`, `azure_medusa` -> `drowned_spire`, each 15%.
- Loot and three-phase fight scripts are wired through `BlueDungeonEnemies.build`.
- Offline watchers: `watch_abyssal_siren.sh`, `watch_drowned_cantor.sh`; they use the existing blue stronghold arena and isolated user data.
