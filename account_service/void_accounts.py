#!/usr/bin/env python3
"""Void Realms account service ("player sync").

One small HTTP/JSON service that owns everything that follows a player from
server to server:

  accounts          who can log in (PBKDF2 password hashes)
  sessions          login tokens handed to the game client
  friends           one-way follows between accounts (up to 200 each)
  characters        every LIVING character, linked to its account; its full
                    state (stats, gear, backpack, quickslots) is a JSON blob
  dead_characters   characters move here, unchanged, the moment they die
                    (with when, where and by what)
  character_items   one row per item a character carries, kept in step with
                    the blob on every save (dead characters keep theirs)
  campaigns         each account's campaign runs and private world as JSON
  servers           game servers announce themselves here every few seconds;
                    clients ask for the ones on their own public IP
  sp_keys           short-lived keys a logged-in player gets to run their own
                    singleplayer server (it may only touch that account)

Accounts level up too: every point of XP a character earns also goes to its
account, and when a character dies the account gets 25% of all the XP that
character ever earned plus a value for everything it carried. Account levels
hand out rewards (see REWARDS): more character slots, better starting gear.

Clients talk to it with a session token (Authorization: Bearer ...). Game
servers talk to it with a server key (X-Server-Key) and are the only ones that
may load, save or kill a character. A character is "leased" to one game
server at a time so it can never be played in two places at once.

Only the standard library is used, so it runs on a stock Raspberry Pi.

    python3 void_accounts.py serve [--config config.json]
    python3 void_accounts.py create-user NAME PASSWORD
    python3 void_accounts.py new-server-key "Server name"
    python3 void_accounts.py list
"""

import argparse
import hashlib
import hmac
import ipaddress
import json
import os
import secrets
import sqlite3
import sys
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse, parse_qs

HERE = os.path.dirname(os.path.abspath(__file__))
DEFAULT_CONFIG = {
    "listen": "127.0.0.1",
    "port": 8095,
    "database": "void_realms.db",
    # key -> label. Game servers send one of these as X-Server-Key.
    "server_keys": {},
    "allow_register": False,
    "max_characters": 8,
    "session_days": 30,
    # A server that hasn't sent a heartbeat for this long is not listed.
    "server_timeout": 30,
    # A character stays bound to the server that loaded it this long after
    # that server's last save/heartbeat (a crashed server frees it again).
    "lease_seconds": 90,
    # Also list servers on other public IPs that asked to be public.
    "list_public_servers": True,
    # Header the reverse proxy puts the real client IP in (Cloudflare).
    "real_ip_headers": ["CF-Connecting-IP", "X-Forwarded-For", "X-Real-IP"],
    # Character slots every account starts with (rewards add more).
    "base_slots": 2,
    "singleplayer_hours": 12,
}
CLASSES = ("archer", "wizard", "priest", "alchemist", "merrow")
MAX_ACCOUNT_LEVEL = 100
# What each account level hands out. Types: slot (+1 character slot),
# start_tier (new characters start with this grade in a gear slot),
# start_item (new characters start with these). Levels not listed have no
# reward yet.
REWARDS = {
    2: {"type": "start_item", "id": "elixir_hp", "count": 2, "text": "New characters start with 2 more health elixirs"},
    3: {"type": "start_tier", "slot": "weapon", "tier": 2, "text": "Starting weapon: Grade 2"},
    5: {"type": "slot", "text": "+1 character slot"},
    7: {"type": "start_tier", "slot": "armor", "tier": 2, "text": "Starting armor: Grade 2"},
    10: {"type": "start_tier", "slot": "spell", "tier": 2, "text": "Starting spell: Grade 2"},
    12: {"type": "slot", "text": "+1 character slot"},
    15: {"type": "start_tier", "slot": "weapon", "tier": 3, "text": "Starting weapon: Grade 3"},
    18: {"type": "start_tier", "slot": "bonus", "tier": 1, "text": "Start with a Grade 1 talisman"},
    20: {"type": "slot", "text": "+1 character slot"},
    25: {"type": "start_tier", "slot": "armor", "tier": 3, "text": "Starting armor: Grade 3"},
    30: {"type": "start_tier", "slot": "weapon", "tier": 4, "text": "Starting weapon: Grade 4"},
    35: {"type": "slot", "text": "+1 character slot"},
    40: {"type": "start_tier", "slot": "spell", "tier": 3, "text": "Starting spell: Grade 3"},
    45: {"type": "start_tier", "slot": "bonus", "tier": 2, "text": "Start with a Grade 2 talisman"},
    50: {"type": "slot", "text": "+1 character slot"},
}


def xp_to_next(level):
    """Account XP needed to go from `level` to the next (the game uses the same formula)."""
    return 600 + 400 * (level - 1)


def account_progress(xp, base_slots):
    level = 1
    left = int(xp)
    while level < MAX_ACCOUNT_LEVEL and left >= xp_to_next(level):
        left -= xp_to_next(level)
        level += 1
    slots = base_slots + sum(1 for l, r in REWARDS.items() if r["type"] == "slot" and l <= level)
    return {"xp": int(xp), "level": level, "into": left, "needed": xp_to_next(level), "slots": slots}


