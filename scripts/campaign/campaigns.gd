class_name Campaigns
## Campaign definitions, shared by the server (which runs them) and the
## client (which shows them). See scripts/campaign/README.md.
##
## A campaign pack is a story told over several campaigns, played in order
## in ONE private world that belongs to the party leader (saved as it goes,
## and copied to every member when a campaign ends). A campaign is a list of
## steps the party shares; NPCS are the people of the story.
##
## Story text may mark words: [npc]Gerald[/npc] (green), [enemy]...[/enemy]
## (red), [place]...[/place] (blue), [b]...[/b]; "|" splits speech into pages.

const PACKS := {
	hidden_power = {
		id = "hidden_power", title = "The Hidden Power",
		blurb = "Torn pieces of an old map, a power hidden in the mountains, and a Hearthhaven gardener who only wanted his lilies back.",
		campaigns = ["lily_thief", "frozen_whisper", "sunken_court", "ember_oath", "drowned_choir", "hollow_hour", "hollow_castle"],
	},
}

## The people of the stories. world: "hall" (the party's Tavern) or
## "campaign" (its realm). campaign + from: only there during that campaign,
## from that step on (someone you only find by asking around...).
const NPCS := {
	gerald = {name = "Gerald the Gardener", world = "hall", pos = Vector3(3, 10, 36)},
	wren = {name = "Old Wren", world = "campaign", campaign = "lily_thief", at = {village = "Bramblebrook", offset = Vector3(-7, 0, 9)}},
	maribel = {name = "Maribel the Weaver", world = "campaign", campaign = "lily_thief", from = "maribel",
		at = {village = "Bramblebrook", offset = Vector3(6, 0, -9)}, model = "npc_baker"},
	ottar = {name = "Ottar the Forgehand", world = "campaign", campaign = "lily_thief", from = "forge",
		at = {village = "Hearthwick", offset = Vector3(10, 0, -8)}, model = "npc_smith"},
	tobias = {name = "Tobias the Trapper", world = "campaign", campaign = "frozen_whisper", from = "tobias",
		at = {village = "Snowbell", offset = Vector3(-6, 0, 8)}, model = "npc_traveler"},
	halvard = {name = "Halvard of the Peaks", world = "campaign", campaign = "frozen_whisper", from = "halvard",
		at = {cabin = "Snowbell", offset = Vector3(3, 0, 3)}, model = "npc_traveler"},
	zahra = {name = "Zahra the Caravan Master", world = "campaign", campaign = "sunken_court",
		at = {village = "Sunveil", offset = Vector3(8, 0, 6)}, model = "npc_magician"},
	nadim = {name = "Nadim the Blind", world = "campaign", campaign = "sunken_court", from = "nadim",
		at = {village = "Sunveil", offset = Vector3(-9, 0, -7)}, model = "npc_traveler"},
	mirela = {name = "Mirela of the Tides", world = "campaign", campaign = "drowned_choir",
		at = {stronghold = "Bluelay", offset = Vector3(0, 0, 62)}, model = "npc_magician"},
	oskar = {name = "Oskar the Diver", world = "campaign", campaign = "drowned_choir",
		at = {stronghold = "Bluelay", offset = Vector3(-24, 0, 66)}, model = "npc_traveler"},
	wick = {name = "Old Wick the Lamplighter", world = "campaign", campaign = "hollow_hour",
		at = {stronghold = "The Deep Dark", offset = Vector3(0, 0, 64)}, model = "npc_traveler"},
	stranger = {name = "The Stranger", world = "campaign", campaign = "hollow_hour", from = "stranger",
		at = {village = "Hearthwick", offset = Vector3(4, 0, 6)}, model = "npc_magician"},
	aurelian = {name = "Aurelian the Old Wizard", world = "campaign", campaign = "hollow_castle",
		at = {village = "Hearthwick", offset = Vector3(-6, 0, 8)}, model = "npc_magician"},
	kael = {name = "Brother Kael", world = "campaign", campaign = "ember_oath",
		at = {stronghold = "Doom", offset = Vector3(0, 0, 58)}, model = "npc_smith"},
}

const _LILY_INTRO := {
	title = "The Lily Thief",
	loading = {title = "The Lily Thief", subtitle = "The Hidden Power  ·  part one", seconds = 3.0},
	shots = [
		{from = Vector3(46, 32, 96), to = Vector3(26, 22, 74), look_from = Vector3(0, 10, 40), look_to = Vector3(0, 10, 46), duration = 7.5,
			cards = [{text = "[place]Hearthhaven[/place] sleeps.", at = 0.8, hold = 2.6},
				{text = "But every night, something creeps through [npc]Gerald[/npc]'s garden.", at = 3.8, hold = 3.4}]},
		{from = Vector3(-20, 14, 26), to = Vector3(-14, 12.5, 52), look_from = Vector3(-9.5, 10, 36), look_to = Vector3(-9.5, 10, 58), duration = 7.0,
			cards = [{text = "And every morning, another bed of moon-lilies is gone.", at = 0.6, hold = 3.0},
				{text = "Nibbled to the stalk. Something with teeth.", at = 3.9, hold = 2.9}]},
		{from = Vector3(9, 13.5, 20), to = Vector3(6.5, 12, 28.5), look_from = Vector3(3, 11.2, 36), look_to = Vector3(3, 11.2, 36), duration = 8.0,
			cards = [{text = "Gerald has stopped sleeping.", at = 0.5, hold = 2.4},
				{text = "He has started sharpening his trowel.", at = 3.0, hold = 2.4},
				{text = "Go and talk to [npc]Gerald[/npc].", at = 5.6, hold = 2.3}]},
	],
}

