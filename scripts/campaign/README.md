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

## The Astral Reach tales

The five tales after the Theory of Everything (`first_light`, `lantern_road`,
`shardfield`, `hollowmoon`, `pale_eye`, all `reach = true`) are told by
`ReachCampaign` in the shared `SpaceWorld` (realm `astral`). Their extra step
kinds are listed as a comment above `Campaigns.LIST`: `reach_ship`, `reach_fly`,
`reach_land` (any landing on that planet counts, pad or free landing),
`reach_dock`, `reach_kill` (ambushes are moved out of a planet's air, where the
brood never go), `reach_repair` and `reach_search`. Talk steps with world
`astral` use the Reach's people (`Campaigns.NPCS`, `at.nexus` or `at.planet`).
Search spots and npcs stand at the planet's story places (`SpaceLayout.PLACES`),
which the terrain keeps flat. `tools/test_reach_online.tscn` plays First Light
end to end against a `--test` server.

## Space Travels (mission 2: first_light, revision 2)

The first Reach tale after Theory of Everything is now titled **Space Travels**.
Its internal id stays `first_light`, so the Astral pack, completion records and
`lantern_road.requires` remain compatible; unfinished revision-1 runs restart
at the tutorial's ship-order step.

The server sends the party to a **private** `astral_camp_<account>_astral_frontier`
world using `PortServer.space_for(party.campaign.realm)`. The existing private
world access checks apply. Other Reach tales still use the shared `astral`.
All native ship/fortress logic continues to work in either kind of world.

Tutorial sequence:
1. `reach_order`: one party member deploys a fleet ship at Bell's command table.
2. `reach_ship`: board it. If the ship disappears before the city stage,
   the first tutorial objectives return to `reach_order`.
3. `reach_tutorial_fly`: launch towards Rosamund; after about halfway a
   brood skiff spawns astern. A camera shot shows the attacker and a
   moving objective badge follows that specific skiff.
4. `reach_tutorial_ambush`: destroy the skiff. A second comes if necessary.
   The tutorial advances after a kill and 50% hull damage, or two kills;
   the ship is deliberately stopped and all four native parts broken.
   During the ambush and repair stages the hull cannot fall below 50%.
5. `reach_tutorial_repair`: a second camera tour shows the ladder, sails,
   engines, top cannon and interior heart crystal. Repair all four using
   the native `repair` interaction and four-second mend timer. There are
   no ambient brood attackers while this private tutorial is active.
6. `reach_port`: land specifically at `rosamund:dock`, the Petalgate
   shipyard, not just anywhere on the planet.
7. Talk with Warden Elowen in Petalgate's town centre to receive the Rose
   Bastion key. Opening the existing fortress gate consumes the key.
8. `reach_boss`: Queen Briarrose's **server-confirmed** death in that
   private instance advances the quest.
9. `reach_dock`: take a ship back to the Nexus and really dock it.
   A ship that was already docked when this objective began doesn't count.
10. `reach_party_nexus`: every connected, alive party member must be
    physically in the Nexus station zone for campaign completion.

**Private campaign ship persistence rule:** while any private-world campaign
run is active, its party's ships must not be automatically stored for fleet
idleness, even if the party has left them parked on a planet or in orbit.
The private instance must also remain loaded while it holds such protected
ships, even if temporarily empty. Once a tale is paused, ended or abandoned,
normal fleet lease, storage and world unloading rules apply. The account
service's lease still requires successful heartbeats; it cannot be extended
locally without the account service.