def character_total_xp(level, xp):
    """All XP a character earned (its own curve: 40 + 20 * level per level)."""
    return sum(40 + 20 * l for l in range(1, int(level))) + int(xp)


def item_value(item_id, count):
    """Account XP an item is worth when its carrier dies with it."""
    if item_id.startswith("D_"):
        return 1500 * count
    if len(item_id) > 2 and item_id[0] == "G" and item_id[1].isdigit():
        tier = int(item_id[1])
        return 5 * tier * tier * count
    if item_id.startswith("elixir_of_"):
        return 60 * count
    if item_id == "backpack":
        return 100 * count
    return 3 * count


def carried(data):
    """Every item a character's data carries: [(id, count)]."""
    out = []
    for item in list((data.get("gear") or {}).values()) + list(data.get("backpack") or []) + list(data.get("quick") or []):
        if item and item.get("id"):
            out.append((str(item["id"]), int(item.get("count", 1))))
    return out
PBKDF2_ROUNDS = 200_000
MAX_CAMPAIGN_BYTES = 2 * 1024 * 1024
SCHEMA = """
CREATE TABLE IF NOT EXISTS accounts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT NOT NULL UNIQUE COLLATE NOCASE,
    pass_hash TEXT NOT NULL,
    salt TEXT NOT NULL,
    created REAL NOT NULL,
    last_login REAL
);
CREATE TABLE IF NOT EXISTS sessions (
    token TEXT PRIMARY KEY,
    account_id INTEGER NOT NULL REFERENCES accounts(id),
    created REAL NOT NULL,
    expires REAL NOT NULL
);
CREATE TABLE IF NOT EXISTS campaigns (
    account_id INTEGER PRIMARY KEY REFERENCES accounts(id),
    data TEXT NOT NULL DEFAULT '{}',
    updated REAL NOT NULL
);
CREATE TABLE IF NOT EXISTS friends (
    account_id INTEGER NOT NULL,
    friend_id INTEGER NOT NULL,
    created REAL NOT NULL,
    PRIMARY KEY (account_id, friend_id)
);
CREATE TABLE IF NOT EXISTS characters (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    account_id INTEGER NOT NULL REFERENCES accounts(id),
    class TEXT NOT NULL DEFAULT 'archer',
    level INTEGER NOT NULL DEFAULT 1,
    xp INTEGER NOT NULL DEFAULT 0,
    data TEXT NOT NULL DEFAULT '{}',
    created REAL NOT NULL,
    updated REAL NOT NULL,
    lease_server TEXT,
    lease_until REAL NOT NULL DEFAULT 0,
    last_server TEXT
);
CREATE TABLE IF NOT EXISTS dead_characters (
    id INTEGER PRIMARY KEY,
    account_id INTEGER NOT NULL REFERENCES accounts(id),
    class TEXT NOT NULL,
    level INTEGER NOT NULL,
    xp INTEGER NOT NULL,
    data TEXT NOT NULL,
    created REAL NOT NULL,
    died REAL NOT NULL,
    killed_by TEXT,
    realm TEXT,
    server TEXT
);
CREATE TABLE IF NOT EXISTS character_items (
    character_id INTEGER NOT NULL,
    place TEXT NOT NULL,
    slot TEXT NOT NULL,
    item_id TEXT NOT NULL,
    count INTEGER NOT NULL DEFAULT 1,
    PRIMARY KEY (character_id, place, slot)
);
CREATE TABLE IF NOT EXISTS servers (
    key_label TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    public_ip TEXT NOT NULL,
    port INTEGER NOT NULL,
    lan TEXT NOT NULL DEFAULT '[]',
    players INTEGER NOT NULL DEFAULT 0,
    max_players INTEGER NOT NULL DEFAULT 0,
    public INTEGER NOT NULL DEFAULT 0,
    version TEXT,
    motd TEXT,
    last_seen REAL NOT NULL
);
CREATE TABLE IF NOT EXISTS sp_keys (
    key TEXT PRIMARY KEY,
    account_id INTEGER NOT NULL REFERENCES accounts(id),
    expires REAL NOT NULL
);
CREATE INDEX IF NOT EXISTS characters_account ON characters(account_id);
CREATE INDEX IF NOT EXISTS dead_account ON dead_characters(account_id);
"""
# Characters start with an id far from 1 so they never look like slot numbers.
FIRST_CHARACTER_ID = 1000


class ApiError(Exception):
    def __init__(self, status, message):
        super().__init__(message)
        self.status = status
        self.message = message