## Step kinds (see README): talk, enter, interact, collect, kill, chest,
## hand_over, ask_around, set_home, dungeon, vote. Optional on any step:
## next (step id to go to after it), gather (pull the party together at its
## spot first), shared (everyone watches the conversation), reward
## ("dexterity" potions or a "t3" item each, in chests), xp.
const LIST := {
	lily_thief = {
		id = "lily_thief", pack = "hidden_power", title = "The Lily Thief", level = 1,
		blurb = "Every night something creeps through Gerald's garden, and every morning another bed of moon-lilies is gone. Find out what has teeth enough to eat them.",
		intro = _LILY_INTRO, xp = 600,
		stars = [
			{id = "complete", text = "Finish the tale"},
			{id = "time", text = "Finish within 35 minutes", seconds = 2100},
			{id = "time", text = "Finish within 20 minutes", seconds = 1200},
			{id = "no_deaths", text = "Nobody in the party falls"},
			{id = "side", text = "Help Old Wren"},
		],
		steps = [
			{id = "gerald", kind = "talk", npc = "gerald", world = "hall", text = "Talk to Gerald in the Tavern garden",
				say = "Gone! The last of my moon-lilies, [b]gone[/b]!|Something with [enemy]teeth[/enemy] drags them off at night, out past the realm gate.|The meadow beyond [place]Bramblebrook[/place], I'd wager. Please, find it, and bring me back one living lily!"},
			{id = "gate", kind = "enter", world = "campaign", text = "Step through the realm gate, north of the fountain"},
			{id = "bloom", kind = "kill", world = "campaign", text = "Find what eats the lilies in the meadow beyond Bramblebrook", count = 1,
				enemies = ["thornmaw_bloom"], pack = "thornmaw", gather = true, at = {village = "Bramblebrook", offset = Vector3(48, 0, 20)}},
			{id = "bloom_chest", kind = "chest", world = "campaign", text = "Open the story chest the Thornmaw left behind",
				at = "death", items = ["story_moon_lily", "story_clue"], until = "story_moon_lily"},
			{id = "lily", kind = "hand_over", npc = "gerald", world = "hall", item = "story_moon_lily", text = "Bring the moon-lily back to Gerald",
				lack = "If only I had my moon-lily back... Whoever carries it, bring it to me!",
				say = "My lily! Alive, and still smelling of moonlight!|And what's this scrap of paper? A [b]map[/b], torn... with a mark like a crown.|Old [place]Bramblebrook[/place] folk know these hills. Ask around there: someone will know what it means."},
			{id = "ask", kind = "ask_around", world = "campaign", village = "Bramblebrook", chance = 0.5, reveal = "maribel",
				text = "Ask the people of Bramblebrook about the torn map",
				yes = "The map? You want [npc]Maribel[/npc] the weaver, she collects old things. She's by her loom.",
				no = "A map? Can't say I've seen one. Ask someone else."},
			{id = "maribel", kind = "talk", npc = "maribel", world = "campaign", text = "Talk to Maribel the weaver in Bramblebrook",
				say = "That mark... I've seen it before, on my grandmother's [b]necklace[/b].|A [enemy]goblin[/enemy] snatched it from my window last night and ran into the woods!|Bring it back, and I'll tell you everything I know."},
			{id = "thief", kind = "kill", world = "campaign", text = "Catch the goblin thief in the woods", count = 1,
				enemies = ["goblin_thief"], pack = "story_goblin", at = {village = "Bramblebrook", offset = Vector3(-30, 0, 36)}},
			{id = "cave", kind = "dungeon", world = "campaign", dungeon = "goblins_cave", at = "death",
				text = "The thief fled into a cave. Follow it down and defeat the Goblin King"},
			{id = "necklace", kind = "chest", world = "dungeon", text = "Take the necklace from the story chest", at = "death",
				items = ["story_necklace"], until = "story_necklace"},
			{id = "vote", kind = "vote", world = "campaign", item = "story_necklace", text = "Return to the realm with the necklace",
				thought = "It's beautiful... and no one would ever know. Maybe I should [b]keep it[/b]?",
				options = {give = "Hand it back", keep = "Keep it"}, branches = {give = "give", keep = "forge"}},
			{id = "forge", kind = "hand_over", npc = "ottar", world = "campaign", item = "story_necklace", xp = 300, next = "lie",
				text = "Take the necklace to the forge in Hearthwick",
				lack = "Bring me whatever it is you want melted, friend.",
				say = "Silver and an old stone. I'll melt it down, no questions asked.|There. Nobody will ever know it was a necklace."},
			{id = "lie", kind = "talk", npc = "maribel", world = "campaign", shared = true, next = "farewell",
				text = "Go back to Maribel in Bramblebrook",
				say = "You couldn't find it? Oh...|Well. You were brave to chase a goblin for an old woman's trinket."},
			{id = "give", kind = "hand_over", npc = "maribel", world = "campaign", item = "story_necklace", shared = true, next = "farewell",
				text = "Give the necklace back to Maribel in Bramblebrook",
				lack = "Whoever carries my necklace, please...",
				say = "My grandmother's necklace! Thank you, thank you all!"},
			{id = "farewell", kind = "talk", npc = "maribel", world = "campaign", shared = true, reward = "dexterity", final = true,
				text = "Hear what Maribel knows",
				say = "Your torn map... my grandmother wore that crown mark until the day she died.|She said a [b]secret force[/b] lives up in the [place]mountains[/place], and that we must never speak of it.|I've said too much already. Take these for your trouble... and forget my name!"},
		],
		side = [
			{id = "wren", kind = "talk", npc = "wren", world = "campaign", text = "Talk to Old Wren in Bramblebrook",
				say = "Never mind lilies, I've lost my good bell!|The [enemy]hoppers[/enemy] knocked it off my gate and rolled it somewhere by the well. Would you look?"},
			{id = "bell", kind = "collect", world = "campaign", text = "Find Old Wren's bell", verb = "Pick up",
				objects = [{id = "wren_bell", name = "Old Wren's bell", at = {village = "Bramblebrook", offset = Vector3(-15, 0, 18)},
					found = "%s found Old Wren's bell."}]},
		],
	},
	frozen_whisper = {
		id = "frozen_whisper", pack = "hidden_power", requires = "lily_thief", title = "The Frozen Whisper", level = 8,
		blurb = "The crown mark leads north, to Snowbell and the frozen peaks. Somebody there knows of the hidden power, if you can find them before they run.",
		xp = 1200, ice_open = true,
		stars = [
			{id = "complete", text = "Finish the tale"},
			{id = "time", text = "Finish within 40 minutes", seconds = 2400},
			{id = "time", text = "Finish within 25 minutes", seconds = 1500},
			{id = "no_deaths", text = "Nobody in the party falls"},
			{id = "no_wipes", text = "Win the stronghold on the first try"},
		],
		steps = [
			{id = "gate", kind = "enter", world = "campaign", text = "Step through the Chronicle Gate south of the fountain and travel north to Snowbell"},
			{id = "ask", kind = "ask_around", world = "campaign", village = "Snowbell", chance = 0.15, flee = true, reveal = "tobias",
				text = "Ask the people of Snowbell about the crown mark",
				yes = "Shh! Not so loud. [npc]Tobias[/npc] the trapper. Talk to him, not me.",
				no = "Get away from me! I don't know anything!"},
			{id = "tobias", kind = "talk", npc = "tobias", world = "campaign", text = "Talk to Tobias the trapper in Snowbell",
				say = "Let me see that map. The crown... I know it.|My friend [npc]Halvard[/npc] lives at the foot of the mountain. He'll tell you more.|But the climb is cruel: make [place]Snowbell[/place] your home first. Sign the steward's book."},
			{id = "home", kind = "set_home", village = "Snowbell", world = "campaign", text = "Make Snowbell your home at the steward's book"},
			{id = "halvard", kind = "talk", npc = "halvard", world = "campaign", shared = true, gather = true,
				text = "Find Halvard's cabin at the foot of the mountain",
				say = "Tobias sent you? Then you've seen the crown.|There is a power on the [place]summit[/place], older than the realm. Things guard it.|Climb, take what lies at the top, and come back to me."},
			{id = "summit", kind = "chest", world = "campaign", text = "Fight your way to the mountain top and open the chest",
				at = {summit = "Snowbell"}, items = ["story_ice_card", "key_crown_of_the_rime"], until = "story_ice_card",
				guards = {pack = "mountain_guard", count = 5}},
			{id = "stronghold", kind = "kill", world = "campaign", text = "Unlock the Crown of the Rime and defeat what waits inside", count = 1,
				enemies = ["rimeheart_prism"], gather = true, gather_range = 45.0, at = {stronghold = "Fosen"}},
			{id = "shard", kind = "chest", world = "campaign", text = "Take the second piece of the map", at = "death",
				items = ["story_clue"], until = "story_clue"},
			{id = "return", kind = "talk", npc = "halvard", world = "campaign", shared = true, reward = "t3", final = true,
				text = "Bring the map pieces back to Halvard's cabin",
				say = "Two pieces now. The lines match, see? The next edge runs south, under the [place]desert sands[/place].|You've done well. Take these. The rest of the map is out there, waiting."},
		],
		side = [],
	},
	sunken_court = {
		id = "sunken_court", pack = "hidden_power", requires = "frozen_whisper", title = "The Sunken Court", level = 12,
		blurb = "South, where the Scarab Regent's court was swallowed by the sand. A caravan robbed, a seal that opens what should stay shut, and a blind man who sees too much.",
		xp = 1800,
		stars = [
			{id = "complete", text = "Finish the tale"},
			{id = "time", text = "Finish within 45 minutes", seconds = 2700},
			{id = "time", text = "Finish within 28 minutes", seconds = 1680},
			{id = "no_deaths", text = "Nobody in the party falls"},
			{id = "no_wipes", text = "Never lose the whole party"},
		],
		steps = [
			{id = "gate", kind = "enter", world = "campaign", text = "Step through the Chronicle Gate south of the fountain and travel south to Sunveil"},
			{id = "zahra", kind = "talk", npc = "zahra", world = "campaign", text = "Find Zahra the caravan master in Sunveil",
				say = "Two map pieces and a crown mark? Then you're hunting the [place]Sunken Court[/place].|My caravan carried its old [b]sun seal[/b] until [enemy]dune raiders[/enemy] took it last night, out in the dunes.|Get it back and I'll tell you what it opens."},
			{id = "raiders", kind = "kill", world = "campaign", text = "Defeat the dune raiders in the dunes (%d/%d)", count = 5,
				enemies = ["sand_scorpion", "dune_crawler"], pack = "dune_raiders", gather = true, at = {village = "Sunveil", offset = Vector3(-44, 0, 30)}},
			{id = "seal_chest", kind = "chest", world = "campaign", text = "Take the sun seal from the raiders' chest", at = "death",
				items = ["story_sun_seal"], until = "story_sun_seal"},
			{id = "seal", kind = "hand_over", npc = "zahra", world = "campaign", item = "story_sun_seal", shared = true,
				text = "Bring the sun seal back to Zahra", lack = "The seal, friend. Whoever holds it, bring it here.",
				say = "That's it. Gold, with the Regent's scarab on it.|It opens the way down, where the [b]scarabs dance[/b] at dusk. Only old [npc]Nadim[/npc] knows where that is, and he hides from strangers.|Ask around. Someone will point you to him."},
			{id = "ask", kind = "ask_around", world = "campaign", village = "Sunveil", chance = 0.35, reveal = "nadim",
				text = "Ask the people of Sunveil where Nadim the Blind lives",
				yes = "Nadim? He sits behind the well, listening to the sand. Be polite.", no = "Nadim? Never heard of him. Move along."},
			{id = "nadim", kind = "talk", npc = "nadim", world = "campaign", shared = true,
				text = "Talk to Nadim the Blind",
				say = "You carry the sun seal. I can hear it humming.|The scarabs dance on the great dune east of here. Hold the seal up there and the sand will open.|The court below never ended. Its [enemy]Gilded Vizier[/enemy] still holds the third edge of your map."},
			{id = "court", kind = "dungeon", world = "campaign", dungeon = "sunken_court", at = {village = "Sunveil", offset = Vector3(62, 0, -26)},
				text = "Open the Sunken Court on the great dune and defeat the Gilded Vizier"},
			{id = "piece", kind = "chest", world = "dungeon", text = "Take the third piece of the map", at = "death",
				items = ["story_clue"], until = "story_clue"},
			{id = "home", kind = "talk", npc = "zahra", world = "campaign", shared = true, reward = "t4", final = true,
				text = "Return to Zahra in Sunveil",
				say = "Three pieces. Hold them together... the line runs into fire, toward the [place]Cinder Bastion[/place].|Whoever drew this map wanted it found, but only by the stubborn.|The caravan thanks you. Take these, and mind the heat."},
		],
		side = [],
	},
	ember_oath = {
		id = "ember_oath", pack = "hidden_power", requires = "sunken_court", title = "The Ember Oath", level = 16,
		blurb = "Into the lands of Doom, beneath a mountain of fire and on into the burning forest beyond. An oath sworn in embers, and a choice that can't be taken back.",
		xp = 2600,
		stars = [
			{id = "complete", text = "Finish the tale"},
			{id = "time", text = "Finish within 50 minutes", seconds = 3000},
			{id = "time", text = "Finish within 32 minutes", seconds = 1920},
			{id = "no_deaths", text = "Nobody in the party falls"},
			{id = "no_wipes", text = "Never lose the whole party"},
		],
		steps = [
			{id = "gate", kind = "enter", world = "campaign", text = "Step through the Chronicle Gate south of the fountain and head for the lands of Doom"},
			{id = "kael", kind = "talk", npc = "kael", world = "campaign", gather = true, text = "Find Brother Kael outside the Cinder Bastion",
				say = "Pilgrims, with a map that burns in my hands. Hm.|The fourth edge lies beneath the mountain of fire, guarded by its [enemy]Warden[/enemy], and beyond it a forest that never stops burning.|First, prove you mean no harm: relight the three [b]oath-braziers[/b] the cultists put out."},
			{id = "braziers", kind = "interact", world = "campaign", text = "Relight the oath-braziers around the Bastion (%d/%d)", verb = "Relight",
				objects = [
					{id = "brazier_1", name = "Cold oath-brazier", at = {stronghold = "Doom", offset = Vector3(-34, 0, 48)}, found = "The first brazier roars back to life."},
					{id = "brazier_2", name = "Cold oath-brazier", at = {stronghold = "Doom", offset = Vector3(36, 0, 50)}, found = "The second brazier flares."},
					{id = "brazier_3", name = "Cold oath-brazier", at = {stronghold = "Doom", offset = Vector3(2, 0, 76)}, found = "The third brazier burns, and the air goes still."},
				]},
			{id = "cult", kind = "kill", world = "campaign", text = "The cultists come back for their braziers: defeat them (%d/%d)", count = 6,
				enemies = ["ember_mite", "cinder_beetle"], pack = "ash_cult", gather = true, at = {stronghold = "Doom", offset = Vector3(0, 0, 90)}},
			{id = "depths", kind = "dungeon", world = "campaign", dungeon = "cinder_depths", encore = "cinder_depths_encore", at = "death",
				text = "Their leader's blood opened a way down: clear the Cinder Depths, then its burning Encore"},
			{id = "piece", kind = "chest", world = "dungeon", text = "Take the fourth piece of the map from the ashes", at = "death",
				items = ["story_clue"], until = "story_clue"},
			{id = "oath", kind = "vote", world = "campaign", item = "story_clue", text = "Return to Brother Kael with the map",
				thought = "Kael is waiting with his hands held out. [b]Swear the Ember Oath[/b] to guard the map with your lives... or keep your freedom?",
				options = {swear = "Swear the Ember Oath", refuse = "Refuse"}, branches = {swear = "sworn", refuse = "refused"}},
			{id = "sworn", kind = "talk", npc = "kael", world = "campaign", shared = true, xp = 800, next = "farewell",
				text = "Swear the oath before Brother Kael",
				say = "Then say it with me: [b]what burns, binds[/b].|It is done. The fire knows your names now, and it will not let you fall easily."},
			{id = "refused", kind = "talk", npc = "kael", world = "campaign", shared = true, next = "farewell",
				text = "Tell Brother Kael you refuse",
				say = "Free, then. The fire does not beg.|But it will remember you walked away."},
			{id = "farewell", kind = "talk", npc = "kael", world = "campaign", shared = true, reward = "t4", final = true,
				text = "Hear Brother Kael's warning",
				say = "Four pieces. Two remain, and they lie in the [place]dark[/place], where the Hollow Crown sits.|Whoever wears that crown is looking for this map too. Hurry."},
		],
		side = [],
	},
	drowned_choir = {
		id = "drowned_choir", pack = "hidden_power", requires = "ember_oath", title = "The Drowned Choir", level = 20,
		blurb = "Under the blue waters a choir still sings, and two seals hold it down: the Siren's pearl and the Cantor's bells. The fifth piece of the map sank with them.",
		xp = 3400,
		stars = [
			{id = "complete", text = "Finish the tale"},
			{id = "time", text = "Finish within 60 minutes", seconds = 3600},
			{id = "time", text = "Finish within 40 minutes", seconds = 2400},
			{id = "no_deaths", text = "Nobody in the party falls"},
			{id = "side", text = "Help Oskar the diver"},
		],
		steps = [
			{id = "gate", kind = "enter", world = "campaign", text = "Step through the Chronicle Gate south of the fountain and go to the blue shores of Bluelay"},
			{id = "mirela", kind = "talk", npc = "mirela", world = "campaign", gather = true, text = "Find Mirela of the Tides by the Azure Crucible",
				say = "Four pieces, and the fifth sank with the [place]Drowned Spire[/place]. I hear it every night.|Two seals hold the Spire down: the [enemy]Siren[/enemy]'s pearl in the grotto, and the [enemy]Cantor[/enemy]'s bells in the tower.|The tide-heralds guard the grotto's mouth. Break them, and the water will let you in."},
			{id = "heralds", kind = "kill", world = "campaign", text = "Break the tide-heralds on the shore (%d/%d)", count = 5,
				enemies = [], any = true, pack = "tide_heralds", gather = true, at = {stronghold = "Bluelay", offset = Vector3(-52, 0, 74)}},
			{id = "grotto", kind = "dungeon", world = "campaign", dungeon = "azure_grotto", at = "death",
				text = "Dive into the Azure Grotto and silence the Abyssal Siren"},
			{id = "pearl", kind = "chest", world = "dungeon", text = "Take the Siren's pearl", at = "death",
				items = ["story_tide_pearl"], until = "story_tide_pearl"},
			{id = "seal", kind = "hand_over", npc = "mirela", world = "campaign", item = "story_tide_pearl", shared = true,
				text = "Bring the Siren's pearl to Mirela", lack = "The pearl, child. Whoever carries the pearl.",
				say = "Hold it to your ear... can you hear them? The whole choir, still singing under the sea.|The second seal: ring the three [b]drowned bells[/b] along the shore. The [enemy]Spire Keeper[/enemy] will rise to stop you. Let him."},
			{id = "bells", kind = "interact", world = "campaign", text = "Ring the drowned bells along the shore (%d/%d)", verb = "Ring",
				objects = [
					{id = "bell_1", look = "bell", name = "Drowned bell", at = {stronghold = "Bluelay", offset = Vector3(-40, 0, 40)}, found = "A low note rolls across the water."},
					{id = "bell_2", look = "bell", name = "Drowned bell", at = {stronghold = "Bluelay", offset = Vector3(44, 0, 46)}, found = "The second bell answers the first."},
					{id = "bell_3", look = "bell", name = "Drowned bell", at = {stronghold = "Bluelay", offset = Vector3(0, 0, 96)}, found = "The third bell rings... and something rings back from under the sea."},
				]},
			{id = "keeper", kind = "kill", world = "campaign", text = "Defeat the Spire Keeper", count = 1,
				enemies = ["spire_keeper"], pack = "spire_keeper", gather = true, gather_range = 30.0, at = {stronghold = "Bluelay", offset = Vector3(0, 0, 110)}},
			{id = "spire", kind = "dungeon", world = "campaign", dungeon = "drowned_spire", at = "death",
				text = "Descend the Drowned Spire and end the Drowned Cantor's song"},
			{id = "piece", kind = "chest", world = "dungeon", text = "Take the fifth piece of the map", at = "death",
				items = ["story_clue"], until = "story_clue"},
			{id = "song", kind = "vote", world = "campaign", item = "story_clue", text = "Return to the shore",
				thought = "The choir is silent now, but one voice still hums in your head, sweet and patient. [b]Sing back[/b]... or keep silent?",
				options = {silence = "Keep silent", sing = "Sing back"}, branches = {silence = "silent", sing = "sang"}},
			{id = "silent", kind = "talk", npc = "mirela", world = "campaign", shared = true, next = "farewell", xp = 600,
				text = "Tell Mirela what you heard", say = "Silence. Good. Whatever hums in your head now wants an answer. Never give it one."},
			{id = "sang", kind = "talk", npc = "mirela", world = "campaign", shared = true, next = "farewell",
				text = "Tell Mirela what you did", say = "You sang back?|Then it knows your voice now. It will remember it. I'm sorry."},
			{id = "farewell", kind = "talk", npc = "mirela", world = "campaign", shared = true, reward = "t5", final = true,
				text = "Hear Mirela's warning",
				say = "Five pieces. The last lies in the [place]Deep Dark[/place], where the light goes to die.|Go with a lamplighter. Never go alone. And never answer anything that calls you by name."},
		],
		side = [
			{id = "oskar", kind = "talk", npc = "oskar", world = "campaign", text = "Talk to Oskar the diver on the shore",
				say = "My helmet! The heralds chased me out of the water and I dropped it somewhere on the beach. Find it?"},
			{id = "helmet", kind = "collect", world = "campaign", text = "Find Oskar's diving helmet", verb = "Pick up",
				objects = [{id = "oskar_helmet", name = "Oskar's diving helmet", at = {stronghold = "Bluelay", offset = Vector3(-30, 0, 92)},
					found = "%s found Oskar's diving helmet."}]},
		],
	},
	hollow_hour = {
		id = "hollow_hour", pack = "hidden_power", requires = "drowned_choir", title = "The Hollow Hour", level = 24,
		blurb = "The last piece of the map waits in the Deep Dark. Take a lamplighter's advice: don't listen to the stones, and don't turn around.",
		xp = 5000,
		stars = [
			{id = "complete", text = "Finish the tale"},
			{id = "time", text = "Finish within 60 minutes", seconds = 3600},
			{id = "time", text = "Finish within 40 minutes", seconds = 2400},
			{id = "no_deaths", text = "Nobody in the party falls"},
			{id = "no_wipes", text = "Never lose the whole party"},
		],
		steps = [
			{id = "gate", kind = "enter", world = "campaign", text = "Step through the Chronicle Gate south of the fountain and go into the Deep Dark"},
			{id = "wick", kind = "talk", npc = "wick", world = "campaign", gather = true, text = "Find Old Wick the lamplighter at the edge of the dark",
				say = "Shh. Keep your voices down. In here, they [b]listen[/b].|Before the throne will open, the stones must hear you. Four of them, out in the black. Put your ear to each.|Whatever they say... don't answer. And if you hear breathing behind you, don't turn around."},
			{id = "stones", kind = "interact", world = "campaign", text = "Listen at the whispering stones in the dark (%d/%d)", verb = "Listen",
				objects = [
					{id = "stone_1", look = "stone", name = "Whispering stone", at = {stronghold = "The Deep Dark", offset = Vector3(-60, 0, 30)},
						found = "A voice, very close: [enemy]\"We know your name now.\"[/enemy]"},
					{id = "stone_2", look = "stone", name = "Whispering stone", at = {stronghold = "The Deep Dark", offset = Vector3(62, 0, 36)},
						found = "Something breathes behind you. [enemy]Don't turn around.[/enemy]"},
					{id = "stone_3", look = "stone", name = "Whispering stone", at = {stronghold = "The Deep Dark", offset = Vector3(-40, 0, 104)},
						found = "The stone is warm. As if someone was just sitting against it."},
					{id = "stone_4", look = "stone", name = "Whispering stone", at = {stronghold = "The Deep Dark", offset = Vector3(46, 0, 110)},
						found = "Silence. Then, from every direction at once: [enemy]\"Found you.\"[/enemy]"},
				]},
			{id = "ambush", kind = "kill", world = "campaign", text = "Survive the things that followed you (%d/%d)", count = 6,
				enemies = [], any = true, pack = "dark_stalkers", gather = true, gather_range = 40.0, at = {stronghold = "The Deep Dark", offset = Vector3(0, 0, 80)}},
			{id = "wick_again", kind = "talk", npc = "wick", world = "campaign", shared = true, text = "Get back to Old Wick",
				say = "They followed you. They always do.|The stones are satisfied. The throne's key lies in a chest by its gate, and the [enemy]Hollow Crown[/enemy] holds the last piece.|I'll keep the lamps lit for you. As long as I can."},
			{id = "key", kind = "chest", world = "campaign", text = "Take the Hollow Throne's key from the chest by its gate",
				at = {stronghold = "The Deep Dark", offset = Vector3(0, 0, -46)}, items = ["key_hollow_throne", "story_candle"], until = "key_hollow_throne",
				guards = {pack = "hollow_ambush", count = 2}},
			{id = "crown", kind = "kill", world = "campaign", text = "Open the Hollow Throne and defeat the Hollow Crown", count = 1,
				enemies = ["hollow_crown"], gather = true, gather_range = 45.0, at = {stronghold = "The Deep Dark"}},
			{id = "piece", kind = "chest", world = "campaign", text = "Take the last piece of the map", at = "death",
				items = ["story_clue"], until = "story_clue"},
			{id = "wick_map", kind = "talk", npc = "wick", world = "campaign", shared = true, text = "Show Old Wick the whole map",
				say = "All six. Let me see it, let me...|No. [b]No.[/b] Put it away. Don't read it here.|Take it to the middle of the realm, to [place]Hearthwick[/place]. Someone there has been waiting for it. I think he always has."},
			{id = "stranger", kind = "talk", npc = "stranger", world = "campaign", shared = true, final = true, cutscene = "hollow_castle",
				text = "Find the stranger waiting in Hearthwick",
				say = "There you are. All six pieces. I knew you'd bring them.|I've waited such a long time.|Let me show you what it says."},
		],
		side = [],
	},
	hollow_castle = {
		id = "hollow_castle", pack = "hidden_power", requires = "hollow_hour", title = "The Hollow Castle", level = 30,
		hidden = true, pack_end = true, xp = 8000,
		blurb = "The map led you here. The castle has been waiting, and so has its king.",
		stars = [
			{id = "complete", text = "End the Hollow King"},
			{id = "time", text = "Finish within 50 minutes", seconds = 3000},
			{id = "time", text = "Finish within 30 minutes", seconds = 1800},
			{id = "no_deaths", text = "Nobody in the party falls"},
			{id = "no_wipes", text = "Never lose the whole party"},
		],
		steps = [
			{id = "gate", kind = "enter", world = "campaign", text = "Step through the Chronicle Gate south of the fountain and go to Hearthwick, the heart of the realm"},
			{id = "aurelian", kind = "talk", npc = "aurelian", world = "campaign", shared = true, gather = true,
				text = "Find Aurelian the Old Wizard in Hearthwick",
				say = "So the Stranger showed you. I felt it, the moment the sixth piece touched the map.|He is no stranger. He is the [enemy]Hollow King[/enemy], and he has been feeding on this realm for a thousand years.|I am old, but I can still open one door. Step through it, end him, and bring me his [b]heart[/b]. It must not keep beating."},
			{id = "castle", kind = "enter", world = "castle", text = "Step through Aurelian's white portal into the Hollow Castle"},
			{id = "knights", kind = "kill", world = "castle", text = "Defeat the knight guardians behind the iron gate (%d/%d)", count = 2,
				enemies = ["castle_knight"]},
			{id = "champions", kind = "kill", world = "castle", text = "Defeat the champions from the walls (%d/%d)", count = 2,
				enemies = ["castle_champion"]},
			{id = "king", kind = "kill", world = "castle", text = "Take the Throne Key to the throne room door, and defeat the Hollow King", count = 1,
				enemies = ["hollow_king"]},
			{id = "heart", kind = "chest", world = "castle", text = "Take the Heart of Stone", at = "death",
				items = ["story_heart_of_stone"], until = "story_heart_of_stone"},
			{id = "deliver", kind = "hand_over", npc = "aurelian", world = "campaign", item = "story_heart_of_stone", shared = true,
				final = true, cutscene = "towns", text = "Bring the Heart of Stone back to Aurelian in Hearthwick",
				lack = "The heart. Whoever carries his heart, bring it to me. Quickly.",
				say = "It's still warm. Give it here.|There. Stone, all the way through now. He's gone.|Listen... do you hear that? The whole realm is breathing again."},
		],
		side = [],
	},
}


