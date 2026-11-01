# Account service (player sync)

`void_accounts.py`: Python 3 stdlib + SQLite, no dependencies. Deployed on the Pi in `~/void_accounts`
(systemd unit `void-accounts.service`, Apache vhost `void.plainshow.se.conf`, listening on
127.0.0.1:8095). `config.json` holds the server keys and options; `void_realms.db` the data.

Tables: `accounts`, `sessions`, `characters` (living; full state as JSON + a lease to one game server),
`dead_characters` (moved here on death with killed_by/realm/server), `character_items` (one row per
carried item, kept for dead characters too), `servers` (heartbeats; listed to clients on the same public IP),
`friends` (one-way follows between accounts), `campaigns` (one JSON book per account with its last
update time). New tables are created automatically for existing databases.

Deploy changes: `scp void_accounts.py hugohansson@192.168.1.5:void_accounts/ && ssh hugohansson@192.168.1.5 sudo systemctl restart void-accounts`

Accounts have XP and levels (`xp_to_next`, `REWARDS`: character slots and starting gear grades; `base_slots`
in config.json). Endpoints added: `/characters/delete`, `/graveyard/delete`, `/singleplayer` (a 12 h key that
lets the player's own Singleplayer server touch only their account). `/server/save` and `/server/die` take
`account_xp`; `die` also adds 25% of the character's total XP plus the value of what it carried.

Campaign progress follows the account between game servers and Singleplayer. The game owns the
book's format, including campaign runs and the saved state of each campaign's private world:

- `POST /server/campaigns/load` with `{account_id: int}`: `{book: {...}}`, or `{book: {}}` if unsaved.
- `POST /server/campaigns/save` with `{account_id: int, book: {...}}`: `{ok: true}`. Replaces the whole
  book; it must be an object (400 otherwise), at most 2 MiB of compact UTF-8 JSON (413 otherwise).
  The request allows an additional 64 KiB for the JSON envelope and formatting.
- Both server endpoints require `X-Server-Key`, like `/server/save`. Singleplayer keys can load/save
  only their own account (403 otherwise); unknown accounts return 404, invalid account IDs return 400.
- `GET /campaigns`: `{book: {...}}` for the logged-in account, using the same player Bearer token as
  `/me`. Clients have read-only access; an unsaved book is `{}`.

Friends endpoints use the same player Bearer session token as `/me`:

- `GET /friends`: `{friends: [{username, online, server, class, level, mutual}]}`, online first then by name.
- `POST /friends/add` with `{username}`: `{ok: true, friend: {...}}`. Adding is one-way, with at most
  200 friends; yourself, duplicates and the limit return 400, unknown accounts return 404.
- `POST /friends/remove` with `{username}`: `{ok: true}` (also if already absent).
- `GET /players/search?q=<text>`: `{players: [{username, online, server, friend}]}`. Case-insensitive
  username prefix, at least 2 characters (otherwise 400), at most 20 results, excluding yourself.

Presence uses unexpired leases on living characters, including the played character's class and level
in friends responses. Server labels map to heartbeat names, falling back to the label; singleplayer
shows as `Singleplayer`. Offline players have empty server/class and level 0. `mutual` means the friend
also added you. No server-key friends endpoint is needed.
