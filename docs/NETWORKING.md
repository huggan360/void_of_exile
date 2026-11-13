# Void Realms online

Three parts:

| Part | Where | What it does |
|---|---|---|
| Account service ("player sync") | Code in the `void_of_exile_account` repo (`server/void_accounts.py`, deploy with `deploy/deploy.sh accounts`). Runs on the Raspberry Pi `hugohansson@192.168.1.5`, `~/void_accounts`, systemd `void-accounts`; `void.plainshow.se/api/` -> `127.0.0.1:8095` | Accounts, logins, every character (alive and dead) with its items, and the list of running game servers |
| Dedicated game server | Any PC: `tools/net/run_server.sh` (headless Godot, same project) | Realms, enemies and their AI, loot, XP, characters while they play |
| Client | The game | Log in (bottom left) -> **Singleplayer** or **Servers** -> play; change characters in the Tavern (top left) |

## Playing

* Nothing can be played without logging in (bottom left of the start screen: switch account, add one, log out).
* **Singleplayer** starts a server of your own on this computer (`--singleplayer`, a short-lived key from the
  account service, its own realms in `user://singleplayer`) and joins it: the same characters and items as on
  every server. It stops by itself when you leave or close the game.
* **Characters**: every account starts with 2 slots. Five classes (`scripts/game/player_classes.gd`). The picker
  top left (only in the Tavern) switches, creates and deletes characters; its Fallen tab opens each dead
  character's full record (stats, items, killer, account XP it gave).
* **Account level**: the bar at the top. The account earns all XP its characters earn; when a character dies
  it also gets 25% of all the XP that character ever earned plus the worth of what it carried
  (`item_value` in void_accounts.py). The arrow under the bar opens the reward track (`REWARDS` in
  void_accounts.py: character slots, better starting gear; most levels are open for later).
* Dying online: red voxels scatter and a gravestone rises where the character fell (it breaks breakable
  obstacles under it and pushes other players clear; later arrivals see it too). The death screen shows over
  the world (and the blood) with two choices: play another character, or create a new one.
* Low health: pixel-art blood stains creep in from the corners at 15%, 10% and 5% health (a lot when you
  die), and the screen edges pulse red under 15%, faster toward 0 (`LowHealthOverlay`).
* Realms are static: every realm is the island laid out in `res://realm/realm_layout.tscn` (villages,
  strongholds, landmarks and roads as markers and paths you can move in Godot; `realm_map.png` underneath
  for reference; terrain from seed 20261031). The procedural planner that baked it stays in
  `IslandGenerator` (no layout = seeded plan, for generated places like future portals);
  `tools/bake_realm_layout.tscn` re-bakes the layout from it (this overwrites hand edits).
* Roads and town streets: +50% walking speed. R (rebindable) escapes to the Tavern from anywhere in a realm.
* Each town's Steward (at the plaza, "Town Hall") makes it your home: you arrive there in realms; it's the
  house on the minimap. Other townsfolk have a line or two (TownTalk); talking swings the camera to the side.

## Chambers, Dots and developers

* **Chambers** (`ChambersWorld`, realm `chm_<account id>`): the account vault, through the red Chambers Gate in the
  Tavern. 4 wooden chests to start, +1 at the "chest" reward levels (`REWARDS` in void_accounts.py) and any bonus
  chests (`grant-chests`). Chests are vault bags in GameServer while you're inside (drag items as with loot chests);
  every change is saved together with the character (`/server/vault/save`, one transaction), so nothing is duplicated
  or lost. Story items can't go in.
* **Dots**: account currency (counter right of the account bar, `DotsCounter`). Dismantle items at Bram's forge in the
  Tavern (`ForgePanel` -> action `forge` -> `/server/dismantle`, which removes the item and pays in one transaction;
  values in `Dots` and `DISMANTLE_DOTS`, keep them in step). Also 250 the first time an account finishes a campaign and
  1000 for a pack (`/server/dots/award`).
* **Developers** (`set-developer NAME`): may use `/give <player> <item id> [count]` on any server.
* Graphics quality: Options -> Graphics (`GraphicsSettings`): Low / Medium / High presets plus per-feature settings,
  View distance among them (Short on Low, Medium on Medium, Far on High).