## The towns cheer (the end of The Hidden Power): one slow shot over each.
const _TOWNS := {
	title = "The Realm Breathes", anywhere = true, fireworks = true,
	shots = [
		{village = "Hearthwick", duration = 6.5, cards = [{text = "The Hollow King is gone.", at = 0.6, hold = 3.0}]},
		{village = "Bramblebrook", duration = 6.0, cards = [{text = "In [place]Bramblebrook[/place], Gerald's moon-lilies bloom again.", at = 0.5, hold = 3.2}]},
		{village = "Snowbell", duration = 6.0, cards = [{text = "In [place]Snowbell[/place], the bells ring all night.", at = 0.5, hold = 3.2}]},
		{village = "Sunveil", duration = 6.5, cards = [{text = "And in [place]Sunveil[/place], nobody whispers anymore.", at = 0.5, hold = 3.0},
			{text = "The realm remembers who saved it.", at = 3.8, hold = 2.4}]},
	],
}

## Cutscenes a step can play when it ends (CampaignCinematic scripts). stage: a
## scene loaded far below the world just for the shots; shots name its markers.
const CUTSCENES := {
	towns = _TOWNS,
	hollow_castle = {
		title = "The Sixth Piece", anywhere = true, show_map = true,
		loading = {title = "The Sixth Piece", subtitle = "Read aloud, by the Stranger", seconds = 3.5},
		stage = "res://scenes/castle/hollow_castle.tscn", stage_offset = Vector3(0, -600, 0),
		shots = [
			{from_marker = "ShotBridgeFrom", to_marker = "ShotBridgeTo", look_marker = "ShotBridgeLook", duration = 9.0,
				cards = [{text = "[i]Whoever gathers these six pieces has done exactly what I wanted.[/i]", at = 0.8, hold = 3.6},
					{text = "[i]The power was never hidden. It was [enemy]waiting[/enemy]. For a bearer.[/i]", at = 4.8, hold = 3.6}]},
			{from_marker = "ShotHallFrom", to_marker = "ShotHallTo", look_marker = "ShotHallLook", duration = 9.0,
				cards = [{text = "[i]Every step you took, you carried me with you. Lily by lily. Bell by bell.[/i]", at = 0.6, hold = 3.8},
					{text = "[i]Come to my castle. Bring the map. [b]Bring your friends.[/b][/i]", at = 4.8, hold = 3.6}]},
			{from_marker = "ShotThroneFrom", to_marker = "ShotThroneTo", look_marker = "ShotThroneLook", duration = 10.0,
				cards = [{text = "[i]The throne has been cold for a thousand years.[/i]", at = 0.8, hold = 3.2},
					{text = "[enemy][b]I am so very hungry.[/b][/enemy]", at = 4.6, hold = 4.4}]},
		],
	},
}


