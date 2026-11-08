#!/usr/bin/env python3
"""Void Realms account service ("player sync").

One small HTTP/JSON service that owns everything that follows a player from
server to server:

  accounts          who can log in (PBKDF2 password hashes)
  sessions          login tokens handed to the game client
  friends           accepted friendships (up to 200 each), with requests
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
import random
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
# Chambers (the account vault): every account starts with BASE_CHESTS chests
# of VAULT_SLOTS slots; these levels add one more each.
BASE_CHESTS = 4
VAULT_SLOTS = 8
MAX_CHESTS = 120
for _level in (4, 6, 9, 13, 17, 22, 27, 33, 38, 44, 48, 55, 60, 70, 80, 90, 100):
    REWARDS[_level] = {"type": "chest", "text": "+1 chest in your Chambers"}
# Dots a dismantled item gives at the forge, by grade (index = tier), Divine.
DISMANTLE_DOTS = (0, 10, 25, 45, 75, 120, 250, 450, 650)
DISMANTLE_DIVINE = 1200
# Most Dots one award (a campaign, a pack) may hand out.
MAX_DOTS_AWARD = 5000


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
    chests = BASE_CHESTS + sum(1 for l, r in REWARDS.items() if r["type"] == "chest" and l <= level)
    return {"xp": int(xp), "level": level, "into": left, "needed": xp_to_next(level), "slots": slots,
            "chests": chests}


def dismantle_value(item_id, count):
    """Dots an item gives when dismantled at the forge (0 = it can't be)."""
    count = max(1, int(count))
    if item_id.startswith("D_"):
        return DISMANTLE_DIVINE * count
    if len(item_id) > 2 and item_id[0] == "G" and item_id[1].isdigit():
        return DISMANTLE_DOTS[max(1, min(8, int(item_id[1])))] * count
    if item_id.startswith("elixir_of_"):
        return 40 * count
    if item_id == "backpack":
        return 20 * count
    return 0


# --- Shops -----------------------------------------------------------------------
# Every shopkeeper in every game world sells from here, so stock, prices and
# offers are the same on every server (and switching servers changes nothing).
# Stock and offers follow 2 hour windows, seeded by the window: no state but
# the sales of limited items (shop_sales). The game's Shops (scripts/game/
# shops.gd) names the shops and their keepers; keep the ids in step.
SHOP_WINDOW = 2 * 3600
# What a grade costs to buy: twice the forge's Dots up to Grade 5, then dearer.
SHOP_PRICE = (0, 20, 50, 90, 150, 240, 1000, 1800, 2600)
SHOP_DIVINE = 3000
SHOP_FIXED = {"elixir_hp": 15, "elixir_mp": 15, "backpack": 120}
SHOP_ELIXIR_OF = 160
STAT_ELIXIRS = ("attack", "defense", "speed", "dexterity", "magic", "hp", "mp")
SPELL_MAX = 5
DIVINE_IDS = (
    "D_bow_Darkmatter", "D_bow_Fallenwoods", "D_bow_dragon", "D_cloak_burningman", "D_cloak_silvershield", "D_cloak_theblue",
    "D_cloak_thevoid", "D_spell_oftheblue", "D_spell_ofthedivine", "D_robe_oftheblue", "D_trident_oftheblue",
    "D_bonus_crucifix_oftheblue", "D_bow_offrost", "D_wand_offrost", "D_trident_offrost", "D_spell_offrost", "D_cloak_offrost",
    "D_robe_offrost", "D_bonus_crucifix_offrost", "D_bonus_flame_offrost", "D_bonus_eye_offrost", "D_bonus_crystal_offrost",
    "D_bonus_talisman_offrost", "D_trident_ofsatan", "D_wand_thewandofsatan", "D_bonus_crucifix_ofsatan", "D_trident_ofthedivine",
    "D_wand_thewandofthedivine", "D_bonus_flame_ofthedivine", "D_robe_ofthegalaxy", "D_trident_ofthevoid", "D_wand_thewandofdarkness",
    "D_trident_ofthefallenwood", "D_wand_thewandofthefallenwood", "D_wand_thewandofsteel", "D_bonus_crucifix_ofthalao",
    "D_robe_ofthedragonsbreath", "D_bonus_flame_ofthebroken", "D_bow_ofstorm", "D_wand_ofstorm", "D_trident_ofstorm",
    "D_spell_ofstorm", "D_cloak_ofstorm", "D_robe_ofstorm", "D_bonus_crucifix_ofstorm", "D_bonus_flame_ofstorm", "D_bonus_eye_ofstorm",
    "D_bonus_crystal_ofstorm", "D_bonus_talisman_ofstorm", "D_bow_ofiron", "D_wand_ofiron", "D_trident_ofiron", "D_cloak_ofiron",
    "D_robe_ofiron", "D_spell_ofiron", "D_bonus_crucifix_ofiron")
ALL_FAMILIES = ("bow", "cloak", "spell", "wand", "trident", "robe", "bonus_crucifix", "bonus_flame", "bonus_eye",
                "bonus_crystal", "bonus_talisman")
# families, grades always in stock, rare high-grade pieces per window (limited, one each), extras.
SHOPS = {
    "wizard": {"families": ("wand", "spell", "robe", "bonus_crystal"), "grades": (2, 5), "rare": 2},
    "priest": {"families": ("bonus_crucifix", "robe", "spell"), "grades": (2, 5), "rare": 2, "extra": ("elixir_hp", "elixir_mp")},
    "bowyer": {"families": ("bow", "cloak", "bonus_eye"), "grades": (2, 5), "rare": 3},
    "tidecaller": {"families": ("trident", "cloak", "bonus_talisman"), "grades": (2, 5), "rare": 2},
    "alchemist": {"families": ("bonus_flame",), "grades": (2, 5), "rare": 2, "extra": ("elixir_hp", "elixir_mp"), "elixirs": 2},
    "general": {"families": ALL_FAMILIES, "grades": (2, 4), "rare": 0, "extra": ("elixir_hp", "elixir_mp", "backpack")},
    "premium": {"families": ALL_FAMILIES, "grades": (4, 5), "rare": 3},
    "curio": {"families": ("bonus_crucifix", "bonus_flame", "bonus_eye", "bonus_crystal", "bonus_talisman"), "grades": (2, 5), "rare": 2,
              "elixirs": 1},
    "relic": {"families": (), "grades": (0, 0), "rare": 0, "divine": 3},
}
# Readable names of what an offer covers (the game shows them in speech bubbles).
FAMILY_NAMES = {"bow": "bows", "cloak": "cloaks", "spell": "spells", "wand": "wands", "trident": "tridents", "robe": "robes",
                "bonus_crucifix": "crucifixes", "bonus_flame": "flames", "bonus_eye": "eyes", "bonus_crystal": "crystals",
                "bonus_talisman": "talismans", "elixir": "elixirs", "divine": "relics"}


def shop_family(item_id):
    """The family an item id belongs to ("wand", "bonus_eye", "elixir", "divine")."""
    if item_id.startswith("D_"):
        return "divine"
    if item_id.startswith("elixir"):
        return "elixir"
    if len(item_id) > 3 and item_id[0] == "G" and item_id[1].isdigit():
        return item_id[3:]
    return item_id


def shop_base_price(item_id):
    if item_id.startswith("D_"):
        return SHOP_DIVINE
    if item_id in SHOP_FIXED:
        return SHOP_FIXED[item_id]
    if item_id.startswith("elixir_of_"):
        return SHOP_ELIXIR_OF
    if len(item_id) > 2 and item_id[0] == "G" and item_id[1].isdigit():
        return SHOP_PRICE[max(1, min(8, int(item_id[1])))]
    return 0


def shop_offers(window):
    """This window's offers: per shop maybe one, and sometimes one everywhere.
    [{shop ("*" = every shop), family or item, percent, ends}]."""
    rng = random.Random("offers:%d" % window)
    ends = (window + 1) * SHOP_WINDOW
    out = []
    for shop in sorted(SHOPS):
        if rng.random() < 0.4:
            spec = SHOPS[shop]
            pool = list(spec["families"]) + (["elixir"] if spec.get("extra") or spec.get("elixirs") else []) \
                + (["divine"] if spec.get("divine") else [])
            if pool:
                out.append({"shop": shop, "family": rng.choice(pool), "percent": rng.choice((10, 15, 15, 20, 25)), "ends": ends})
    if rng.random() < 0.3:
        out.append({"shop": "*", "family": rng.choice(ALL_FAMILIES), "percent": rng.choice((10, 15)), "ends": ends})
    return out


def shop_discount(shop, item_id, offers):
    family = shop_family(item_id)
    best = 0
    for offer in offers:
        if offer["shop"] in (shop, "*") and offer["family"] == family:
            best = max(best, int(offer["percent"]))
    return best


def shop_stock(shop, window):
    """[(item id, limited)] a shop sells this window (limited ones: one each, server wide)."""
    spec = SHOPS[shop]
    rng = random.Random("stock:%s:%d" % (shop, window))
    out = []
    lo, hi = spec["grades"]
    for family in spec["families"]:
        for tier in range(lo, hi + 1):
            if family == "spell" and tier > SPELL_MAX:
                continue
            out.append(("G%d_%s" % (tier, family), False))
    for item in spec.get("extra", ()):
        out.append((item, False))
    for stat in rng.sample(STAT_ELIXIRS, spec.get("elixirs", 0)):
        out.append(("elixir_of_" + stat, True))
    for _ in range(spec["rare"]):
        family = rng.choice(spec["families"])
        tier = rng.choice((6, 6, 6, 7, 7, 8))
        if family == "spell":
            tier = min(tier, SPELL_MAX)
        item = "G%d_%s" % (tier, family)
        if (item, False) not in out and (item, True) not in out:
            out.append((item, True))
    # The relic keeper: two or three divine pieces, and some windows nothing at all.
    if spec.get("divine"):
        count = rng.choice((0, 2, 2, 3, 3))
        for item in rng.sample(DIVINE_IDS, count):
            out.append((item, True))
    return out


def valid_item(item):
    return item is None or (isinstance(item, dict) and isinstance(item.get("id"), str) and 0 < len(item["id"]) <= 64
                            and isinstance(item.get("count", 1), int) and 0 < item.get("count", 1) <= 999)


def character_total_xp(level, xp):
    """Character curve; keep in sync with PlayerStats.xp_for_level."""
    return sum(40 + 20 * l + 3 * max(0, l - 8) ** 3
               for l in range(1, int(level))) + int(xp)


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
CREATE TABLE IF NOT EXISTS friend_requests (
    sender INTEGER NOT NULL REFERENCES accounts(id),
    recipient INTEGER NOT NULL REFERENCES accounts(id),
    created REAL NOT NULL,
    PRIMARY KEY (sender, recipient)
);
CREATE TABLE IF NOT EXISTS party_invites (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    sender INTEGER NOT NULL REFERENCES accounts(id),
    recipient INTEGER NOT NULL REFERENCES accounts(id),
    character_id INTEGER NOT NULL,
    server TEXT NOT NULL,
    expires REAL NOT NULL,
    accepted INTEGER NOT NULL DEFAULT 0,
    UNIQUE (sender, recipient)
);
CREATE INDEX IF NOT EXISTS friend_requests_recipient ON friend_requests(recipient);
CREATE INDEX IF NOT EXISTS party_invites_recipient ON party_invites(recipient);
CREATE INDEX IF NOT EXISTS party_invites_expires ON party_invites(expires);
CREATE TABLE IF NOT EXISTS social_limits (
    account_id INTEGER NOT NULL,
    action TEXT NOT NULL,
    started REAL NOT NULL,
    count INTEGER NOT NULL,
    PRIMARY KEY (account_id, action)
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
CREATE TABLE IF NOT EXISTS vaults (
    account_id INTEGER PRIMARY KEY REFERENCES accounts(id),
    items TEXT NOT NULL DEFAULT '[]',
    bonus_chests INTEGER NOT NULL DEFAULT 0,
    updated REAL NOT NULL
);
CREATE TABLE IF NOT EXISTS shop_sales (
    win INTEGER NOT NULL,
    shop TEXT NOT NULL,
    item_id TEXT NOT NULL,
    sold INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY (win, shop, item_id)
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
                                    ("accounts", "dots", "INTEGER NOT NULL DEFAULT 0"),
                                    ("accounts", "developer", "INTEGER NOT NULL DEFAULT 0"),
                                    ("accounts", "home", "TEXT DEFAULT NULL"),
                                    ("dead_characters", "account_xp", "INTEGER NOT NULL DEFAULT 0")):
            if column not in [r[1] for r in db.execute("PRAGMA table_info(%s)" % table)]:
                db.execute("ALTER TABLE %s ADD COLUMN %s %s" % (table, column, decl))
        if db.execute("SELECT seq FROM sqlite_sequence WHERE name='characters'").fetchone() is None:
            db.execute("INSERT INTO sqlite_sequence(name, seq) VALUES ('characters', ?)", (FIRST_CHARACTER_ID - 1,))
        # Existing follows become accepted, reciprocal friendships.
        db.execute("INSERT OR IGNORE INTO friends(account_id, friend_id, created)"
                   " SELECT friend_id, account_id, created FROM friends")
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

    def social_limit(self, account_id, action="write", limit=20):
        now = time.time()
        row = self.db().execute(
            "INSERT INTO social_limits VALUES (?,?,?,1) ON CONFLICT(account_id, action) DO UPDATE SET"
            " started=CASE WHEN started < ? THEN excluded.started ELSE started END,"
            " count=CASE WHEN started < ? THEN 1 ELSE count+1 END RETURNING count",
            (account_id, action, now, now - 60, now - 60)).fetchone()
        if row[0] > limit:
            raise ApiError(429, "Too many social requests. Try again shortly.")

    def social_account(self, username):
        if not 1 <= len(username.strip()) <= 24:
            raise ApiError(400, "Enter a player name (1-24 characters).")
        row = self.db().execute("SELECT id, username FROM accounts WHERE username=?", (username.strip(),)).fetchone()
        if row is None:
            raise ApiError(404, "No such account.")
        return row

    def active_character(self, account_id):
        return self.db().execute(
            "SELECT * FROM characters WHERE account_id=? AND lease_until>? AND lease_server IS NOT NULL"
            " ORDER BY lease_until DESC LIMIT 1", (account_id, time.time())).fetchone()

    def player_summary(self, account, now):
        row = self.active_character(account["id"])
        out = {"username": account["username"], "online": row is not None, "server": "",
               "class": row["class"] if row else "", "level": row["level"] if row else 0, "joinable": False}
        if row is not None:
            label = row["lease_server"]
            private = label.startswith(("Singleplayer (", "sp_"))
            server = self.db().execute("SELECT * FROM servers WHERE key_label=?", (label,)).fetchone()
            out["server"] = "Singleplayer" if private else (server["name"] if server else "Unavailable server")
            # Friends may follow you to any running dedicated server ("public" only
            # decides who sees it in the server list); Singleplayer stays private.
            if not private and server and server["last_seen"] > now - 30:
                out.update(joinable=True, address=server["public_ip"], port=server["port"])
        return out

    def friend_summary(self, account_id, friend, now):
        mine = self.active_character(account_id)
        theirs = self.active_character(friend["id"])
        same = bool(mine and theirs and mine["lease_server"] == theirs["lease_server"])
        return dict(self.player_summary(friend, now), mutual=True, same_server=same)

    def friends(self, account_id):
        rows = self.db().execute(
            "SELECT a.id, a.username FROM friends f JOIN accounts a ON a.id=f.friend_id WHERE f.account_id=?",
            (account_id,)).fetchall()
        out = [self.friend_summary(account_id, r, time.time()) for r in rows]
        return sorted(out, key=lambda r: (not r["online"], r["username"].casefold()))

    def social_state(self, account_id):
        self.social_limit(account_id, "poll", 60)
        requests = self.db().execute(
            "SELECT a.username, r.sender=? AS outgoing FROM friend_requests r JOIN accounts a"
            " ON a.id=CASE WHEN r.sender=? THEN r.recipient ELSE r.sender END"
            " WHERE r.sender=? OR r.recipient=? ORDER BY r.created LIMIT 400",
            (account_id, account_id, account_id, account_id)).fetchall()
        invites = self.db().execute(
            "SELECT i.id, a.username, i.accepted FROM party_invites i JOIN accounts a ON a.id=i.sender"
            " WHERE i.recipient=? AND i.expires>? ORDER BY i.id LIMIT 24", (account_id, time.time())).fetchall()
        return {"friends": self.friends(account_id), "requests": [dict(r) for r in requests],
                "party_invites": [dict(r) for r in invites]}

    def add_friend(self, account_id, username):
        self.social_limit(account_id)
        friend = self.social_account(username)
        if friend["id"] == account_id:
            raise ApiError(400, "You can't add yourself.")
        db = self.db()
        db.execute("BEGIN IMMEDIATE")
        try:
            if db.execute("SELECT 1 FROM friends WHERE account_id=? AND friend_id=?", (account_id, friend["id"])).fetchone():
                raise ApiError(400, "That player is already a friend.")
            for aid in (account_id, friend["id"]):
                if db.execute("SELECT COUNT(*) FROM friends WHERE account_id=?", (aid,)).fetchone()[0] >= 200:
                    raise ApiError(400, "Friend list is full (200).")
                if db.execute("SELECT COUNT(*) FROM friend_requests WHERE sender=? OR recipient=?", (aid, aid)).fetchone()[0] >= 200:
                    raise ApiError(400, "Too many pending friend requests (200).")
            db.execute("INSERT OR IGNORE INTO friend_requests VALUES (?,?,?)", (account_id, friend["id"], time.time()))
            db.execute("COMMIT")
        except Exception:
            db.execute("ROLLBACK")
            raise
        return dict(self.player_summary(friend, time.time()), pending=True)

    def respond_friend(self, account_id, username, accept):
        self.social_limit(account_id)
        other = self.social_account(username)["id"]
        db = self.db()
        db.execute("BEGIN IMMEDIATE")
        try:
            if not db.execute("SELECT 1 FROM friend_requests WHERE sender=? AND recipient=?", (other, account_id)).fetchone():
                raise ApiError(404, "No such friend request.")
            if accept:
                for aid in (account_id, other):
                    if db.execute("SELECT COUNT(*) FROM friends WHERE account_id=?", (aid,)).fetchone()[0] >= 200:
                        raise ApiError(400, "Friend list is full (200).")
                db.executemany("INSERT OR IGNORE INTO friends VALUES (?,?,?)",
                               [(account_id, other, time.time()), (other, account_id, time.time())])
            db.execute("DELETE FROM friend_requests WHERE (sender=? AND recipient=?) OR (sender=? AND recipient=?)",
                       (other, account_id, account_id, other))
            db.execute("COMMIT")
        except Exception:
            db.execute("ROLLBACK")
            raise

    def remove_friend(self, account_id, username):
        self.social_limit(account_id)
        other = self.social_account(username)["id"]
        db = self.db()
        db.execute("BEGIN IMMEDIATE")
        try:
            db.execute("DELETE FROM friends WHERE (account_id=? AND friend_id=?) OR (account_id=? AND friend_id=?)",
                       (account_id, other, other, account_id))
            db.execute("DELETE FROM friend_requests WHERE (sender=? AND recipient=?) OR (sender=? AND recipient=?)",
                       (account_id, other, other, account_id))
            db.execute("DELETE FROM party_invites WHERE (sender=? AND recipient=?) OR (sender=? AND recipient=?)",
                       (account_id, other, other, account_id))
            db.execute("COMMIT")
        except Exception:
            db.execute("ROLLBACK")
            raise

    def search_players(self, account_id, query):
        self.social_limit(account_id, "search", 30)
        query = query.strip()
        if not 1 <= len(query) <= 24:
            raise ApiError(400, "Search needs 1-24 characters.")
        prefix = query.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_") + "%"
        rows = self.db().execute(
            "SELECT a.id, a.username, EXISTS(SELECT 1 FROM friends f WHERE f.account_id=? AND f.friend_id=a.id) AS friend"
            " FROM accounts a WHERE a.id != ? AND a.username LIKE ? ESCAPE '\\' ORDER BY a.username LIMIT 20",
            (account_id, account_id, prefix)).fetchall()
        return [dict(self.player_summary(r, time.time()), friend=bool(r["friend"])) for r in rows]

    def join_friend(self, account_id, username):
        self.social_limit(account_id)
        other = self.social_account(username)
        if not self.db().execute("SELECT 1 FROM friends WHERE account_id=? AND friend_id=?", (account_id, other["id"])).fetchone():
            raise ApiError(403, "You can only join accepted friends.")
        out = self.friend_summary(account_id, other, time.time())
        if not out["joinable"] and not out["same_server"]:
            raise ApiError(409, "That player isn't on a joinable public server.")
        return out

    def invite_party(self, account_id, username, server=None):
        self.social_limit(account_id)
        other = self.social_account(username)
        db = self.db()
        db.execute("BEGIN IMMEDIATE")
        try:
            if not db.execute("SELECT 1 FROM friends WHERE account_id=? AND friend_id=?", (account_id, other["id"])).fetchone():
                raise ApiError(403, "Cross-server invites need an accepted friendship.")
            sender = db.execute("SELECT id, username FROM accounts WHERE id=?", (account_id,)).fetchone()
            char = self.active_character(account_id)
            summary = self.player_summary(sender, time.time())
            if not char or (server is not None and char["lease_server"] != server) or not summary["joinable"]:
                raise ApiError(409, "Join a public server to invite a friend. Singleplayer is private.")
            db.execute("DELETE FROM party_invites WHERE expires<?", (time.time(),))
            if db.execute("SELECT COUNT(*) FROM party_invites WHERE sender=?", (account_id,)).fetchone()[0] >= 12 or db.execute(
                    "SELECT COUNT(*) FROM party_invites WHERE recipient=?", (other["id"],)).fetchone()[0] >= 24:
                raise ApiError(400, "Too many pending party invites.")
            db.execute("INSERT INTO party_invites(sender, recipient, character_id, server, expires) VALUES (?,?,?,?,?)"
                       " ON CONFLICT(sender, recipient) DO UPDATE SET character_id=excluded.character_id,"
                       " server=excluded.server, expires=excluded.expires, accepted=0",
                       (account_id, other["id"], char["id"], char["lease_server"], time.time() + 180))
            db.execute("COMMIT")
        except Exception:
            db.execute("ROLLBACK")
            raise

    def respond_party(self, account_id, invite_id, accept):
        self.social_limit(account_id)
        db = self.db()
        db.execute("BEGIN IMMEDIATE")
        try:
            row = db.execute("SELECT * FROM party_invites WHERE id=? AND recipient=? AND expires>?",
                             (invite_id, account_id, time.time())).fetchone()
            if row is None:
                raise ApiError(404, "That party invitation expired.")
            out = {}
            if not accept:
                db.execute("DELETE FROM party_invites WHERE id=?", (invite_id,))
            else:
                char = self.active_character(row["sender"])
                sender = db.execute("SELECT id, username FROM accounts WHERE id=?", (row["sender"],)).fetchone()
                out = self.player_summary(sender, time.time())
                if not char or char["id"] != row["character_id"] or char["lease_server"] != row["server"] or not out["joinable"]:
                    raise ApiError(409, "The inviter has left that server.")
                mine = self.active_character(account_id)
                out["same_server"] = bool(mine and mine["lease_server"] == row["server"])
                # Accepting one invitation replaces other accepted arrivals.
                db.execute("UPDATE party_invites SET accepted=0 WHERE recipient=?", (account_id,))
                db.execute("UPDATE party_invites SET accepted=1 WHERE id=?", (invite_id,))
            db.execute("COMMIT")
        except Exception:
            db.execute("ROLLBACK")
            raise
        return out

    def party_arrivals(self, server, done=None, account_id=None):
        if done is not None:
            self.db().execute("DELETE FROM party_invites WHERE id=? AND server=? AND accepted=1", (done, server))
            return []
        return [dict(r) for r in self.db().execute(
            "SELECT i.id, i.sender, i.recipient, i.character_id FROM party_invites i"
            " JOIN characters c ON c.account_id=i.recipient AND c.lease_server=i.server AND c.lease_until>?"
            " JOIN characters l ON l.id=i.character_id AND l.lease_server=i.server AND l.lease_until>?"
            " WHERE i.server=? AND i.accepted=1 AND i.expires>? AND i.recipient=? LIMIT 24",
            (time.time(), time.time(), server, time.time(), account_id))]

    # --- characters -----------------------------------------------------------------

    @staticmethod
    def character_summary(row, dead=False):
        out = {"id": row["id"], "class": row["class"], "level": row["level"], "xp": row["xp"],
               "created": row["created"]}
        data = json.loads(row["data"] or "{}")
        gear = data.get("gear", {}) if isinstance(data, dict) else {}
        out["gear"] = {k: (v or {}).get("id") for k, v in gear.items()}
        out["stats"] = {k: data[k] for k in ("base", "base_hp", "base_mp") if k in data} if isinstance(data, dict) else {}
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
            # Adopt the first played character's legacy town once, then share it.
            legacy = json.loads(row["data"] or "{}")
            db.execute("UPDATE accounts SET home=COALESCE(home, ?) WHERE id=?",
                       (str(legacy.get("home", "")), account["id"]))
            db.execute("UPDATE characters SET lease_server=?, lease_until=?, last_server=? WHERE id=?",
                       (server, now + lease_seconds, server, character_id))
            db.execute("COMMIT")
        except Exception:
            db.execute("ROLLBACK")
            raise
        progress = self.progress(account["id"], base_slots)
        rewards = [dict(r, level=l) for l, r in sorted(REWARDS.items()) if l <= progress["level"]]
        extra = self.account_extra(account["id"], base_slots)
        return {"account": dict(extra, id=account["id"], username=account["username"], progress=progress,
                                rewards=rewards),
                "character": {"id": row["id"], "class": row["class"], "data": json.loads(row["data"] or "{}")}}

    def _check_lease(self, row, server):
        if row["lease_server"] != server:
            raise ApiError(409, "Character %d is not loaded on this server." % row["id"])

    def set_home(self, character_id, server, village, only_account=None):
        if not isinstance(village, str) or len(village) >= 40:
            raise ApiError(400, "Invalid spawn town.")
        db = self.db()
        db.execute("BEGIN IMMEDIATE")
        try:
            row = self._character(character_id)
            self._check_lease(row, server)
            if only_account is not None and row["account_id"] != only_account:
                raise ApiError(403, "Not this account's character.")
            db.execute("UPDATE accounts SET home=? WHERE id=?", (village, row["account_id"]))
            db.execute("COMMIT")
        except Exception:
            db.execute("ROLLBACK")
            raise
        return {"home": village}

    def save(self, character_id, server, data, lease_seconds, account_xp=0, only_account=None, then=None):
        """Saves a character. `then(account_id)` runs in the same transaction
        (a vault or Dots change that must land together with this data)."""
        db = self.db()
        db.execute("BEGIN IMMEDIATE")
        try:
            row = self._character(character_id)
            self._check_lease(row, server)
            if only_account is not None and row["account_id"] != only_account:
                raise ApiError(403, "Not this account's character.")
            self.add_account_xp(row["account_id"], account_xp)
            now = time.time()
            if data is not None:
                db.execute("UPDATE characters SET data=?, level=?, xp=?, updated=?, lease_until=? WHERE id=?",
                           (json.dumps(data), int(data.get("level", 1)), int(data.get("xp", 0)), now,
                            now + lease_seconds, character_id))
                self._write_items(character_id, data)
            result = then(row["account_id"]) if then else None
            db.execute("COMMIT")
        except Exception:
            db.execute("ROLLBACK")
            raise
        return result

    # --- Chambers (vault), Dots, developers ------------------------------------------

    def account_extra(self, account_id, base_slots):
        row = self.db().execute("SELECT dots, developer, home FROM accounts WHERE id=?", (account_id,)).fetchone()
        return {"dots": row["dots"] if row else 0, "developer": bool(row["developer"]) if row else False,
                "chests": self.chest_count(account_id, base_slots), "home": row["home"] if row else None}

    def chest_count(self, account_id, base_slots):
        row = self.db().execute("SELECT bonus_chests FROM vaults WHERE account_id=?", (account_id,)).fetchone()
        bonus = row["bonus_chests"] if row else 0
        return min(MAX_CHESTS, self.progress(account_id, base_slots)["chests"] + bonus)

    def vault(self, account_id, base_slots):
        row = self.db().execute("SELECT items FROM vaults WHERE account_id=?", (account_id,)).fetchone()
        items = json.loads(row["items"]) if row else []
        chests = self.chest_count(account_id, base_slots)
        # Never lose items: a vault holding more than its chests (fewer bonus
        # chests than before) keeps every item; the game shows enough chests.
        used = max([i + 1 for i, item in enumerate(items) if item] or [0])
        chests = max(chests, -(-used // VAULT_SLOTS))
        items = (items + [None] * (chests * VAULT_SLOTS))[:chests * VAULT_SLOTS]
        return {"chests": chests, "slots": VAULT_SLOTS, "items": items}

    def _write_vault(self, account_id, items):
        self.db().execute(
            "INSERT INTO vaults(account_id, items, updated) VALUES (?,?,?)"
            " ON CONFLICT(account_id) DO UPDATE SET items=excluded.items, updated=excluded.updated",
            (account_id, json.dumps(items, separators=(",", ":")), time.time()))

    def save_vault(self, character_id, server, data, items, lease_seconds, base_slots, only_account=None):
        """A character's data and the account vault, saved together (an item
        moved between them is never in both, nor lost)."""
        if not isinstance(items, list) or not all(valid_item(i) for i in items):
            raise ApiError(400, "items must be a list of {id, count} or null.")

        def write(account_id):
            if len(items) > self.vault(account_id, base_slots)["chests"] * VAULT_SLOTS:
                raise ApiError(409, "More items than the Chambers have room for.")
            self._write_vault(account_id, items)
        self.save(character_id, server, data, lease_seconds, 0, only_account, write)

    def add_dots(self, account_id, amount):
        self.db().execute("UPDATE accounts SET dots = MAX(0, dots + ?) WHERE id=?", (int(amount), account_id))
        return self.db().execute("SELECT dots FROM accounts WHERE id=?", (account_id,)).fetchone()["dots"]

    def dismantle(self, character_id, server, data, item_id, count, lease_seconds, only_account=None):
        """The character (saved without the item) gets its Dots, in one go."""
        gained = dismantle_value(str(item_id), count)
        if gained <= 0:
            raise ApiError(400, "That can't be dismantled.")
        dots = self.save(character_id, server, data, lease_seconds, 0, only_account,
                         lambda account_id: self.add_dots(account_id, gained))
        return {"dots": dots, "gained": gained}

    # --- Shops ------------------------------------------------------------------------

    def shops_state(self, now=None):
        """Every shop's stock with today's prices, and the window's offers."""
        now = time.time() if now is None else now
        window = int(now // SHOP_WINDOW)
        offers = shop_offers(window)
        sold = {(r["shop"], r["item_id"]): r["sold"] for r in self.db().execute(
            "SELECT shop, item_id, sold FROM shop_sales WHERE win=?", (window,))}
        shops = {}
        for shop in SHOPS:
            stock = []
            for item_id, limited in shop_stock(shop, window):
                base = shop_base_price(item_id)
                off = shop_discount(shop, item_id, offers)
                stock.append({"id": item_id, "base": base, "price": int(round(base * (100 - off) / 100.0)), "off": off,
                              "left": (max(0, 1 - int(sold.get((shop, item_id), 0))) if limited else -1)})
            shops[shop] = {"stock": stock}
        return {"now": now, "window": window, "ends": (window + 1) * SHOP_WINDOW, "offers": offers, "shops": shops,
                "families": FAMILY_NAMES}

    def buy(self, character_id, server, data, shop, item_id, expected, lease_seconds, only_account=None):
        """The character (saved with the item) pays its price, in one go."""
        if shop not in SHOPS:
            raise ApiError(400, "No such shop.")
        state = self.shops_state()
        entry = next((e for e in state["shops"][shop]["stock"] if e["id"] == item_id), None)
        if entry is None:
            raise ApiError(409, "That isn't for sale here any more.")
        if entry["left"] == 0:
            raise ApiError(409, "Someone bought the last one.")
        price = int(entry["price"])
        if expected is not None and price > int(expected):
            raise ApiError(409, "The price changed: it is %d Dots now." % price)
        if not any(i == item_id for i, _c in carried(data)):
            raise ApiError(400, "The bought item must be in the saved character.")
        window = state["window"]

        def pay(account_id):
            db = self.db()
            have = db.execute("SELECT dots FROM accounts WHERE id=?", (account_id,)).fetchone()["dots"]
            if have < price:
                raise ApiError(402, "Not enough Dots (%d of %d)." % (have, price))
            if entry["left"] > 0:
                row = db.execute("SELECT sold FROM shop_sales WHERE win=? AND shop=? AND item_id=?",
                                 (window, shop, item_id)).fetchone()
                if row and row["sold"] >= 1:
                    raise ApiError(409, "Someone bought the last one.")
                db.execute("INSERT INTO shop_sales (win, shop, item_id, sold) VALUES (?,?,?,1) "
                           "ON CONFLICT(win, shop, item_id) DO UPDATE SET sold = sold + 1", (window, shop, item_id))
            return self.add_dots(account_id, -price)

        dots = self.save(character_id, server, data, lease_seconds, 0, only_account, pay)
        return {"dots": dots, "price": price, "item_id": item_id}

    def award_dots(self, character_id, server, amount, lease_seconds, only_account=None):
        amount = max(0, min(MAX_DOTS_AWARD, int(amount)))
        dots = self.save(character_id, server, None, lease_seconds, 0, only_account,
                         lambda account_id: self.add_dots(account_id, amount))
        return {"dots": dots, "gained": amount}

    def _account_id(self, username):
        row = self.db().execute("SELECT id FROM accounts WHERE username=?", (username,)).fetchone()
        if row is None:
            raise ApiError(404, "No such account.")
        return row["id"]

    def set_developer(self, username, on):
        self.db().execute("UPDATE accounts SET developer=? WHERE id=?", (1 if on else 0, self._account_id(username)))

    def grant_chests(self, username, count):
        account_id = self._account_id(username)
        self.db().execute(
            "INSERT INTO vaults(account_id, items, bonus_chests, updated) VALUES (?, '[]', ?, ?)"
            " ON CONFLICT(account_id) DO UPDATE SET bonus_chests = MAX(0, bonus_chests + excluded.bonus_chests)",
            (account_id, int(count), time.time()))

    def fill_vault(self, username, ids, base_slots):
        """Development: puts one of each id in the account's Chambers (after
        what's there), adding bonus chests as needed. Only while the account
        is offline, so no game server holds an older copy."""
        account_id = self._account_id(username)
        if self.db().execute("SELECT 1 FROM characters WHERE account_id=? AND lease_until > ?",
                             (account_id, time.time())).fetchone():
            raise ApiError(409, "That account is playing right now; fill its Chambers while it's offline.")
        vault = self.vault(account_id, base_slots)
        items = [i for i in vault["items"] if i]
        items += [{"id": str(i), "count": 1} for i in ids]
        need = -(-len(items) // VAULT_SLOTS)
        if need > vault["chests"]:
            self.grant_chests(username, need - vault["chests"])
        self._write_vault(account_id, items)
        return len(items), max(need, vault["chests"])

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
        extra = self.store.account_extra(row["id"], self.config["base_slots"])
        return {"account": dict(extra, id=row["id"], username=row["username"]), "progress": progress,
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
            if path.startswith(("/friends", "/party", "/server/party")):
                max_length = 4096
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
        return self.store.social_state(row["id"])

    def api_add_friend(self, body):
        row = self.store.account_for_token(self.token())
        return {"ok": True, "friend": self.store.add_friend(row["id"], str(body.get("username", "")))}

    def api_remove_friend(self, body):
        row = self.store.account_for_token(self.token())
        self.store.remove_friend(row["id"], str(body.get("username", "")))
        return {"ok": True}

    def api_respond_friend(self, body):
        row = self.store.account_for_token(self.token())
        if type(body.get("accept")) is not bool:
            raise ApiError(400, "accept must be a boolean.")
        self.store.respond_friend(row["id"], str(body.get("username", "")), body["accept"])
        return {"ok": True}

    def api_join_friend(self, body):
        row = self.store.account_for_token(self.token())
        return self.store.join_friend(row["id"], str(body.get("username", "")))

    def api_invite_party(self, body):
        row = self.store.account_for_token(self.token())
        self.store.invite_party(row["id"], str(body.get("username", "")))
        return {"ok": True}

    def api_respond_party(self, body):
        row = self.store.account_for_token(self.token())
        if type(body.get("accept")) is not bool or type(body.get("id")) is not int:
            raise ApiError(400, "id must be an integer and accept a boolean.")
        return self.store.respond_party(row["id"], body["id"], body["accept"])

    def api_server_invite_party(self, body):
        label = self.server_label()
        aid = body.get("account_id")
        self.store._campaign_account(aid, self.only_account)
        self.store.invite_party(aid, str(body.get("username", "")), label)
        return {"ok": True}

    def api_party_arrivals(self, body):
        label = self.server_label()
        if self.only_account is not None:
            raise ApiError(403, "Singleplayer is private.")
        done = body.get("done")
        if done is not None and type(done) is not int:
            raise ApiError(400, "done must be an integer.")
        aid = body.get("account_id")
        if done is None:
            self.store._campaign_account(aid, self.only_account)
        return {"arrivals": self.store.party_arrivals(label, done, aid)}

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

    def api_home(self, body):
        label = self.server_label()
        return self.store.set_home(int(body.get("character_id", 0)), label,
                                   body.get("home", ""), self.only_account)

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

    def api_load_vault(self, body):
        label = self.server_label()
        row = self.store._character(int(body.get("character_id", 0)))
        self.store._check_lease(row, label)
        if self.only_account is not None and row["account_id"] != self.only_account:
            raise ApiError(403, "Not this account's character.")
        return self.store.vault(row["account_id"], self.config["base_slots"])

    def api_save_vault(self, body):
        label = self.server_label()
        data = body.get("data")
        if not isinstance(data, dict):
            raise ApiError(400, "data must be an object.")
        self.store.save_vault(int(body.get("character_id", 0)), label, data, body.get("items"),
                              self.config["lease_seconds"], self.config["base_slots"], self.only_account)

    def api_dismantle(self, body):
        label = self.server_label()
        data = body.get("data")
        if not isinstance(data, dict):
            raise ApiError(400, "data must be an object.")
        return self.store.dismantle(int(body.get("character_id", 0)), label, data, str(body.get("item_id", "")),
                                    int(body.get("count", 1)), self.config["lease_seconds"], self.only_account)

    def api_shops(self, _body):
        self.server_label()
        return self.store.shops_state()

    def api_buy(self, body):
        label = self.server_label()
        data = body.get("data")
        if not isinstance(data, dict):
            raise ApiError(400, "data must be an object.")
        expected = body.get("price")
        return self.store.buy(int(body.get("character_id", 0)), label, data, str(body.get("shop", "")),
                              str(body.get("item_id", "")), None if expected is None else int(expected),
                              self.config["lease_seconds"], self.only_account)

    def api_award_dots(self, body):
        label = self.server_label()
        return self.store.award_dots(int(body.get("character_id", 0)), label, int(body.get("amount", 0)),
                                     self.config["lease_seconds"], self.only_account)

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
    ("POST", "/friends/respond"): Handler.api_respond_friend,
    ("POST", "/friends/join"): Handler.api_join_friend,
    ("POST", "/party/invite"): Handler.api_invite_party,
    ("POST", "/party/respond"): Handler.api_respond_party,
    ("POST", "/server/party/invite"): Handler.api_server_invite_party,
    ("POST", "/server/party/arrivals"): Handler.api_party_arrivals,
    ("POST", "/characters"): Handler.api_create_character,
    ("GET", "/graveyard"): Handler.api_graveyard,
    ("POST", "/characters/delete"): Handler.api_delete_character,
    ("POST", "/graveyard/delete"): Handler.api_delete_dead,
    ("POST", "/singleplayer"): Handler.api_singleplayer,
    ("GET", "/servers"): Handler.api_servers,
    ("POST", "/server/heartbeat"): Handler.api_heartbeat,
    ("POST", "/server/claim"): Handler.api_claim,
    ("POST", "/server/save"): Handler.api_save,
    ("POST", "/server/home"): Handler.api_home,
    ("POST", "/server/campaigns/load"): Handler.api_load_campaign,
    ("POST", "/server/campaigns/save"): Handler.api_save_campaign,
    ("POST", "/server/release"): Handler.api_release,
    ("POST", "/server/vault/load"): Handler.api_load_vault,
    ("POST", "/server/vault/save"): Handler.api_save_vault,
    ("POST", "/server/dismantle"): Handler.api_dismantle,
    ("POST", "/server/shops"): Handler.api_shops,
    ("POST", "/server/shop/buy"): Handler.api_buy,
    ("POST", "/server/dots/award"): Handler.api_award_dots,
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
    p = sub.add_parser("set-developer", help="developer accounts may use /give, /lvl and /max on game servers")
    p.add_argument("username")
    p.add_argument("on", nargs="?", default="1", choices=("0", "1"))
    p = sub.add_parser("grant-chests", help="extra Chambers chests (negative takes them back)")
    p.add_argument("username")
    p.add_argument("count", type=int)
    p = sub.add_parser("fill-vault", help="put one of each item id (a file, one per line) in the Chambers")
    p.add_argument("username")
    p.add_argument("ids_file")
    p = sub.add_parser("give-dots")
    p.add_argument("username")
    p.add_argument("amount", type=int)
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
    elif args.cmd == "set-developer":
        store.set_developer(args.username, args.on == "1")
        print("%s is %sa developer" % (args.username, "" if args.on == "1" else "no longer "))
    elif args.cmd == "grant-chests":
        store.grant_chests(args.username, args.count)
        print("%s now has %d chests" % (args.username, store.chest_count(store._account_id(args.username),
                                                                           config["base_slots"])))
    elif args.cmd == "fill-vault":
        with open(args.ids_file) as f:
            ids = [line.strip() for line in f if line.strip() and not line.startswith("#")]
        count, chests = store.fill_vault(args.username, ids, config["base_slots"])
        print("%s's Chambers: %d items in %d chests" % (args.username, count, chests))
    elif args.cmd == "give-dots":
        print("%s has %d Dots" % (args.username, store.add_dots(store._account_id(args.username), args.amount)))
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
