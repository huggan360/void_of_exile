# Pets

Small voxel companions. A pet hatches from an egg, follows its owner, and every few seconds sends a thin bolt
of light to its owner (a heal, a buff) or to an enemy (damage). Pets belong to the account (every character of
the account shares them), live in the account's own **Pet Yard**, level up from 1 to 50 by eating Dots, and two
pets of the same kind and rarity merge into one of the next rarity.

This file is the contract between the pieces. Names here (files, functions, messages, fields) are fixed;
anything not named is up to whoever builds that piece.

## Species (15)

Ids are `PetDefs` keys and creature folders `creatures/pet_<id>/`. Height is in metres. `gait` is how it moves
(see Following).

| id | Name | Look | Height | gait |
| --- | --- | --- | ---: | --- |
| duck | Puddle Duck | a round yellow duckling-duck, orange bill and feet, a tuft on its head | 0.55 | waddle |
| puffbun | Puffbun | a cream bunny ball with long floppy ears, pink nose | 0.5 | hop |
| gloop | Gloop | a jelly-green slime with a happy face and a bubble inside | 0.45 | squash |
| ember_kit | Ember Kit | an orange fox kit, tail tip a small flame | 0.6 | trot |
| cinderling | Cinderling | a baby dragon, red-bronze scales, tiny wings, a puff of smoke | 0.7 | flap |
| hoot | Hoot | a round grey-blue owl with huge amber eyes | 0.5 | glide |
| lilyhop | Lilyhop | a fat green frog with a lily pad hat | 0.45 | leap |
| mossback | Mossback | a little tortoise, moss and a sprout on the shell | 0.45 | plod |
| wisp | Wisp | a small friendly ghost, a lantern glow in its chest | 0.6 | float |
| shardling | Shardling | a stubby crystal golem, violet shards on its back, glowing eyes | 0.75 | stomp |
| moonpaw | Moonpaw | a black kitten with a crescent moon on its forehead, blue eyes | 0.5 | trot |
| axie | Axie | a pink axolotl with frilly gills, walks on stubby legs | 0.4 | wiggle |
| capling | Capling | a mushroom sprite, red cap with white dots, tiny arms | 0.5 | hop |
| nebula_jelly | Nebula Jelly | a floating jellyfish of deep blue with stars inside, trailing tendrils | 0.8 | pulse |
| skywhale | Skywhale | a tiny floating whale, white belly, slow fin strokes | 0.7 | swim |

Some cute, some cool; every one readable from the overhead camera. Rare and Divine pets are the same model with
a look on top (Rarity).

## Rarity

`common`, `rare`, `divine`. Eggs always hatch a common pet. Two commons of the same species merge into a rare,
two rares into a divine. Rarity multiplies ability power: common 1.0, rare 1.5, divine 2.25. Look: rare pets get
a soft shimmer (a light tint and sparkle motes), divine pets a gold halo and gold motes.

## Abilities (6)

Each pet is born with two abilities, picked at random (they may be the same; a doubled ability fires twice).
The first works from level 1; the second unlocks at level 30. An ability's level is the pet's level.

| id | Name | Bolt colour | Target | Effect per pulse |
| --- | --- | --- | --- | --- |
| regen | Regeneration | white | owner | heals HP |
| mana | Magic Regeneration | blue `#4aa8ff` | owner | restores MP |
| attack | Attack | red `#ff3a3a` | nearest enemy in 12 m | damage (normal damage, enemy defence applies) |
| chain | Chain Lightning | violet `#b06bff` | up to 3 enemies in 12 m, hopping | 55% of attack damage each |
| ward | Ward | gold `#ffc94a` | owner | +defence buff for 6 s |
| swift | Swiftness | green `#5cff8a` | owner | +speed buff for 6 s |

Numbers (common, before the rarity multiplier), level L from 1 to 50, t = (L - 1) / 49:

- interval: 10 s at level 1 down to 5 s at level 50 (`lerp(10, 5, t)`)
- regen: `lerp(2, 30, t)` HP; mana: `lerp(3, 36, t)` MP
- attack: `lerp(15, 260, t)` damage; chain: 55% of that per target
- ward: `lerp(2, 12, t)` defence; swift: `lerp(2, 10, t)` speed (stat points, via the buff system)

Pulses only fire while the owner is alive, in a world with combat (not the Tavern, Chambers or Pet Yard), and
(for attack/chain) only at enemies that are awake and in range. Heal/mana pulses skip when the owner is full.

## Levels and feeding

Pets eat Dots at the Caretaker. One bite costs `PetDefs.BITE_DOTS` (10) Dots and gives 10 XP. XP to go from
level L to L+1: `PetDefs.xp_to_next(L) = round(20 + 6 * L + 0.9 * L * L)` (about 2,700 bites = 27k Dots from 1
to 50 for one pet, a long goal). The Caretaker panel can feed 1, 10 or "to next level".

## Merging