static func get_def(id: String) -> Dictionary:
	return LIST.get(id, {})


static func step_def(id: String, index: int, side := false) -> Dictionary:
	var steps: Array = get_def(id).get("side" if side else "steps", [])
	return steps[index] if index >= 0 and index < steps.size() else {}


static func step_index(id: String, step_id: String) -> int:
	var steps: Array = get_def(id).get("steps", [])
	for i in steps.size():
		if steps[i].id == step_id:
			return i
	return -1


## The world a campaign is told in: its pack's, or its own.
static func world_key(campaign_id: String) -> String:
	return str(get_def(campaign_id).get("pack", campaign_id))


## The campaign realm's id for an account's world of a campaign (or pack).
static func realm_id(account_id: int, campaign_id: String) -> String:
	return "camp_%d_%s" % [account_id, world_key(campaign_id)]


## The world's private Tavern.
static func tavern_id(account_id: int, campaign_id: String) -> String:
	return "ctav_%d_%s" % [account_id, world_key(campaign_id)]


## The party's private Hollow Castle (the pack's final world).
static func castle_id(account_id: int, campaign_id: String) -> String:
	return "cst_%d_%s" % [account_id, world_key(campaign_id)]


static func is_castle(realm: String) -> bool:
	return realm.begins_with("cst_")