class Store:
    """All database access. One connection per thread (sqlite3 rule)."""

    def __init__(self, path):
        self.path = path
        self.local = threading.local()
        db = self.db()
        db.executescript(SCHEMA)
        for table, column, decl in (("accounts", "xp", "INTEGER NOT NULL DEFAULT 0"),
                                    ("dead_characters", "account_xp", "INTEGER NOT NULL DEFAULT 0")):
            if column not in [r[1] for r in db.execute("PRAGMA table_info(%s)" % table)]:
                db.execute("ALTER TABLE %s ADD COLUMN %s %s" % (table, column, decl))
        if db.execute("SELECT seq FROM sqlite_sequence WHERE name='characters'").fetchone() is None:
            db.execute("INSERT INTO sqlite_sequence(name, seq) VALUES ('characters', ?)", (FIRST_CHARACTER_ID - 1,))
        db.commit()

    def db(self):
        conn = getattr(self.local, "conn", None)
        if conn is None:
            conn = sqlite3.connect(self.path, timeout=10, isolation_level=None)
            conn.row_factory = sqlite3.Row
            conn.execute("PRAGMA journal_mode=WAL")
            conn.execute("PRAGMA foreign_keys=ON")
            self.local.conn = conn
        return conn

    # --- accounts -------------------------------------------------------------------

    @staticmethod
    def hash_password(password, salt):
        return hashlib.pbkdf2_hmac("sha256", password.encode(), bytes.fromhex(salt), PBKDF2_ROUNDS).hex()

    def create_account(self, username, password):
        username = username.strip()
        if not (1 <= len(username) <= 24) or not username.replace("_", "").replace("-", "").isalnum():
            raise ApiError(400, "Usernames are 1-24 letters, digits, - or _.")
        if len(password) < 4:
            raise ApiError(400, "Passwords need at least 4 characters.")
        salt = secrets.token_hex(16)
        try:
            cur = self.db().execute(
                "INSERT INTO accounts(username, pass_hash, salt, created) VALUES (?,?,?,?)",
                (username, self.hash_password(password, salt), salt, time.time()))
        except sqlite3.IntegrityError:
            raise ApiError(409, "That username is taken.")
        return cur.lastrowid

    def set_password(self, username, password):
        salt = secrets.token_hex(16)
        n = self.db().execute("UPDATE accounts SET pass_hash=?, salt=? WHERE username=?",
                              (self.hash_password(password, salt), salt, username)).rowcount
        if n == 0:
            raise ApiError(404, "No such account.")

    def login(self, username, password, session_days):
        row = self.db().execute("SELECT * FROM accounts WHERE username=?", (username.strip(),)).fetchone()
        if row is None or not hmac.compare_digest(row["pass_hash"], self.hash_password(password, row["salt"])):
            time.sleep(0.4)  # slow down guessing
            raise ApiError(401, "Wrong username or password.")
        token = secrets.token_urlsafe(32)
        now = time.time()
        db = self.db()
        db.execute("INSERT INTO sessions(token, account_id, created, expires) VALUES (?,?,?,?)",
                   (token, row["id"], now, now + session_days * 86400))
        db.execute("UPDATE accounts SET last_login=? WHERE id=?", (now, row["id"]))
        db.execute("DELETE FROM sessions WHERE expires < ?", (now,))
        return token, row

    def account_for_token(self, token):
        if not token:
            raise ApiError(401, "Not logged in.")
        row = self.db().execute(
            "SELECT a.* FROM sessions s JOIN accounts a ON a.id = s.account_id WHERE s.token=? AND s.expires > ?",
            (token, time.time())).fetchone()
        if row is None:
            raise ApiError(401, "Your login has expired. Log in again.")
        return row

    def logout(self, token):
        self.db().execute("DELETE FROM sessions WHERE token=?", (token,))

    # --- campaigns ------------------------------------------------------------------

    def _campaign_account(self, account_id, only_account):
        if type(account_id) is not int:
            raise ApiError(400, "account_id must be an integer.")
        if only_account is not None and account_id != only_account:
            raise ApiError(403, "A singleplayer server only plays its own account.")
        if not (0 < account_id < 2 ** 63) or self.db().execute(
                "SELECT 1 FROM accounts WHERE id=?", (account_id,)).fetchone() is None:
            raise ApiError(404, "No such account.")

    def load_campaign(self, account_id, only_account=None):
        self._campaign_account(account_id, only_account)
        row = self.db().execute("SELECT data FROM campaigns WHERE account_id=?", (account_id,)).fetchone()
        return json.loads(row["data"]) if row else {}

    def save_campaign(self, account_id, book, only_account=None):
        self._campaign_account(account_id, only_account)
        if not isinstance(book, dict):
            raise ApiError(400, "book must be an object.")
        data = json.dumps(book, ensure_ascii=False, separators=(",", ":"))
        if len(data.encode("utf-8")) > MAX_CAMPAIGN_BYTES:
            raise ApiError(413, "Campaign book too large.")
        self.db().execute(
            "INSERT INTO campaigns(account_id, data, updated) VALUES (?,?,?)"
            " ON CONFLICT(account_id) DO UPDATE SET data=excluded.data, updated=excluded.updated",
            (account_id, data, time.time()))

    # --- friends --------------------------------------------------------------------

    def player_summary(self, account, now):
        row = self.db().execute(
            "SELECT c.class, c.level, c.lease_server, s.name FROM characters c"
            " LEFT JOIN servers s ON s.key_label=c.lease_server"
            " WHERE c.account_id=? AND c.lease_until > ? ORDER BY c.lease_until DESC, c.id LIMIT 1",
            (account["id"], now)).fetchone()
        server = ""
        if row is not None:
            label = row["lease_server"] or ""
            server = "Singleplayer" if label.startswith("Singleplayer (") else (row["name"] or label)
        return {"username": account["username"], "online": row is not None, "server": server,
                "class": row["class"] if row else "", "level": row["level"] if row else 0}

    def friend_summary(self, account_id, friend, now):
        out = self.player_summary(friend, now)
        out["mutual"] = self.db().execute(
            "SELECT 1 FROM friends WHERE account_id=? AND friend_id=?", (friend["id"], account_id)).fetchone() is not None
        return out

    def friends(self, account_id):
        rows = self.db().execute(
            "SELECT a.id, a.username FROM friends f JOIN accounts a ON a.id=f.friend_id WHERE f.account_id=?",
            (account_id,)).fetchall()
        now = time.time()
        out = [self.friend_summary(account_id, r, now) for r in rows]
        return sorted(out, key=lambda r: (not r["online"], r["username"].casefold()))

    def add_friend(self, account_id, username):
        db = self.db()
        db.execute("BEGIN IMMEDIATE")
        try:
            friend = db.execute("SELECT id, username FROM accounts WHERE username=?", (username.strip(),)).fetchone()
            if friend is None:
                raise ApiError(404, "No such account.")
            if friend["id"] == account_id:
                raise ApiError(400, "You can't add yourself.")
            if db.execute("SELECT 1 FROM friends WHERE account_id=? AND friend_id=?",
                          (account_id, friend["id"])).fetchone():
                raise ApiError(400, "That player is already a friend.")
            if db.execute("SELECT COUNT(*) FROM friends WHERE account_id=?", (account_id,)).fetchone()[0] >= 200:
                raise ApiError(400, "You can have at most 200 friends.")
            db.execute("INSERT INTO friends(account_id, friend_id, created) VALUES (?,?,?)",
                       (account_id, friend["id"], time.time()))
            db.execute("COMMIT")
        except Exception:
            db.execute("ROLLBACK")
            raise
        return self.friend_summary(account_id, friend, time.time())

    def remove_friend(self, account_id, username):
        self.db().execute("DELETE FROM friends WHERE account_id=? AND friend_id IN"
                          " (SELECT id FROM accounts WHERE username=?)", (account_id, username.strip()))

    def search_players(self, account_id, query):
        query = query.strip()
        if len(query) < 2:
            raise ApiError(400, "Search needs at least 2 characters.")
        # Escape LIKE wildcards so underscores in usernames stay literal.
        prefix = query.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_") + "%"
        rows = self.db().execute(
            "SELECT a.id, a.username, EXISTS(SELECT 1 FROM friends f WHERE f.account_id=? AND f.friend_id=a.id) AS friend"
            " FROM accounts a WHERE a.id != ? AND a.username LIKE ? ESCAPE '\\' ORDER BY a.username LIMIT 20",
            (account_id, account_id, prefix)).fetchall()
        now = time.time()
        out = []
        for row in rows:
            player = self.player_summary(row, now)
            out.append({"username": player["username"], "online": player["online"], "server": player["server"],
                        "friend": bool(row["friend"])})
        return out

    # --- characters -----------------------------------------------------------------

    @staticmethod
    def character_summary(row, dead=False):
        out = {"id": row["id"], "class": row["class"], "level": row["level"], "xp": row["xp"],
               "created": row["created"]}
        data = json.loads(row["data"] or "{}")
        gear = data.get("gear", {}) if isinstance(data, dict) else {}
        out["gear"] = {k: (v or {}).get("id") for k, v in gear.items()}
        if dead:
            out.update(died=row["died"], killed_by=row["killed_by"], realm=row["realm"], server=row["server"],
                       account_xp=row["account_xp"], data=data)
        else:
            out["online"] = bool(row["lease_server"]) and row["lease_until"] > time.time()
            out["last_server"] = row["last_server"]
        return out

    def characters(self, account_id):
        rows = self.db().execute("SELECT * FROM characters WHERE account_id=? ORDER BY id", (account_id,)).fetchall()
        return [self.character_summary(r) for r in rows]

    def graveyard(self, account_id, limit=50):
        rows = self.db().execute("SELECT * FROM dead_characters WHERE account_id=? ORDER BY died DESC LIMIT ?",
                                 (account_id, limit)).fetchall()
        return [self.character_summary(r, dead=True) for r in rows]

    def progress(self, account_id, base_slots):
        row = self.db().execute("SELECT xp FROM accounts WHERE id=?", (account_id,)).fetchone()
        return account_progress(row["xp"] if row else 0, base_slots)

    def add_account_xp(self, account_id, amount):
        if amount > 0:
            self.db().execute("UPDATE accounts SET xp = xp + ? WHERE id=?", (int(amount), account_id))

    def delete_character(self, account_id, character_id):
        db = self.db()
        row = db.execute("SELECT * FROM characters WHERE id=? AND account_id=?", (character_id, account_id)).fetchone()
        if row is None:
            raise ApiError(404, "No such character.")
        if row["lease_server"] and row["lease_until"] > time.time():
            raise ApiError(409, "That character is playing right now.")
        db.execute("DELETE FROM characters WHERE id=?", (character_id,))
        db.execute("DELETE FROM character_items WHERE character_id=?", (character_id,))

    def delete_dead(self, account_id, character_id):
        n = self.db().execute("DELETE FROM dead_characters WHERE id=? AND account_id=?", (character_id, account_id)).rowcount
        if n == 0:
            raise ApiError(404, "No such fallen character.")
        self.db().execute("DELETE FROM character_items WHERE character_id=?", (character_id,))

    def singleplayer_key(self, account_id, hours):
        key = "sp_" + secrets.token_urlsafe(24)
        now = time.time()
        self.db().execute("DELETE FROM sp_keys WHERE expires < ?", (now,))
        self.db().execute("INSERT INTO sp_keys(key, account_id, expires) VALUES (?,?,?)", (key, account_id, now + hours * 3600))
        return key

    def singleplayer_account(self, key):
        row = self.db().execute("SELECT s.account_id, a.username FROM sp_keys s JOIN accounts a ON a.id = s.account_id"
                                " WHERE s.key=? AND s.expires > ?", (key, time.time())).fetchone()
        return row

    def create_character(self, account_id, cls, max_characters):
        db = self.db()
        count = db.execute("SELECT COUNT(*) FROM characters WHERE account_id=?", (account_id,)).fetchone()[0]
        if count >= max_characters:
            raise ApiError(409, "All %d character slots are in use." % max_characters)
        now = time.time()
        cur = db.execute("INSERT INTO characters(account_id, class, data, created, updated) VALUES (?,?,?,?,?)",
                         (account_id, cls, "{}", now, now))
        return cur.lastrowid

    def _character(self, character_id):
        row = self.db().execute("SELECT * FROM characters WHERE id=?", (character_id,)).fetchone()
        if row is None:
            raise ApiError(404, "That character does not exist (or has died).")
        return row

    def claim(self, token, character_id, server, lease_seconds, base_slots, only_account=None):
        """A game server loads a character for a logged-in player."""
        account = self.account_for_token(token)
        if only_account is not None and account["id"] != only_account:
            raise ApiError(403, "A singleplayer server only plays its own account.")
        db = self.db()
        db.execute("BEGIN IMMEDIATE")
        try:
            row = self._character(character_id)
            if row["account_id"] != account["id"]:
                raise ApiError(403, "That character belongs to another account.")
            now = time.time()
            # One server per account at a time (and so per character).
            busy = db.execute(
                "SELECT id, lease_server FROM characters WHERE account_id=? AND lease_until > ? AND lease_server != ?",
                (account["id"], now, server)).fetchone()
            if busy is not None:
                raise ApiError(409, "This account is already playing on %s." % busy["lease_server"])
            db.execute("UPDATE characters SET lease_server=?, lease_until=?, last_server=? WHERE id=?",
                       (server, now + lease_seconds, server, character_id))
            db.execute("COMMIT")
        except Exception:
            db.execute("ROLLBACK")
            raise
        progress = self.progress(account["id"], base_slots)
        rewards = [dict(r, level=l) for l, r in sorted(REWARDS.items()) if l <= progress["level"]]
        return {"account": {"id": account["id"], "username": account["username"], "progress": progress,
                            "rewards": rewards},
                "character": {"id": row["id"], "class": row["class"], "data": json.loads(row["data"] or "{}")}}

    def _check_lease(self, row, server):
        if row["lease_server"] != server:
            raise ApiError(409, "Character %d is not loaded on this server." % row["id"])

    def save(self, character_id, server, data, lease_seconds, account_xp=0, only_account=None):
        db = self.db()
        db.execute("BEGIN IMMEDIATE")
        try:
            row = self._character(character_id)
            self._check_lease(row, server)
            if only_account is not None and row["account_id"] != only_account:
                raise ApiError(403, "Not this account's character.")
            self.add_account_xp(row["account_id"], account_xp)
            now = time.time()
            db.execute("UPDATE characters SET data=?, level=?, xp=?, updated=?, lease_until=? WHERE id=?",
                       (json.dumps(data), int(data.get("level", 1)), int(data.get("xp", 0)), now,
                        now + lease_seconds, character_id))
            self._write_items(character_id, data)
            db.execute("COMMIT")
        except Exception:
            db.execute("ROLLBACK")
            raise

    def release(self, character_id, server):
        self.db().execute("UPDATE characters SET lease_server=NULL, lease_until=0 WHERE id=? AND lease_server=?",
                          (character_id, server))

    def renew(self, server, character_ids, lease_seconds):
        if not character_ids:
            return
        marks = ",".join("?" * len(character_ids))
        self.db().execute("UPDATE characters SET lease_until=? WHERE lease_server=? AND id IN (%s)" % marks,
                          [time.time() + lease_seconds, server] + list(character_ids))

    def die(self, character_id, server, data, killed_by, realm, account_xp=0, only_account=None, base_slots=2):
        """Moves a character to the dead table, with what it carried. The
        account gets the XP it earned since the last save, 25% of everything
        the character ever earned, and the value of what it carried."""
        db = self.db()
        db.execute("BEGIN IMMEDIATE")
        try:
            row = self._character(character_id)
            self._check_lease(row, server)
            if only_account is not None and row["account_id"] != only_account:
                raise ApiError(403, "Not this account's character.")
            if data:
                self._write_items(character_id, data)
            final = json.dumps(data) if data else row["data"]
            level = int(data.get("level", row["level"])) if data else row["level"]
            xp = int(data.get("xp", row["xp"])) if data else row["xp"]
            final_data = json.loads(final or "{}")
            items_xp = sum(item_value(i, c) for i, c in carried(final_data))
            share_xp = character_total_xp(level, xp) // 4
            bonus = items_xp + share_xp
            self.add_account_xp(row["account_id"], int(account_xp) + bonus)
            db.execute(
                "INSERT INTO dead_characters(id, account_id, class, level, xp, data, created, died, killed_by, realm, server,"
                " account_xp) VALUES (?,?,?,?,?,?,?,?,?,?,?,?)",
                (row["id"], row["account_id"], row["class"], level, xp, final, row["created"], time.time(),
                 killed_by, realm, server, bonus))
            db.execute("DELETE FROM characters WHERE id=?", (character_id,))
            db.execute("COMMIT")
        except Exception:
            db.execute("ROLLBACK")
            raise
        return {"id": row["id"], "level": level, "items_xp": items_xp, "share_xp": share_xp, "account_xp": bonus,
                "progress": self.progress(row["account_id"], base_slots)}

    def _write_items(self, character_id, data):
        db = self.db()
        db.execute("DELETE FROM character_items WHERE character_id=?", (character_id,))
        rows = []
        for slot, item in (data.get("gear") or {}).items():
            if item:
                rows.append((character_id, "gear", str(slot), item["id"], int(item.get("count", 1))))
        for place in ("backpack", "quick"):
            for i, item in enumerate(data.get(place) or []):
                if item:
                    rows.append((character_id, place, str(i), item["id"], int(item.get("count", 1))))
        db.executemany("INSERT INTO character_items VALUES (?,?,?,?,?)", rows)

    # --- servers --------------------------------------------------------------------

    def heartbeat(self, key_label, ip, body):
        lan = [str(a) for a in body.get("lan", [])][:8]
        self.db().execute(
            "INSERT INTO servers(key_label, name, public_ip, port, lan, players, max_players, public, version, motd, last_seen)"
            " VALUES (?,?,?,?,?,?,?,?,?,?,?) ON CONFLICT(key_label) DO UPDATE SET name=excluded.name,"
            " public_ip=excluded.public_ip, port=excluded.port, lan=excluded.lan, players=excluded.players,"
            " max_players=excluded.max_players, public=excluded.public, version=excluded.version,"
            " motd=excluded.motd, last_seen=excluded.last_seen",
            (key_label, str(body.get("name", key_label))[:48], ip, int(body.get("port", 24565)), json.dumps(lan),
             int(body.get("players", 0)), int(body.get("max_players", 0)), 1 if body.get("public") else 0,
             str(body.get("version", ""))[:16], str(body.get("motd", ""))[:120], time.time()))

    def servers_for(self, ip, timeout, include_public):
        rows = self.db().execute("SELECT * FROM servers WHERE last_seen > ?", (time.time() - timeout,)).fetchall()
        out = []
        for r in rows:
            same = r["public_ip"] == ip
            if not same and not (include_public and r["public"]):
                continue
            out.append({"name": r["name"], "address": r["public_ip"], "port": r["port"],
                        "lan": json.loads(r["lan"]), "players": r["players"], "max_players": r["max_players"],
                        "version": r["version"], "motd": r["motd"], "same_network": same})
        return out