At the Caretaker: pick two pets of the same species and rarity (common or rare). They become one pet of the next
rarity with abilities `[a.abilities[0], b.abilities[0]]`, level `min(a.level, b.level)` and xp 0. Both old pets
are removed. An equipped pet can be merged (the result is equipped).

## Eggs

One egg item: `pet_egg` ("Pet Egg", a speckled egg). It hatches a random species (equal chance), common, with
two random abilities. Bought at the Pet Store in the Pet Yard for 350 Dots, and dropped rarely: 0.15% from any
enemy kill, 2% from bosses (a personal drop to the top damage dealer, like other loot). Hatching happens only in
the Pet Yard, at the Hatching Nest: walk up with an egg in your inventory and interact.

## Data

A pet (one Dictionary, saved as JSON):

```
{id = 17, species = "duck", rarity = "common", level = 1, xp = 0, abilities = ["regen", "attack"],
 name = "Puddle Duck", born = 1763200000}
```

An account's pets: `{next_id = 18, equipped = 17 (0 = none), pets = [pet, ...]}` (at most 60 pets).

## Code layout

| File | Owner (session) | What |
| --- | --- | --- |
| `scripts/pets/pet_defs.gd` (`class_name PetDefs`) | core | species, abilities, numbers above, `xp_to_next`, `ability_value(id, level, rarity)`, `interval(level)`, `random_pet(rng)`, `merge(a, b)` |
| `scripts/pets/pet_server.gd` (`class_name PetServer`) | core | owned by NetServer (`server.pets`): load/save per account, hatch, feed, merge, equip, ability pulses, egg drops |
| `scripts/pets/pet_follower.gd` (`class_name PetFollower`) | core | the pet that follows a player (local or remote) on clients, with its gait |
| `scripts/pets/pet_beam.gd` (`class_name PetBeam`) | core | the bolt of light (a short jagged lightning line that fades in ~0.35 s), coloured per ability |
| `scripts/pets/pets_client.gd` (`class_name PetsClient`) | core | client state: `PetsClient.state` (the account's pets as above), signal `changed`, requests `hatch()`, `feed(id, bites)`, `merge(a, b)`, `equip(id)` |
| `scripts/ui/pet_panel.gd` (`class_name PetPanel`) | core | the Caretaker's big panel |
| `scripts/world/pet_yard_world.gd` (`class_name PetYardWorld`) | yard | the Pet Yard world |
| `creatures/pet_<id>/`, `tools/make_pets.py` | art | the 15 pet models |
| `obstacles/pets/` or `props/pets/` | art | yard props: Hatching Nest, Pet Store stall, fences, food bowls, egg crate |
| NPC models `caretaker`, `pet_storekeeper` | art | in the same place other NPC models live |

## Network messages

Client to server (through the existing request path the economy/social code uses): `["pet_hatch"]`,
`["pet_feed", pet_id, bites]`, `["pet_merge", a_id, b_id]`, `["pet_equip", pet_id or 0]`.
Server to the owner: `["pets", state]` (the whole account state, after load and after every change).
Server to the realm: the equipped pet of each player rides along with the player's looks
(`{pet = {species, rarity}}` or none), so every client can draw everyone's pet; and a pulse
`["pet_pulse", owner_player_id, ability, target_pos or Vector3.INF for the owner, target_net_id]`, which clients
draw as a PetBeam from that owner's pet.

Persistence: the account service stores the account state as one JSON blob: `POST /server/pets/load
{character_id}` -> `{pets: state}`, `POST /server/pets/save {character_id, pets: state}` -> `{ok}`. The game
server loads it when a player joins and saves after each change (debounced 2 s, and on leave). The Pet Store is
the account service shop `pets` (item `pet_egg`), shown through the existing shop panel.

## The Pet Yard

Realm id `pty_<account id>` (`PetYardWorld.PREFIX = "pty_"`, `PetYardWorld.is_pet_yard(id)`), reached by a
portal in the Tavern ("Pet Yard" sign) and left through a portal back to the Tavern, exactly like the Chambers.
A cosy fenced meadow of voxel ground: paths, a pond, trees, a Hatching Nest, the Pet Store stall with the
storekeeper, the Caretaker's cottage with the Caretaker, food bowls, a little bridge. All the account's pets
wander free inside the fence (client-side, using their gaits) except the equipped one, which follows its owner.
Walk up to a wandering pet and interact to equip it ("Take <name> along"); walk up to your following pet to send
it back to play.

## Following

`PetFollower` keeps about 1.6 m behind and to the side of its owner, catching up faster when far (teleports past
25 m), and faces where it goes. Gaits: waddle (side-to-side rock), hop (small bounces), leap (big bounces with
pauses), squash (squash and stretch bounces), trot (quick bob), flap/glide (fly at 0.8 to 1.2 m, wing beats or
gentle glide), float/pulse/swim (hover with a slow bob or a pulse), plod (slow heavy bob), stomp (heavy steps),
wiggle (body sway). Idle: a small breathing bob, and now and then a cute idle (a turn, a hop).
