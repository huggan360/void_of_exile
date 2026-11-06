# Campaigns and campaign packs

Definitions live in `campaigns.gd` (shared by server and client); the server runs them in
`campaign_server.gd`, the client shows them in `campaign_client.gd` (+ `quest_banner.gd`,
`campaign_browser.gd`, `scene_dialog.gd`, `story_reader.gd`).

## Packs
`Campaigns.PACKS[id] = {title, blurb, campaigns: [ids in order]}`. Each campaign has `pack` and
`requires` (the previous one). All campaigns of a pack are told in ONE private world per leader
account: realm `camp_<account>_<pack>` + Tavern `ctav_<account>_<pack>`. Its state (broken
things, cleared packs, opened/forced-open gates, fog) is saved in the leader's book
(`book.worlds[pack]`, account service). When a campaign ends every member gets it marked done
(unlocking the next) and a copy of the world. The party stays in the world afterwards.
`coming_soon = true` shows a locked card.

## A campaign
`{id, pack, requires, title, level, blurb, intro (cinematic), xp, stars (5), steps, side}`.
Stars: `complete`, `time` (seconds), `no_deaths`, `no_wipes`, `side`.

## Step kinds (`steps[i].kind`)
| kind | does | fields |
|---|---|---|
| talk | speak to an npc | npc, say ("\|" = pages) |
| hand_over | talk, but only whoever carries `item` (consumed) | npc, item, say, lack |
| enter | step into the campaign realm | |
| interact / collect | search objects (each once) / take one | objects [{id, name, at, found}] |
| kill | kill `count` of `enemies`; `pack` is placed at `at` | enemies, count, pack, at |
| chest | a story chest (yellow, never expires) with `items`; done when `until` is taken. `at = "death"` = where the last kill fell; `guards = {pack, count}` ring it with enemies | items, until, at |
| ask_around | villagers of `village` wear "?"; asking rolls `chance`; `flee` = the rest run off; success reveals `reveal` (an npc with `from`) | village, chance, yes, no, flee, reveal |
| set_home | sign the steward's book in `village` | village |
| dungeon | a story dungeon portal (never expires until its boss falls) at `at` ("death" = where the last kill fell); whole party enters. With `encore` the first boss opens the follow-up portal and the step ends when the encore's boss falls (both portals stay until then) | dungeon, encore, at |
| vote | when the carrier of `item` returns, the party watches them and votes; `branches` maps the winning option to a step id (tie = first) | item, thought, options, branches |

Rewards: `reward` "dexterity" or "t<N>" (a grade-N item each).

Optional on any step: `world` ("hall" = the party's Tavern, "campaign", "dungeon"), `next` (step id
to continue with), `gather` (+`gather_range`: the first member near pulls the party in with the portal
flash), `shared` (everyone watches the conversation; only the starter turns pages), `reward`
("dexterity" potion / "t3" item per member, in their own chest), `xp`, `final` (ends the campaign).

## People
`Campaigns.NPCS[id] = {name, world, at | pos, campaign, from, model}`: stationary realm NPCs are spawned by
CampaignServer while their campaign plays (from step `from` on, or once revealed).
The party summary carries their authoritative positions, model and yaw; clients mirror that roster.
Offline previews still resolve the same authored anchors locally. Anchors: `{village,
offset}`, `{cabin: village}` (flat foot of the nearest mountain), `{summit: village}`,
`{stronghold: biome}`.

## Story items
`Items.STORY_ITEMS` (slot "story", icons in ~/Documents/Voidrealm_textures/story). Double-click
reads them (`StoryReader`). `story_clue` stacks up to 6 map pieces and keeps across the pack;
other story items and keys are removed when a campaign ends. A dying carrier drops them in a story
chest. Ambient goblins are held back in a pack world until The Lily Thief is done; authored quest packs are exempt
(`CampaignServer.HELD_BACK`).

## More options (campaigns 5-7)
- kill steps can supply `formation` (a pack definition) for guaranteed story counts. Combat anchors
  use `encounter_position` to stay beyond town perimeters; members stay within 20 m of the marker.
- kill steps: `any = true` counts every authored pack member (mixed ambush packs).
  Pack identity is checked on the server, so chasing enemies away from the marker cannot strand a quest.