class Handler(BaseHTTPRequestHandler):
    server_version = "VoidAccounts/1.0"
    store: Store = None
    config: dict = None
    only_account = None

    # --- plumbing -------------------------------------------------------------------

    def log_message(self, fmt, *args):
        sys.stderr.write("%s %s\n" % (self.client_ip(), fmt % args))

    def client_ip(self):
        for header in self.config["real_ip_headers"]:
            value = self.headers.get(header)
            if value:
                candidate = value.split(",")[0].strip()
                try:
                    ipaddress.ip_address(candidate)
                    return candidate
                except ValueError:
                    pass
        return self.client_address[0]

    def body(self, max_length=512 * 1024):
        length = int(self.headers.get("Content-Length") or 0)
        if length > max_length:
            raise ApiError(413, "Request too large.")
        if length == 0:
            return {}
        try:
            data = json.loads(self.rfile.read(length))
        except ValueError:
            raise ApiError(400, "Body must be JSON.")
        if not isinstance(data, dict):
            raise ApiError(400, "Body must be a JSON object.")
        return data

    def token(self):
        auth = self.headers.get("Authorization", "")
        return auth[7:].strip() if auth.startswith("Bearer ") else ""

    def server_label(self):
        """Which game server is asking. Singleplayer keys also set
        self.only_account: that server may only touch its own account."""
        key = self.headers.get("X-Server-Key", "")
        self.only_account = None
        for known, label in self.config["server_keys"].items():
            if key and hmac.compare_digest(key, known):
                return label
        if key.startswith("sp_"):
            row = self.store.singleplayer_account(key)
            if row is not None:
                self.only_account = row["account_id"]
                return "Singleplayer (%s)" % row["username"]
        raise ApiError(403, "Unknown server key.")

    def account_payload(self, row):
        progress = self.store.progress(row["id"], self.config["base_slots"])
        return {"account": {"id": row["id"], "username": row["username"]}, "progress": progress,
                "characters": self.store.characters(row["id"]), "max_characters": progress["slots"],
                "classes": list(CLASSES),
                "rewards": [dict(r, level=l) for l, r in sorted(REWARDS.items())], "max_level": MAX_ACCOUNT_LEVEL}

    def reply(self, status, payload):
        raw = json.dumps(payload).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(raw)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(raw)

    def do_GET(self):
        self.route("GET")

    def do_POST(self):
        self.route("POST")

    def route(self, method):
        url = urlparse(self.path)
        path = url.path.rstrip("/")
        if path.startswith("/api"):
            path = path[4:]
        handler = ROUTES.get((method, path))
        try:
            if handler is None:
                raise ApiError(404, "No such endpoint.")
            # Leave room for the JSON envelope around a full campaign book.
            max_length = MAX_CAMPAIGN_BYTES + 64 * 1024 if path == "/server/campaigns/save" else 512 * 1024
            body = self.body(max_length) if method == "POST" else {k: v[-1] for k, v in parse_qs(url.query).items()}
            self.reply(200, handler(self, body) or {"ok": True})
        except ApiError as e:
            self.reply(e.status, {"error": e.message})
        except Exception as e:  # never leak a traceback to clients
            sys.stderr.write("error on %s %s: %r\n" % (method, path, e))
            self.reply(500, {"error": "Internal error."})

    # --- client endpoints -----------------------------------------------------------

    def api_status(self, _body):
        return {"ok": True, "service": "void-accounts", "version": 1, "your_ip": self.client_ip()}

    def api_register(self, body):
        if not self.config["allow_register"]:
            raise ApiError(403, "Registration is closed.")
        self.store.create_account(str(body.get("username", "")), str(body.get("password", "")))
        return self.api_login(body)

    def api_login(self, body):
        token, row = self.store.login(str(body.get("username", "")), str(body.get("password", "")),
                                      self.config["session_days"])
        return dict(self.account_payload(row), token=token)

    def api_logout(self, _body):
        self.store.logout(self.token())

    def api_me(self, _body):
        return self.account_payload(self.store.account_for_token(self.token()))

    def api_campaigns(self, _body):
        row = self.store.account_for_token(self.token())
        return {"book": self.store.load_campaign(row["id"])}

    def api_friends(self, _body):
        row = self.store.account_for_token(self.token())
        return {"friends": self.store.friends(row["id"])}

    def api_add_friend(self, body):
        row = self.store.account_for_token(self.token())
        return {"ok": True, "friend": self.store.add_friend(row["id"], str(body.get("username", "")))}

    def api_remove_friend(self, body):
        row = self.store.account_for_token(self.token())
        self.store.remove_friend(row["id"], str(body.get("username", "")))
        return {"ok": True}

    def api_search_players(self, body):
        row = self.store.account_for_token(self.token())
        return {"players": self.store.search_players(row["id"], str(body.get("q", "")))}

    def api_create_character(self, body):
        row = self.store.account_for_token(self.token())
        cls = str(body.get("class", "archer"))
        if cls not in CLASSES:
            raise ApiError(400, "Unknown class.")
        slots = self.store.progress(row["id"], self.config["base_slots"])["slots"]
        cid = self.store.create_character(row["id"], cls, slots)
        return dict(self.account_payload(row), id=cid)

    def api_delete_character(self, body):
        row = self.store.account_for_token(self.token())
        self.store.delete_character(row["id"], int(body.get("id", 0)))
        return self.account_payload(row)

    def api_delete_dead(self, body):
        row = self.store.account_for_token(self.token())
        self.store.delete_dead(row["id"], int(body.get("id", 0)))
        return {"dead": self.store.graveyard(row["id"])}

    def api_singleplayer(self, _body):
        row = self.store.account_for_token(self.token())
        return {"key": self.store.singleplayer_key(row["id"], self.config["singleplayer_hours"])}

    def api_graveyard(self, _body):
        row = self.store.account_for_token(self.token())
        return {"dead": self.store.graveyard(row["id"])}

    def api_servers(self, _body):
        ip = self.client_ip()
        return {"your_ip": ip, "servers": self.store.servers_for(ip, self.config["server_timeout"],
                                                                 self.config["list_public_servers"])}

    # --- game server endpoints ------------------------------------------------------

    def api_heartbeat(self, body):
        label = self.server_label()
        if self.only_account is not None:
            return {"ok": True, "listed": False}  # singleplayer servers aren't listed
        self.store.heartbeat(label, self.client_ip(), body)
        self.store.renew(label, [int(c) for c in body.get("characters", [])], self.config["lease_seconds"])
        return {"ok": True, "public_ip": self.client_ip()}

    def api_claim(self, body):
        label = self.server_label()
        return self.store.claim(str(body.get("token", "")), int(body.get("character_id", 0)), label,
                                self.config["lease_seconds"], self.config["base_slots"], self.only_account)

    def api_save(self, body):
        label = self.server_label()
        data = body.get("data")
        if not isinstance(data, dict):
            raise ApiError(400, "data must be an object.")
        self.store.save(int(body.get("character_id", 0)), label, data, self.config["lease_seconds"],
                        max(0, int(body.get("account_xp", 0))), self.only_account)

    def api_load_campaign(self, body):
        self.server_label()
        return {"book": self.store.load_campaign(body.get("account_id"), self.only_account)}

    def api_save_campaign(self, body):
        self.server_label()
        self.store.save_campaign(body.get("account_id"), body.get("book"), self.only_account)
        return {"ok": True}

    def api_release(self, body):
        self.store.release(int(body.get("character_id", 0)), self.server_label())

    def api_die(self, body):
        label = self.server_label()
        data = body.get("data") if isinstance(body.get("data"), dict) else None
        return self.store.die(int(body.get("character_id", 0)), label, data,
                              str(body.get("killed_by", ""))[:64], str(body.get("realm", ""))[:32],
                              max(0, int(body.get("account_xp", 0))), self.only_account, self.config["base_slots"])


