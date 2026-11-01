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
`Campaigns.NPCS[id] = {name, world, at | pos, campaign, from, model}`: realm npcs are spawned by
the client while their campaign plays (from step `from` on, or once revealed). Anchors: `{village,
offset}`, `{cabin: village}` (flat foot of the nearest mountain), `{summit: village}`,
`{stronghold: biome}`.

## Story items
`Items.STORY_ITEMS` (slot "story", icons in ~/Documents/Voidrealm_textures/story). Double-click
reads them (`StoryReader`). `story_clue` stacks up to 6 map pieces and keeps across the pack;
other story items and keys are removed when a campaign ends. A dying carrier drops them in a story
chest. Goblins are held back in a pack world until The Lily Thief is done
(`CampaignServer.HELD_BACK`).

## More options (campaigns 5-7)
- kill steps: `any = true` counts every enemy that falls within 40 m of `at` (mixed ambush packs).
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