static func is_campaign_realm(realm: String) -> bool:
	return realm.begins_with("camp_")


## The public Tavern, or a campaign's own.
static func is_tavern(place: String) -> bool:
	return place == "hall" or place.begins_with("ctav_")


## Can an account (its book) begin this campaign?
static func unlocked(id: String, book: Dictionary) -> bool:
	var def := get_def(id)
	if def.is_empty() or def.get("coming_soon", false):
		return false
	var needs := str(def.get("requires", ""))
	return needs == "" or str(book.get("runs", {}).get(needs, {}).get("status", "")) == "done" \
			or int(book.get("runs", {}).get(needs, {}).get("stars_best", 0)) > 0


## Where an anchor lands in `world`: {village, offset}, {cabin: village}
## (a flat spot at the foot of the mountain nearest it), {summit: village}
## (that mountain's top), {stronghold: biome name}, or a fixed Vector3
## (the Tavern). The nearest open, walkable spot; INF if unknown.
static func resolve(at: Variant, world: GameWorld) -> Vector3:
	if at is Vector3:
		return open_spot(at, world) if world is IslandWorld else at
	if not at is Dictionary or not world is IslandWorld:
		return Vector3.INF
	var island := world as IslandWorld
	var want := Vector3.INF
	if at.has("village"):
		for v in island.generator.villages:
			if v.display_name == str(at.village):
				want = Vector3(v.center.x, 0, v.center.y)
	elif at.has("cabin") or at.has("summit"):
		var spots := _mountain(island, str(at.get("cabin", at.get("summit", ""))))
		want = spots[0] if at.has("cabin") else spots[1]

	elif at.has("stronghold"):
		for fort in island.generator.strongholds:
			if Biomes.get_biome(fort.biome_id).biome_name.to_lower() == str(at.stronghold).to_lower():
				want = Vector3(fort.center.x, 0, fort.center.y)

	if want == Vector3.INF:
		return Vector3.INF
	want += at.get("offset", Vector3.ZERO)
	return open_spot(want, island)