ROUTES = {
    ("GET", "/status"): Handler.api_status,
    ("GET", ""): Handler.api_status,
    ("POST", "/register"): Handler.api_register,
    ("POST", "/login"): Handler.api_login,
    ("POST", "/logout"): Handler.api_logout,
    ("GET", "/me"): Handler.api_me,
    ("GET", "/campaigns"): Handler.api_campaigns,
    ("GET", "/friends"): Handler.api_friends,
    ("POST", "/friends/add"): Handler.api_add_friend,
    ("POST", "/friends/remove"): Handler.api_remove_friend,
    ("GET", "/players/search"): Handler.api_search_players,
    ("POST", "/characters"): Handler.api_create_character,
    ("GET", "/graveyard"): Handler.api_graveyard,
    ("POST", "/characters/delete"): Handler.api_delete_character,
    ("POST", "/graveyard/delete"): Handler.api_delete_dead,
    ("POST", "/singleplayer"): Handler.api_singleplayer,
    ("GET", "/servers"): Handler.api_servers,
    ("POST", "/server/heartbeat"): Handler.api_heartbeat,
    ("POST", "/server/claim"): Handler.api_claim,
    ("POST", "/server/save"): Handler.api_save,
    ("POST", "/server/campaigns/load"): Handler.api_load_campaign,
    ("POST", "/server/campaigns/save"): Handler.api_save_campaign,
    ("POST", "/server/release"): Handler.api_release,
    ("POST", "/server/die"): Handler.api_die,
}