* Friends: Join shows only for a friend on another server and always lands you in that server's Tavern; on the
  same server use Go in the party list. Teleports and sends within the world you are in move you there
  without loading the world again, and changing characters in the Tavern keeps the Tavern.

    python3 void_accounts.py set-developer p1          # (0 to revoke)
    python3 void_accounts.py grant-chests p1 12
    python3 void_accounts.py fill-vault p1 ids.txt     # account must be offline; ids from tools/net/export_item_ids.gd
    python3 void_accounts.py give-dots p1 500

## Running a server

    tools/net/run_server.sh                      # uses server_config/ (created on first start)
    tools/net/run_server.sh --set=gameplay.player_collision=true --port=24565
    tools/net/run_server.sh --test               # godmode, full kits, nothing saved, weak bosses

For players outside your network, forward **UDP 24565 and 24566** (game + status ping) on the router.
Everything is configured in `server_config/` (see the README there).

## Accounts

    ssh hugohansson@192.168.1.5
    cd ~/void_accounts
    python3 void_accounts.py list                       # accounts, characters, servers
    python3 void_accounts.py create-user NAME PASSWORD
    python3 void_accounts.py set-password NAME PASSWORD
    python3 void_accounts.py new-server-key "label"     # key for another game server's server.cfg
    sudo systemctl restart void-accounts
    sqlite3 void_realms.db                               # accounts, characters, dead_characters, character_items, servers

Test accounts: `p1` / `12345` and `p2` / `12345`.

## How a fight works (client prediction, server authority)

* **Your movement** is applied immediately on your client and reported 20x a second. The server only checks
  it's believable (speed + knockback slack) and snaps you back if not.
* **Enemies run on the server.** Clients get snapshots (positions, looks) and timestamped events (shots,
  flinches, bursts, hazards, damage numbers). A client shows the world `Net.INTERP_DELAY` (0.12 s) in the
  past so enemies move smoothly and every shot leaves the enemy exactly when you see it fire.
* **Getting hit is decided by your client.** Enemy shots, ripples and boss hazards fly on every client;
  you are only hit by what touches *you on your screen*, so a shot you dodged can never hit you. The
  client reports the hit; the server applies it and decides about death. Boss melee (charges, slams) is
  detected on the server.
* **Your shots** fly on your client; a hit on an enemy is reported and checked (range, max possible
  damage for your gear) before the server applies it. Others see your shots as harmless copies.
* **Death is permanent**: the server moves the character (with what it carried) to the dead table and
  you go back to the server list to make a new one. Characters are the same on every server.

## Code map

* `scripts/net/net.gd` (autoload `Net`): modes, every RPC.
* `scripts/net/net_server.gd`: joining (claims the character from the account service), realms, ticks
  (snapshots + events per player, interest radius), checks, saving, death, status ping, LAN beacon,
  heartbeat. Each tick packs vitals, enemies and players into as few snapshot packets as fit the MTU;
  looks-only events (`COSMETIC_EVENTS`: others' shots, debris, damage numbers, shakes) go unreliably
  (`Net.c_looks`) so a lost packet never holds up shots and hits. Enemy attacks are stripped and keyed
  once per attack (`_wire_cache`). New bags and XP pickups (`xp-`) reach the whole realm.
* `scripts/net/net_client.gd`: clock sync, interpolation, enemy mirrors (`Enemy.mirror`), remote players,
  replaying events, predicted hp/mp.
* `scripts/net/realm_instance.gd`: one realm in its own physics world (SubViewport).
* `scripts/net/server_config.gd`: the config files. `scripts/net/server_browser.gd`,
  `scripts/ui/server_panel.gd`: the server list.
* Game code hooks: `CreatureModel.recorder`, `FloatingText/Debris/BlinkVoxels/CameraShake.shake_from/
  EnemyRipple/EnemyBullets.fire` send events when `Net.is_server()`; `BossHazards` replicates by id;
  `Enemy.target()` = nearest player; `EnemyDirector.players`.

## Mirroring

Everything an encounter shows reaches the clients: model calls, voxel bursts, damage numbers, shakes, hazards
(by id), rays, the boss bar, light flashes (`Boss.flash_light`), the dying glow, and each boss's own extras
through `Boss.net_visuals()` / `mirror_visuals()` (Vharok's shield bubble, Rimeheart's conduit beams).
Obstacle hits are relayed, so every player sees the chips and the damage adds up.