## Resolve against terrain and planned colliders, before streaming is available.
## Never silently return an obstructed anchor when the local search runs out.
static func open_spot(want: Vector3, world: GameWorld, radius := 0.6, height := 4.0) -> Vector3:
	if want == Vector3.INF: return want
	if not world is IslandWorld:
		for ring in 25:
			for k in maxi(1, ring * 6):
				var angle := TAU * k / maxi(1, ring * 6)
				var p := want + Vector3(cos(angle), 0, sin(angle)) * ring
				p.y = world.ground_height(p.x, p.z)
				if world.is_walkable(p) and not world.is_hazard(p): return p
		return Vector3.INF
	var island := world as IslandWorld
	for ring in 65:
		for k in maxi(1, ring * 6):
			var a := TAU * k / maxi(1, ring * 6)
			var p := want + Vector3(cos(a), 0, sin(a)) * ring * 1.5
			p.y = island.ground_height(p.x, p.z)
			if spawn_clear(p, island, radius, height): return p
	push_error("No clear campaign spawn near %s" % want)
	return Vector3.INF


static var _spawn_obstacles := {}

static func spawn_clear(p: Vector3, island: IslandWorld, radius := 0.6, height := 4.0) -> bool:
	if not p.is_finite() or not island.is_walkable(p) or island.is_hazard(p): return false
	if p.y < IslandGenerator.SEA_LEVEL + 1.0: return false
	if not island.generator.enemy_spawn_clear(p, radius, height): return false
	if radius > 3.0:
		for offset in [Vector2(-radius, -radius), Vector2(radius, -radius), Vector2(-radius, radius), Vector2(radius, radius)]:
			if absf(island.ground_height(p.x + offset.x, p.z + offset.y) - p.y) > 0.5: return false
	# Town houses/props and seeded obstacles have separate, streamed colliders.
	var boxes: Array[AABB] = []
	for village in island.generator.villages:
		for building: Dictionary in village.houses + village.props:
			var factor: float = building.get("scale", 1.0)
			var size: Vector3 = building.solid_size * factor
			var offset: Vector3 = building.get("solid_offset", Vector3.ZERO) * factor
			var yaw: float = building.get("yaw", -float(building.get("turn", 0)) * PI * 0.5)
			var center: Vector3 = building.pos + offset.rotated(Vector3.UP, yaw)
			var half := Vector3(absf(cos(yaw)) * size.x + absf(sin(yaw)) * size.z, size.y,
				absf(sin(yaw)) * size.x + absf(cos(yaw)) * size.z) * 0.5
			boxes.append(AABB(center - half, half * 2.0))
	var chunk := Vector2i(floori(p.x / 32), floori(p.z / 32))
	var key := "%d/%s" % [island.get_instance_id(), chunk]
	if not _spawn_obstacles.has(key):
		_spawn_obstacles[key] = island.generator.obstacle_sites(Rect2i(chunk * 32 - Vector2i(8, 8), Vector2i(48, 48)), island._keep_clear, island.KEEP_CLEAR_RADIUS)
	for obstacle: Dictionary in _spawn_obstacles[key]:
		var prefab := ObstacleLibrary.get_prefab(obstacle.prefab)
		for bounds: AABB in prefab.collision_boxes:
			boxes.append(Transform3D(Basis(Vector3.UP, float(obstacle.yaw)), obstacle.pos) * bounds)
	var body := AABB(p + Vector3(-radius, 0.1, -radius), Vector3(radius * 2, height, radius * 2))
	for box in boxes:
		if body.intersects(box): return false
	return true


