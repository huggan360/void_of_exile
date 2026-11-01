# Server config

Edit, then restart the server. Missing files are recreated with the game's current values.

* **server.cfg**: the important switches.
  * `[server]` name (shown in the server list), port (UDP; status ping uses port+1), max_players, motd,
    public (also list for players on other networks), lan_discovery, data_dir (realm records).
  * `[realms]` max_players_per_realm, max_realms, unload_after_empty (seconds).
  * `[gameplay]` player_collision (players block each other and each other's shots), xp_multiplier,
    enemy_hp_multiplier, enemy_damage_multiplier, spawn_density_multiplier, godmode.
  * `[network]` tick_rate (snapshots/s), interest_radius (m), event_radius (m), max_speed_tolerance.
  * `[accounts]` url (account service), server_key (from `void_accounts.py new-server-key`),
    save_interval, heartbeat_interval (seconds).
* **enemies.json**: per enemy: hp, defense, xp, move_speed, aggro/lose radius, keep_distance,
  wander_radius, damage_multiplier, attack_speed_multiplier, projectile_speed_multiplier.
* **bosses.json**: per boss: hp (solo), defense, xp, shell_hp, hp_per_extra_player,
  support_hp_per_extra_player, intro_time, abandon_radius/time, bar_radius, damage_multiplier
  (all its shots, ripples and hazards).
* **loot.json**: bag lifetimes; per enemy loot_threshold and loot table.
* **spawns.json**: density_multiplier; every pack (members, leader, respawn_time, activate_radius);
  which packs live in each biome and their density.
* **player.json**: regen, shield, ring, XP orb tunables; the starting kit of new characters.