def load_config(path):
    config = dict(DEFAULT_CONFIG)
    if os.path.exists(path):
        with open(path) as f:
            config.update(json.load(f))
    else:
        with open(path, "w") as f:
            json.dump(config, f, indent=2)
    if not os.path.isabs(config["database"]):
        config["database"] = os.path.join(os.path.dirname(os.path.abspath(path)), config["database"])
    return config


def save_config(path, config):
    on_disk = dict(config)
    on_disk["database"] = os.path.basename(config["database"])
    with open(path, "w") as f:
        json.dump(on_disk, f, indent=2)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--config", default=os.path.join(HERE, "config.json"))
    sub = parser.add_subparsers(dest="cmd", required=True)
    sub.add_parser("serve")
    p = sub.add_parser("create-user")
    p.add_argument("username")
    p.add_argument("password")
    p = sub.add_parser("set-password")
    p.add_argument("username")
    p.add_argument("password")
    p = sub.add_parser("new-server-key")
    p.add_argument("label")
    sub.add_parser("list")
    args = parser.parse_args()

    config = load_config(args.config)
    store = Store(config["database"])
    if args.cmd == "serve":
        Handler.store = store
        Handler.config = config
        httpd = ThreadingHTTPServer((config["listen"], int(config["port"])), Handler)
        httpd.daemon_threads = True
        print("void-accounts listening on %s:%s (db %s)" % (config["listen"], config["port"], config["database"]),
              flush=True)
        httpd.serve_forever()
    elif args.cmd == "create-user":
        print("created account", store.create_account(args.username, args.password))
    elif args.cmd == "set-password":
        store.set_password(args.username, args.password)
        print("password changed")
    elif args.cmd == "new-server-key":
        key = secrets.token_urlsafe(24)
        config["server_keys"][key] = args.label
        save_config(args.config, config)
        print(key)
    elif args.cmd == "list":
        db = store.db()
        for a in db.execute("SELECT id, username FROM accounts").fetchall():
            alive = db.execute("SELECT id, level FROM characters WHERE account_id=?", (a["id"],)).fetchall()
            dead = db.execute("SELECT COUNT(*) FROM dead_characters WHERE account_id=?", (a["id"],)).fetchone()[0]
            print("%4d %-16s L%-3d alive: %s  dead: %d" % (a["id"], a["username"], store.progress(a["id"], config["base_slots"])["level"],
                                                     ", ".join("#%d L%d" % (c["id"], c["level"]) for c in alive) or "-",
                                                     dead))
        for s in db.execute("SELECT * FROM servers"):
            print("server %-20s %s:%d %d/%d seen %ds ago" % (s["name"], s["public_ip"], s["port"], s["players"],
                                                            s["max_players"], time.time() - s["last_seen"]))


if __name__ == "__main__":
    main()