static var _mountains := {}  # "world id/village" -> [cabin spot, summit]


## The highest ground within reach of a village, and a flat spot at its foot
## (on the village's side). Same on every machine: a fixed grid scan.
static func _mountain(island: IslandWorld, village: String) -> Array:
	var key := "%d/%s" % [island.get_instance_id(), village]
	if _mountains.has(key):
		return _mountains[key]
	var home := Vector3.INF
	for v in island.generator.villages:
		if v.display_name == village:
			home = Vector3(v.center.x, 0, v.center.y)
	if home == Vector3.INF:
		return [Vector3.INF, Vector3.INF]
	var top := home
	var best := -INF
	for z in range(-120, 121, 4):
		for x in range(-120, 121, 4):
			var p := home + Vector3(x, 0, z)
			var h := island.ground_height(p.x, p.z)
			if h > best and island.is_walkable(p):
				best = h
				top = Vector3(p.x, h, p.z)
	# Walk from the summit back toward the village until the ground is low and flat.
	var foot := home
	var steps := int(home.distance_to(Vector3(top.x, 0, top.z)))
	for s in range(0, steps, 2):
		var p := Vector3(top.x, 0, top.z).move_toward(home, s)
		var h := island.ground_height(p.x, p.z)
		var flat := absf(island.ground_height(p.x + 3, p.z) - h) + absf(island.ground_height(p.x, p.z + 3) - h) < 1.5
		if flat and h < best - 8.0 and island.is_walkable(p) and not island.is_road(p):
			foot = Vector3(p.x, h, p.z)
			break
	_mountains[key] = [foot, top]
	return _mountains[key]