- `cutscene` (a key of `Campaigns.CUTSCENES`): played for the whole party when the step ends, anywhere. A cutscene can
  `show_map` (the six pieces fitted together first) and have a `stage`: a scene (e.g. the castle,
  res://scenes/castle/hollow_castle.tscn) loaded at `stage_offset` far below the world just for the shots, whose shots
  name its markers (`from_marker`, `to_marker`, `look_marker`). The campaign-complete splash waits for it.
- `hidden = true` on a campaign: it doesn't appear in the book until the one it requires is told (The Hollow Castle).
- Interact objects can have a `look`: "bell", "stone" (whispering monolith), or brazier ids.
- `pack_end = true` (a pack's last campaign): after its cutscene everyone is sent to the Tavern, the pack's realm and
  castle close and are deleted from this server (they stay in every member's book to replay), then the campaign card
  shows, and the first time an account finishes the pack a "Campaign pack complete" card (+15000 XP, a G7 item).
- Worlds of a run: realm `camp_`, Tavern `ctav_`, and the Hollow Castle `cst_<account>_<pack>` (CastleWorld, entered
  through Aurelian's white portal; destination "castle"). Steps can use `world = "castle"`; its encounter (iron gate,
  guardian waves, throne key and door) is CastleWorld's (scenes/castle/README.md), the campaign counts its kills.

## Conversations, recovery and navigation
NPC proximity cards only show the name, quest badge and Talk action. Campaign dialogue starts a
server scene and advances on its final Exit, including handovers and side conversations. The
private Tavern stays accessible after dialogue; the player chooses when to leave. Gerald
also accepts the party's quest in the public Tavern, if a member was already waiting there.

Chest activation resolves its owning instance independently of the realm's lifetime. Once per
second, an active chest step with a member present recreates a missing chest. A missing bag is
not a completed step. Story dungeon entrances remain until the chest is taken. If its dungeon
has closed, recovery places the chest by the saved realm entrance. Clients can request a missing
chest mirror with `sync_chest`; the server checks the active step and the requester's world.

The summary includes objective instance/position and dungeon links. CampaignClient routes
through the current world's next portal, with matching world badges and minimap markers,
including encore chains and the castle return. Lily Thief revision 2 maps old numeric progress
to step ids before resuming, preserving saves across its inserted trail step.

## The Astral Frontier

`theory_of_everything` is the first tale in a separate, independently available
pack. It uses the same Realm 1 island as the other campaigns. Only this pack's
private realm carries `astral_station` in its realm record (including the client
entry record); ordinary public realms and The Hidden Power are unchanged.
`AstralStation.plan()` chooses one woodland clearing before terrain streaming.
The station footprint is reserved from packs, trees and decorative grass, and
`IslandWorld.astral_anchor()` supplies identical positions to story actors,
markers, the chest, boarding checks and the launch camera.

`AstralCampaign` extends the existing campaign authority for three step kinds:
`astral_parts` accepts each of the three distinct parts from any party member;
`astral_board` requires every party member to be alive, connected and at the hatch;
`astral_route` follows shared electrical state and route arrival. All five
unfinished cabinets have physical quest badges at once during the appropriate
ship objective. Wreck cabinets are on the lower deck beside the main passage.
The former algorithm gate and parity diagnostic are no longer active; the
transit platform remains continuous with its connecting road.

The authority opens the destination and publishes a future server-clock launch.
`AstralLaunchCinematic` and the station rocket use that same clock on every
client. A launch grants invincibility and immunity, hides the HUD and boarded
crew, and hands travel over to the existing asynchronous portal transition.
A member leaving or changing the boarding roster cancels the launch.

The account book's `run.astral` saves installed parts, seed, route checkpoint,
checked relays, repairs, opened doors and broken vents. Pausing evacuates the
whole party and closes the space instance. Resuming always returns to Orin and
requires boarding and flying again; the installed parts and ship circuits stay
saved. The Aurora is the arrival point on a repeat flight. The campaign stops
at the Convergence with an explicit waiting objective: no boss victory, rewards
or pack completion are granted before the future encounter is implemented.

`tools/check_astral_campaign.tscn` runs an account-free two-member flow through
the arena and pause/resume, including an account JSON round-trip of ship state.
Its optional `--preview` captures the launch station without using account data.