Static contract check (needs the project's voxel-enabled Godot build):
`godot --headless --path . --script res://tools/check_space_travels.gd`.
For end-to-end verification, use a test account on a `--test` server and
check fleet deployment, the moving skiff marker, both cinematic shots, native
repairs, Petalgate-only landing, the key, the fortress victory, and the full
party's return. The old `tools/test_reach_online.tscn` was authored for
revision-1 First Light and should be revised before using it for mission 2.

## Vesperis (mission 3: lantern_road, revision 2)

This is the third Astral Frontier campaign, now titled **Vesperis**. Its saved
identifier stays `lantern_road` so `shardfield.requires` and finished tales
remain compatible. Active revision-1 Lantern Road runs restart at the new
arrival objective when migrated.

Like Space Travels, Vesperis uses a party-private Reach through
`PortServer.space_for(party.campaign.realm)`. Fleet persistence in private
campaign worlds is unchanged. The remaining Reach tales use the shared Reach.

### Seven mission objectives

1. Land at any **Lanternheart Spaceport** pad on Vesperis.
2. Speak to **Wizard Aldren**, standing outside the existing wizard shop.
   The existing shop remains usable for buying wands and magic.
3. Visit a Lanternheart pub, order beer from the bar's actual tap and drink
   two **complete four-sip mugs per party member**. The authority checks the
   true city venue, each ordered mug's unique id, the drinking location and
   the individual member's progress. Beer from the ship and coffee do not
   count. The quest mark points to a real nearby Lanternheart bar.
4. Follow the country road to an existing red-barn farmstead on Vesperis
   (index `CityCountry.FARMS[0]`, within the playable planet combat cap)
   and defeat the user's existing `mad_farmer` three-phase shotgun boss.
   The private realm owns a finite `quest_lantern_road_<attempt>_farmer`
   site and the server confirms that specific boss's death.
5. Open the persistent gold **Story Chest** in the farmyard to collect
   `story_wizard_starball`, the magical sphere stolen from the wizard.
   The quest waits for a real party member to possess it, and can recreate
   the chest if the ball is lost.
6. Return to Aldren at the wizard shop. The story dialogue requires a party
   member to have the starball and takes it once the conversation ends.
7. Every party member collects their own guaranteed **G5_wand** from a
   **personal blue chest** spawned outside Aldren's shop. The mission
   completes only after the contents have been claimed by everyone.
   Expired unclaimed chests are recreated; claimed ones are not duplicated.

### Check

After importing with the project's voxel-enabled Godot build, run:

`/home/hugo/godot/engine/godot_voxel_editor --headless --path . --script res://tools/check_vesperis_campaign.gd`

This script validates the authored assets, real shop/pub and farm positions,
the boss definition, private realm selection, quest steps and rewards.
It is a **contract check, not an online end-to-end playthrough**. An online
test using the documented test account should also verify a two-player party,
actual beer ordering/sipping, the boss's combat and death, picking up the
starball, the wizard's handover and both personal Blue Chests.

## The Starwright's Missing Parts (mission 4: shardfield, revision 2)

The fourth Astral Frontier mission is reworked from the original asteroid
pass into a three-planet retrieval adventure, while its internal id remains
`shardfield`. Already-finished campaign records and
`hollowmoon.requires = shardfield` remain intact. Unfinished revision-1
campaigns restart at the new first quest objective.

This mission uses its own private `astral_<campaign realm>` SpaceWorld, as
missions 2 and 3 do. It keeps the native ship persistence rules, fleet
behavior, boss scripts, rewards and story-item inventory model.

**The commission**: Starwright Fen is in the shipwright yard of
Mossbrook, on Verdance. Completing his shared conversation immediately
plays the real three-shot `starwright_three_worlds` CampaignCinematic:
a flyover of Vesperis (navigation core), Amberfall (Aurum and amber power
regulator), and Tidewell (NPC clues and tidal stabilizer). The normal Space
scene stays visible; each shot includes a caption with the next objective.
The existing hold-Space-to-skip cinematic control continues to work.

**Vesperis**: Scrapper Nix stands on the sidewalk outside the existing
general shop in Lanternheart. Interacting with him during the purchase
objective charges the purchasing player 500 Dots through
`EconomyServer.spend`. This authorises a **gold Story Chest** beside
his shop containing the real `story_nav_core`. The merchant does not
directly give an item. The quest advances only when a party member
takes the core out of the chest. The server verifies proximity, payment,
and real story-item inventory. Only one 500-Dot purchase is required
per party; the saved `shard_nav_paid` receipt lets an absent, expired,
or emptied chest respawn without another charge if the part is lost.
A full backpack does not consume the purchased core; the chest remains
waiting until the player can make room.

**Amberfall**: Warden Saffron is in Honeymarket's plaza and gives the
real `key_amber_ziggurat` after her story conversation. The party must
unlock the existing Ziggurat gate and defeat the original
`amber_colossus` Boss, Aurum; only the server's actual boss-death
callback advances the step. The warden reissues a key after a reset when
necessary. The Amber Power Regulator appears in a persistent golden
Story Chest near the fortress arena after victory.

**Tidewell**: two sequential NPC conversations lead from Fisher Mira
in Saltstilts to Keeper Brine at the lighthouse. He reveals the Shell
Shrine, where a separate golden Story Chest contains the Tidal Stabilizer.
The chest and marker are not revealed in earlier mission steps.

**Return to Verdance**: Only after all three actual items are held by
party members does Fen's final dialogue start. Its completion consumes
all three after a full inventory recheck, then awards normal mission XP
and progression to the next campaign. The purchased part cannot be
faked with a UI marker; **all three components come from persistent,
server-authoritative golden Story Chests**. The two found items can be
reacquired at their original sources after the appropriate quest step;
the Vesperis chest remains recoverable using the original payment.

For a headless contract test with the project's custom voxel Godot build:

`godot --headless --path . --script res://tools/check_shardfield_parts_campaign.gd`

The test checks definitions, NPCs, actual planets, the three shots,
key/boss pairing, price, story items and final objective. It is not a
substitute for a multiplayer playthrough. Test the 500-Dot sale (including
insufficient funds), that a gold Story Chest appears instead of a direct
item, collecting the core from that chest, re-opening the chest without
paying again, and leaving the item waiting when the backpack is full.
Also test key reissue, Aurum defeat and his gold Story Chest, Tidewell
conversations, party-shared handover and the cinematic.