## Where an npc stands in the place `realm` (its world, when it has one),
## or INF when it isn't there.
static func npc_position(npc: String, realm: String, world: GameWorld) -> Vector3:
	var info: Dictionary = NPCS.get(npc, {})
	if info.is_empty() or (info.world == "hall") != is_tavern(realm):
		return Vector3.INF
	return info.pos if info.has("pos") else resolve(info.at, world)


## A step's objective as the banner shows it ("... (2/3)").
static func objective_text(step: Dictionary, count: int) -> String:
	var text := str(step.get("text", ""))
	if not text.contains("%d"):
		return text
	var needed: int = int(step.count) if step.has("count") else step.get("objects", []).size()
	return text % [count, needed]


## Stars earned by a finished run: [bool x 5].
static func stars_for(id: String, state: Dictionary) -> Array:
	var out := []
	for star: Dictionary in get_def(id).get("stars", []):
		match str(star.id):
			"complete": out.append(true)
			"time": out.append(float(state.get("elapsed", 0.0)) <= float(star.seconds))
			"no_deaths": out.append(int(state.get("deaths", 0)) == 0)
			"no_wipes": out.append(int(state.get("wipes", 0)) == 0)
			"side": out.append(bool(state.get("side_done", false)))
			_: out.append(false)
	return out
