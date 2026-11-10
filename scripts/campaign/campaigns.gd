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
	astral_frontier = {id="astral_frontier",title="The Astral Frontier",
		blurb="A woodland mechanic builds a way to the stars. Beyond the Aurora waits a universe coming apart.",
		campaigns=["theory_of_everything","first_light","lantern_road","shardfield","hollowmoon","pale_eye"]},
	hidden_power = {
		id = "hidden_power", title = "The Hidden Power",
		blurb = "Torn pieces of an old map, a power hidden in the mountains, and a Tavern gardener who only wanted his lilies back.",
		campaigns = ["lily_thief", "frozen_whisper", "sunken_court", "ember_oath", "drowned_choir", "hollow_hour", "hollow_castle"],
	},
}

## The people of the stories. world: "hall" (the party's Tavern) or
## "campaign" (its realm). campaign + from: only there during that campaign,
## from that step on (someone you only find by asking around...).
const NPCS := {
	# The Astral Reach (SpaceWorld): at = {nexus = station anchor} or {planet, spot}.
	isolde = {name = "Captain Isolde", world = "astral", at = {nexus = "npc_captain"}, model = "npc_traveler",
		greeting = "Charts, tea and trouble. The Reach has plenty of all three."},
	bell = {name = "Quartermaster Bell", world = "astral", at = {nexus = "npc_quartermaster"}, model = "npc_baker",
		greeting = "Every ship leaves my berths with full lanterns and an empty biscuit tin. Somehow."},
	orin_nexus = {name = "Orin the Starwright", world = "astral", at = {nexus = "npc_mechanic"}, model = "npc_smith",
		greeting = "The shuttle's warm if you miss the Surface. It lands by Hearthwick's launch pad."},
	moss = {name = "Elder Moss", world = "astral", at = {planet = "verdance", spot = "treehouse_village"}, model = "npc_gardener",
		greeting = "Mind the glowcaps. They sulk when you step on them."},
	lys = {name = "Keeper Lys", world = "astral", at = {planet = "rosamund", spot = "petal_shrine"}, model = "npc_magician",
		greeting = "The shrines sing when the crystals are happy. They have not sung in weeks."},
	tam = {name = "Tam of the Lighthouse", world = "astral", at = {planet = "tidewell", spot = "lighthouse"}, model = "npc_villager",
		greeting = "Lamp's lit. Always lit. Somebody out there needs to see it."},
	hermit = {name = "The Hollow Hermit", world = "astral", at = {planet = "hollowmoon", spot = "observatory_ruin"}, model = "npc_traveler",
		greeting = "You came through the Shardfield. Brave, or lost. Usually both."},
	petalgate_warden = {name = "Warden Elowen", world = "astral", at = {planet = "rosamund", town = "center"}, model = "npc_magician",
		greeting = "Petalgate keeps her gates open for friends, though the Bastion does not."},
	vesperis_wizard = {name = "Wizard Aldren", world = "astral", at = {planet = "vesperis", city_venue = "wizard"}, model = "npc_magician",
		greeting = "Wands, charms, enchanted trinkets - and the best pubs in the Reach!"},
	verdance_starwright = {name = "Starwright Fen", world = "astral", at = {planet = "verdance", town = "wright"}, model = "npc_smith",
		greeting = "The starship will not fly until I find those three missing parts."},
	vesperis_partsmith = {name = "Scrapper Nix", world = "astral", at = {planet = "vesperis", city_venue = "parts"}, model = "npc_traveler",
		greeting = "Ship parts, fresh from the salvage yard. Navigation core: 500 Dots."},
	amberfall_warden = {name = "Warden Saffron", world = "astral", at = {planet = "amberfall", town = "center"}, model = "npc_traveler",
		greeting = "The Amber Ziggurat has been quiet. Far too quiet."},
	tidewell_fisher = {name = "Fisher Mira", world = "astral", at = {planet = "tidewell", town = "center"}, model = "npc_villager",
		greeting = "The tides brought in something stranger than fish."},
	tidewell_keeper = {name = "Keeper Brine", world = "astral", at = {planet = "tidewell", spot = "lighthouse"}, model = "npc_traveler",
		greeting = "The lighthouse sees everything the tides are trying to hide."},
	astral_mechanic = {name="Orin the Starwright",world="campaign",campaign="theory_of_everything",
		at={astral="mechanic"},model="npc_smith",
		greeting="Welcome to Starfall Launchworks. The Starling runs on aether, copper, and a very unreasonable amount of hope."},
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
	loading = {title = "The Lily Thief", subtitle = "The Hidden Power  -  part one", seconds = 3.0},
	shots = [
		{from = Vector3(46, 32, 96), to = Vector3(26, 22, 74), look_from = Vector3(0, 10, 40), look_to = Vector3(0, 10, 46), duration = 7.5,
			cards = [{text = "[place]The Tavern[/place] sleeps.", at = 0.8, hold = 2.6},
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
	# The Astral Reach tales, told by ReachCampaign. Extra step kinds:
	# | kind | done when | fields |
	# |---|---|---|
	# | reach_ship | a party member is aboard a party ship | |
	# | reach_fly | a party ship comes within `range` of `target` | target ("planet:<id>", "pass:<n>", "nexus", "point") , range, at |
	# | reach_land | a party ship lands on `planet` | planet |
	# | reach_dock | a party ship docks at the Nexus | |
	# | reach_kill | party cannons destroy `count` brood (`foe` kind or any); `ambush` spawns them near `target` | count, foe, target, ambush |
	# | reach_repair | the party ship is crippled until every `objects` spot aboard is mended | objects [{id, name, seat}] |
	# | reach_search | searching each object at a planet spot | planet, objects [{id, name, spot, found}] |
	# Space Travels additionally uses reach_order, reach_tutorial_fly, reach_tutorial_ambush,
	# reach_tutorial_repair, reach_port, reach_boss and reach_party_nexus.
	# talk steps with world "astral" use the Reach NPCS.

	# Mission 2 retains the original id to preserve existing saves and unlocks.
	first_light = {
		id = "first_light", revision = 2, pack = "astral_frontier", requires = "theory_of_everything", reach = true,
		title = "Space Travels", level = 40, xp = 6000,
		blurb = "Learn to command a battleship, survive a skiff ambush, mend your hull, explore Petalgate and open the Rose Bastion.",
		stars = [{id = "complete", text = "Finish the voyage"}, {id = "time", text = "Finish within 40 minutes", seconds = 2400},
			{id = "no_deaths", text = "Nobody falls"}],
		steps = [
			{id = "order", kind = "reach_order", world = "astral",
				text = "Use Bell's shipwright at the Nexus to deploy a ship for your party"},
			{id = "board", kind = "reach_ship", world = "astral",
				text = "Board the ship at its Nexus berth (the command table can find your ship)"},
			{id = "travel", kind = "reach_tutorial_fly", world = "astral", planet = "rosamund",
				text = "Take the helm and fly towards Rosamund, the rose-coloured planet"},
			{id = "ambush", kind = "reach_tutorial_ambush", world = "astral",
				text = "Enemy ship astern! Take the helm or a cannon and shoot down the pursuing skiff"},
			{id = "repairs", kind = "reach_tutorial_repair", world = "astral", count = 4,
				text = "Mend the four broken ship parts: sails, engines, top cannon and heart crystal (%d/%d)"},
			{id = "port", kind = "reach_port", world = "astral", planet = "rosamund", port = "rosamund:dock",
				text = "Pilot to Rosamund and land at Petalgate's SHIPYARD port (X to land)"},
			{id = "warden", kind = "talk", world = "astral", npc = "petalgate_warden", shared = true,
				grant_key = "key_rose_bastion", text = "Explore Petalgate and meet its warden in the town square",
				say = "Welcome to [place]Petalgate[/place], travellers! I saw your wounded ship land. We could use people as brave as you.|Our [place]Rose Bastion[/place] lies south of the city. Its gates have sealed themselves around [enemy]Queen Briarrose[/enemy].|Take this [b]Rose Bastion key[/b]. Use it on the fortress gate, then face the Queen together. If you lose your way, look for the great pink towers beyond town."},
			{id = "boss", kind = "reach_boss", world = "astral", planet = "rosamund", boss = "queen_briarrose",
				text = "Unlock the Rose Bastion and defeat Queen Briarrose"},
			{id = "return", kind = "reach_dock", world = "astral",
				text = "Return to your ship (or deploy another at a shipwright), fly home and dock at the Nexus"},
			{id = "assemble", kind = "reach_party_nexus", world = "astral", final = true,
				text = "Disembark at the Nexus and wait until every party member is safely on the station"},
		],
	},
	# Mission 3 retains its original id to preserve completed runs and the
	# prerequisite for Through the Shardfield.
	lantern_road = {
		id = "lantern_road", revision = 2, pack = "astral_frontier", requires = "first_light", reach = true,
		title = "Vesperis", level = 42, xp = 7000,
		blurb = "Visit the wizard of Lanternheart, share two beers each at a proper city pub, and recover his stolen starball from a shotgun-wielding farmer.",
		stars = [{id = "complete", text = "Recover the stolen starball"}, {id = "time", text = "Finish within 40 minutes", seconds = 2400},
			{id = "no_deaths", text = "Nobody falls"}],
		steps = [
			{id = "arrival", kind = "reach_vesperis_port", world = "astral",
				text = "Fly to Vesperis and land at Lanternheart Spaceport"},
			{id = "wizard", kind = "talk", world = "astral", npc = "vesperis_wizard", shared = true,
				text = "Find the wizard waiting outside his magic shop in Lanternheart",
				say = "Ah, travellers! Welcome to [place]The Wizard[/place]. Step inside if you fancy a wand, a charm, or something magical that hasn't exploded yet.|I would offer you a tour, but a rather unpleasant fellow stole my [b]starball[/b]. It is a magical sphere that keeps my finest enchantments steady.|We'll deal with that soon enough. First you simply MUST visit one of the [place]Lanternheart pubs[/place]. The beer here is outstanding! Each of you should enjoy two proper mugs. Then come to think of it, I know where our thief is hiding."},
			{id = "beers", kind = "reach_vesperis_beers", world = "astral",
				text = "Visit a Lanternheart pub, order beer at the bar, and drink two FULL mugs each (four sips per mug)"},
			{id = "farmer", kind = "reach_vesperis_boss", world = "astral", boss = "mad_farmer", farm = 0,
				text = "Follow the country road to a nearby farm and defeat the shotgun-wielding Mad Farmer"},
			{id = "starball", kind = "reach_vesperis_ball", world = "astral", item = "story_wizard_starball",
				text = "Open the Story Chest at the farm and recover the stolen magical starball"},
			{id = "return", kind = "talk", world = "astral", npc = "vesperis_wizard", shared = true,
				return_item = "story_wizard_starball",
				text = "Bring the magical starball back to the wizard outside his shop",
				say = "You found it! By the wandering stars, you've even brought back the whole thing.|The farmer was convinced this ball would make his turnips fly. Sadly, the only thing he learned to fly was buckshot.|Thank you, every one of you. A proper wizard always pays his debts: I've prepared a [b]Tier 5 wand[/b] for each of you. Look for your own [b]Blue Chest[/b] here outside the shop."},
			{id = "wands", kind = "reach_vesperis_wands", world = "astral", final = true,
				text = "Each party member must open their own Blue Chest outside the shop and take their Tier 5 wand"},
		],
	},
	# Mission 4 keeps the legacy id for existing saves and the next unlock.
	shardfield = {
		id = "shardfield", revision = 2, pack = "astral_frontier", requires = "lantern_road", reach = true,
		title = "The Starwright's Missing Parts", level = 44, xp = 8000,
		blurb = "Three planets, three missing ship components, and an amber giant between you and a working star engine.",
		stars = [{id = "complete", text = "Return all three ship parts"}, {id = "time", text = "Finish within 50 minutes", seconds = 3000},
			{id = "no_deaths", text = "Nobody falls"}],
		steps = [
			{id = "commission", kind = "talk", world = "astral", npc = "verdance_starwright", shared = true,
				text = "Meet Starwright Fen at the shipwright's yard in Mossbrook on Verdance",
				say = "Finally, a crew that knows one end of a battleship from the other! I'm Fen. I'm rebuilding a starship here in [place]Mossbrook[/place].|Three pieces have gone missing: a [b]navigation core[/b] sold by a parts shop in [place]Vesperis[/place], an [b]amber power regulator[/b] sealed in Aurum's fortress on [place]Amberfall[/place], and a [b]tidal stabilizer[/b] somewhere on [place]Tidewell[/place].|The core will cost [b]500 Dots[/b]. Honeymarket's warden keeps the Amber Ziggurat key. On Tidewell, ask the locals: they'll know where the last part washed up.|Let me show you the three worlds on your star chart. When all three parts are in your hands, bring them here and I'll fit the new drive.",
				cutscene = "starwright_three_worlds"},
			{id = "buy_core", kind = "reach_buy_part", world = "astral", npc = "vesperis_partsmith", item = "story_nav_core", price = 500,
				text = "Buy the ship's Navigation Core from the parts merchant in Lanternheart, Vesperis (500 Dots)"},
			{id = "amber_key", kind = "talk", world = "astral", npc = "amberfall_warden", shared = true,
				grant_key = "key_amber_ziggurat",
				text = "Find the warden in Honeymarket on Amberfall and ask for the Amber Ziggurat key",
				say = "You're after the [b]amber power regulator[/b]? Aurum took it into the [place]Amber Ziggurat[/place].|The gates will not open without this amber key. Take it, but tread carefully - [enemy]Aurum, the Amber Colossus[/enemy], does not care for visitors.|Follow the terraces south of town. The golden towers are impossible to miss."},
			{id = "aurum", kind = "reach_boss", world = "astral", planet = "amberfall", boss = "amber_colossus",
				text = "Unlock the Amber Ziggurat and defeat Aurum, the Amber Colossus"},
			{id = "amber_regulator", kind = "reach_part_chest", world = "astral", planet = "amberfall",
				spot = "fort", item = "story_amber_regulator",
				text = "Open the Story Chest in the Amber Ziggurat to recover the amber power regulator"},
			{id = "fisher", kind = "talk", world = "astral", npc = "tidewell_fisher", shared = true,
				text = "Ask the fisherman in Saltstilts on Tidewell about the tidal stabilizer",
				say = "A brass thing shaped like a spinning shell? Yes, we found one tangled in our nets.|The lighthouse keeper came asking about it. He claimed the tides were answering its song.|Go to the [place]lighthouse[/place] and ask him before you wade through the shallows."},
			{id = "keeper", kind = "talk", world = "astral", npc = "tidewell_keeper", shared = true,
				text = "Ask the lighthouse keeper on Tidewell where the ship component was hidden",
				say = "That little machine could call a wave out of a dry dock. I hid it where the sea is quiet.|Follow the shore to the [place]Shell Shrine[/place]. Beside the old stones is a chest with the [b]tidal stabilizer[/b]. It belongs aboard a ship, not at the bottom of mine."},
			{id = "tidal_stabilizer", kind = "reach_part_chest", world = "astral", planet = "tidewell",
				spot = "shell_shrine", item = "story_tidal_stabilizer",
				text = "Find the Shell Shrine on Tidewell and take the tidal stabilizer from its Story Chest"},
			{id = "return_parts", kind = "talk", world = "astral", npc = "verdance_starwright", shared = true, final = true,
				return_items = ["story_nav_core", "story_amber_regulator", "story_tidal_stabilizer"],
				text = "Return all three ship parts to Starwright Fen in Mossbrook on Verdance",
				say = "The navigation core! Genuine city circuitry. And Aurum's amber regulator... that must have been a fearsome fight.|And the tidal stabilizer. Three planets' work, brought together by one crew. Now that's what I call a proper voyage.|You've given this old ship another chance to see the stars. Thank you, all of you. The drive is whole, and the tale is complete."},
		],
	},
	hollowmoon = {
		id = "hollowmoon", revision = 1, pack = "astral_frontier", requires = "shardfield", reach = true,
		title = "The Hollow Moon", level = 46, xp = 9000,
		blurb = "Beyond the Shardfield the Gloam swallows the stars. A hermit on a dead moon watches the brood grow.",
		stars = [{id = "complete", text = "Finish the tale"}, {id = "time", text = "Finish within 35 minutes", seconds = 2100},
			{id = "no_deaths", text = "Nobody falls"}],
		steps = [
			{id = "orin", kind = "talk", world = "astral", npc = "orin_nexus", shared = true, text = "Ask Orin to fit the ship for the Gloam",
				say = "The Gloam eats lantern light, so I gave your lanterns bigger appetites.|Through any pass, then keep going until the stars go quiet. Hollowmoon is grey. Very grey. You will know it."},
			{id = "ship", kind = "reach_ship", world = "astral", text = "Board a party ship"},
			{id = "gloam", kind = "reach_fly", world = "astral", target = "planet:hollowmoon", range = 700.0, text = "Cross the Shardfield and fly into the Gloam to Hollowmoon"},
			{id = "eels", kind = "reach_kill", world = "astral", count = 4, foe = "void_eel", target = "planet:hollowmoon", ambush = 4, text = "Drive off the void eels (%d/%d)"},
			{id = "land", kind = "reach_land", world = "astral", planet = "hollowmoon", text = "Land on Hollowmoon"},
			{id = "hermit", kind = "talk", world = "astral", npc = "hermit", shared = true, text = "Find the hermit at the ruined observatory",
				say = "Visitors. Living ones, even.|I have watched [place]Mawgrave[/place] for nine years. The brood grow there in hives the size of towns. The Empress you slew was only a daughter.|Their mother sleeps under the storm of [place]the Pale Eye[/place]. Light my three beacons and the Nexus will see what I see."},
			{id = "beacons", kind = "reach_search", world = "astral", planet = "hollowmoon", text = "Light the hermit's beacons (%d/%d)",
				objects = [{id = "b_a", name = "Cold beacon", spot = "observatory_ruin", found = "Green fire climbs the beacon."},
					{id = "b_b", name = "Cold beacon", spot = "bone_forest", found = "The bone trees glow from within."},
					{id = "b_c", name = "Cold beacon", spot = "fallen_astrolabe", found = "Far away, the Nexus flashes back."}]},
			{id = "home", kind = "reach_dock", world = "astral", text = "Return to the Nexus"},
			{id = "report", kind = "talk", world = "astral", npc = "isolde", final = true, text = "Report to Captain Isolde",
				say = "We saw the beacons. All of us. The whole station went quiet.|A mother of the brood, under the Pale Eye. Then that is where this ends."},
		],
	},
	pale_eye = {
		id = "pale_eye", revision = 1, pack = "astral_frontier", requires = "hollowmoon", reach = true,
		title = "Under the Pale Eye", level = 48, xp = 12000,
		blurb = "Burn the hives of Mawgrave and fly into the storm at the end of the map.",
		stars = [{id = "complete", text = "Finish the tale"}, {id = "time", text = "Finish within 40 minutes", seconds = 2400},
			{id = "no_deaths", text = "Nobody falls"}],
		steps = [
			{id = "captain", kind = "talk", world = "astral", npc = "isolde", shared = true, text = "Captain Isolde's last orders",
				say = "Every ship of the Nexus is with you, in spirit and in biscuits.|Burn the hives on [place]Mawgrave[/place] first, or the mother will have an army. Then the storm."},
			{id = "ship", kind = "reach_ship", world = "astral", text = "Board a party ship"},
			{id = "maw", kind = "reach_fly", world = "astral", target = "planet:mawgrave", range = 800.0, text = "Fly deep into the Gloam to Mawgrave"},
			{id = "swarm", kind = "reach_kill", world = "astral", count = 10, target = "planet:mawgrave", ambush = 10, text = "Break the swarm over Mawgrave (%d/%d)"},
			{id = "land", kind = "reach_land", world = "astral", planet = "mawgrave", text = "Land on Mawgrave"},
			{id = "hives", kind = "reach_search", world = "astral", planet = "mawgrave", text = "Set Orin's lantern charges in the hives (%d/%d)",
				objects = [{id = "h_a", name = "Brood hive", spot = "brood_hive", found = "The charge glows green and the hive shrinks back."},
					{id = "h_b", name = "Brood hive", spot = "hollow_nest", found = "Something inside screams and goes still."},
					{id = "h_c", name = "Brood hive", spot = "spore_garden", found = "The last charge catches. Mawgrave burns with green fire."}]},
			{id = "eye", kind = "reach_fly", world = "astral", target = "planet:pale_eye", range = 900.0, text = "Fly into the storm of the Pale Eye"},
			{id = "mother", kind = "reach_kill", world = "astral", count = 12, target = "planet:pale_eye", ambush = 12,
				text = "Destroy the Mother's last brood under the Eye (%d/%d)"},
			{id = "home", kind = "reach_dock", world = "astral", text = "Come home to the Nexus"},
			{id = "report", kind = "talk", world = "astral", npc = "isolde", final = true, shared = true, text = "Come home to Captain Isolde",
				say = "The storm is breaking up. We can see stars behind the Eye for the first time in nine years.|You crossed a theory, a field of shards and the dark itself. The Nexus is yours, for as long as you like.|...Tea?"},
		],
	},
	theory_of_everything = {
		id="theory_of_everything",revision=1,pack="astral_frontier",title="Theory of Everything",level=40,
		blurb="Help a woodland starwright finish his impossible ship. Board together, cross the chromatic void and restore a haunted vessel on the way to the Convergence.",
		xp=8000,stars=[],side=[],
		steps=[
			{id="realm",kind="enter",world="campaign",text="Return to the Surface through the Chronicle Gate"},
			{id="mechanic",kind="talk",world="campaign",npc="astral_mechanic",shared=true,
				text="Find Orin at Starfall Launchworks in the woods",
				say="You found my little clearing! [place]Starfall Launchworks[/place], first port to a very unreasonable sky.|My ship needs a [b]starcoil[/b], a [b]spellsteel nozzle[/b] and an [b]aether heart[/b]. My supply chest is beside the workshop. Bring all three to me.|Once she is ready, every member of your party must board. Nobody gets left in the trees."},
			{id="parts",kind="astral_parts",world="campaign",npc="astral_mechanic",count=3,
				text="Take the three rocket parts from the supply chest and bring them to Orin (%d/%d)",
				say="Perfect. The starcoil holds, the nozzle is seated, and the heart is singing.|She is ready. Go to the boarding hatch. I'll keep the engines warm until [b]everyone[/b] is aboard."},
			{id="board",kind="astral_board",world="campaign",text="Board the magic rocket and wait for your party"},
			{id="relays",kind="astral_route",world="dungeon",text="Inspect the Aurora's marked electrical boxes to find the airlock relay"},
			{id="expanse",kind="astral_route",world="dungeon",text="Leave the Aurora and cross the Chromatic Expanse to the derelict ship"},
			{id="repairs",kind="astral_route",world="dungeon",count=5,text="Repair all five marked service bays in the derelict ship (%d/%d)"},
			{id="unravelling",kind="astral_route",world="dungeon",text="Leave through the restored airlock and cross the Unravelling"},
			{id="convergence",kind="astral_route",world="dungeon",text="Defeat the Hollow Empress at the Convergence"},
			{id="beyond",kind="astral_route",world="dungeon",final=true,text="Step through the star portal to the Nexus"},
			{id="relaunch",kind="talk",world="campaign",npc="astral_mechanic",shared=true,next="board",
				text="Return to Orin at Starfall Launchworks and arrange another flight",
				say="Your parts are still installed. I've brought the ship home and kept your route on the star chart.|Board together when you are ready. We'll return to the Aurora; every circuit you repaired is still saved."},
		],
	},
	lily_thief = {
		id = "lily_thief", revision = 2, pack = "hidden_power", title = "The Lily Thief", level = 1,
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
			{id = "gate", kind = "enter", world = "campaign", text = "Step through the Chronicle Gate south of the fountain"},
			{id = "trail", kind = "interact", world = "campaign", text = "Follow the stolen lilies through the eastern meadow (%d/%d)", verb = "Examine",
				objects = [
					{id = "lily_tracks", name = "Dragged lily stems", at = Vector3(150, 0, 45), found = "Chewed stems lead farther into the meadow."},
					{id = "lily_petals", name = "Scattered moon-lily petals", at = Vector3(205, 0, 110), found = "The petals end at a clearing. Something huge is feeding here."},
				]},
			{id = "bloom", kind = "kill", world = "campaign", text = "Find what eats the lilies in the meadow beyond Bramblebrook", count = 1,
				enemies = ["thornmaw_bloom"], pack = "thornmaw", gather = true, at = Vector3(250, 0, 155)},
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
				say = "That mark... I've seen it before, on my grandmother's [b]necklace[/b].|A [enemy]goblin[/enemy] snatched it from my window last night! Its master camps across the forest, southwest of the city.|Bring it back, and I'll tell you everything I know."},
			{id = "thief", kind = "kill", world = "campaign", text = "Defeat the Goblin Master's pack across the forest (%d/%d)", count = 6,
				enemies = ["goblin_master", "goblin_thief", "goblin"], pack = "story_goblin", gather = true, at = Vector3(-225, 0, 115),
				formation = {members = [{enemy = "goblin", min = 4, max = 4}, {enemy = "goblin_thief", min = 1, max = 1}],
					leader = {enemy = "goblin_master", min_members = 0}, respawn_time = -1.0, activate_radius = 40.0}},
			{id = "cave", kind = "dungeon", world = "campaign", dungeon = "goblins_cave", at = "death",
				text = "The pack guarded a cave. Follow it down and defeat the Goblin King"},
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
					{id = "brazier_1", name = "Cold oath-brazier", at = {stronghold = "Doom", offset = Vector3(-90, 0, 85)}, found = "The first brazier roars back to life."},
					{id = "brazier_2", name = "Cold oath-brazier", at = {stronghold = "Doom", offset = Vector3(95, 0, 95)}, found = "The second brazier flares."},
					{id = "brazier_3", name = "Cold oath-brazier", at = {stronghold = "Doom", offset = Vector3(5, 0, 165)}, found = "The third brazier burns, and the air goes still."},
				]},
			{id = "cult", kind = "kill", world = "campaign", text = "The cultists come back for their braziers: defeat them (%d/%d)", count = 6,
				enemies = ["ember_mite", "cinder_beetle"], pack = "ash_cult", gather = true, at = {stronghold = "Doom", offset = Vector3(0, 0, 180)}},
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
		id = "drowned_choir", revision = 2, pack = "hidden_power", requires = "ember_oath", title = "The Drowned Choir", level = 20,
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
				enemies = [], any = true, pack = "tide_heralds", gather = true, at = {stronghold = "Bluelay", offset = Vector3(-100, 0, 120)},
				formation = {members = [{enemy = "genie_blue", min = 2, max = 2}, {enemy = "tide_snail", min = 3, max = 3}], respawn_time = -1.0, activate_radius = 38.0}},
			{id = "grotto", kind = "dungeon", world = "campaign", dungeon = "azure_grotto", at = "death",
				text = "Dive into the Azure Grotto and silence the Abyssal Siren"},
			{id = "pearl", kind = "chest", world = "dungeon", text = "Take the Siren's pearl", at = "death",
				items = ["story_tide_pearl"], until = "story_tide_pearl"},
			{id = "seal", kind = "hand_over", npc = "mirela", world = "campaign", item = "story_tide_pearl", shared = true,
				text = "Bring the Siren's pearl to Mirela", lack = "The pearl, child. Whoever carries the pearl.",
				say = "Hold it to your ear... can you hear them? The whole choir, still singing under the sea.|The second seal: ring the three [b]drowned bells[/b] along the shore. The [enemy]Spire Keeper[/enemy] will rise to stop you. Let him."},
			{id = "bells", kind = "interact", world = "campaign", text = "Ring the drowned bells along the shore (%d/%d)", verb = "Ring",
				objects = [
					{id = "bell_1", look = "bell", name = "Drowned bell", at = {stronghold = "Bluelay", offset = Vector3(-100, 0, 65)}, found = "A low note rolls across the water."},
					{id = "bell_2", look = "bell", name = "Drowned bell", at = {stronghold = "Bluelay", offset = Vector3(105, 0, 80)}, found = "The second bell answers the first."},
					{id = "bell_3", look = "bell", name = "Drowned bell", at = {stronghold = "Bluelay", offset = Vector3(0, 0, 180)}, found = "The third bell rings... and something rings back from under the sea."},
				]},
			{id = "keeper", kind = "kill", world = "campaign", text = "Defeat the Spire Keeper", count = 1,
				enemies = ["spire_keeper"], pack = "spire_keeper", gather = true, gather_range = 30.0, at = {stronghold = "Bluelay", offset = Vector3(0, 0, 220)}},
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
		id = "hollow_hour", revision = 2, pack = "hidden_power", requires = "drowned_choir", title = "The Hollow Hour", level = 24,
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
					{id = "stone_1", look = "stone", name = "Whispering stone", at = {stronghold = "The Deep Dark", offset = Vector3(-105, 0, 65)},
						found = "A voice, very close: [enemy]\"We know your name now.\"[/enemy]"},
					{id = "stone_2", look = "stone", name = "Whispering stone", at = {stronghold = "The Deep Dark", offset = Vector3(110, 0, 70)},
						found = "Something breathes behind you. [enemy]Don't turn around.[/enemy]"},
					{id = "stone_3", look = "stone", name = "Whispering stone", at = {stronghold = "The Deep Dark", offset = Vector3(-85, 0, 160)},
						found = "The stone is warm. As if someone was just sitting against it."},
					{id = "stone_4", look = "stone", name = "Whispering stone", at = {stronghold = "The Deep Dark", offset = Vector3(90, 0, 180)},
						found = "Silence. Then, from every direction at once: [enemy]\"Found you.\"[/enemy]"},
				]},
			{id = "ambush", kind = "kill", world = "campaign", text = "Survive the things that followed you (%d/%d)", count = 6,
				enemies = [], any = true, pack = "dark_stalkers", gather = true, gather_range = 40.0, at = {stronghold = "The Deep Dark", offset = Vector3(0, 0, 175)},
				formation = {members = [{enemy = "gloam_bat", min = 3, max = 3}, {enemy = "bile_bandit", min = 3, max = 3}], respawn_time = -1.0, activate_radius = 40.0}},
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
	starwright_three_worlds = {
		title = "Three Worlds, Three Ship Parts", anywhere = true,
		loading = {title = "Three Worlds, Three Ship Parts", subtitle = "Starwright Fen's chart of the Astral Reach", seconds = 2.0},
		shots = [
			{from = SpaceLayout.planet("vesperis").center+Vector3(950, 680, 1650),
				to = SpaceLayout.planet("vesperis").center+Vector3(730, 480, 1300),
				look_from = SpaceLayout.planet("vesperis").center, look_to = SpaceLayout.planet("vesperis").center,
				duration = 8.0,
				cards = [{text = "[place]Vesperis[/place] - the Lantern City. Scrapper Nix sells a [b]Navigation Core[/b] for [b]500 Dots[/b].", at = 0.6, hold = 5.3}]},
			{from = SpaceLayout.planet("amberfall").center+Vector3(1250, 780, 1250),
				to = SpaceLayout.planet("amberfall").center+Vector3(920, 530, 1020),
				look_from = SpaceLayout.planet("amberfall").center, look_to = SpaceLayout.planet("amberfall").center,
				duration = 8.0,
				cards = [{text = "[place]Amberfall[/place] - get the key in Honeymarket, defeat [enemy]Aurum[/enemy], and take the [b]Amber Regulator[/b].", at = 0.5, hold = 5.4}]},
			{from = SpaceLayout.planet("tidewell").center+Vector3(-1350, 800, 1500),
				to = SpaceLayout.planet("tidewell").center+Vector3(-980, 580, 1180),
				look_from = SpaceLayout.planet("tidewell").center, look_to = SpaceLayout.planet("tidewell").center,
				duration = 9.0,
				cards = [{text = "[place]Tidewell[/place] - question the fishermen and lighthouse keeper, then search the Shell Shrine for the [b]Tidal Stabilizer[/b].", at = 0.5, hold = 6.0}]},
		],
	},
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
	# The open-spot search is costly and the answer never moves for a world:
	# markers, the guide and portal badges ask several times a second.
	if not is_instance_valid(world): return Vector3.INF
	var key := "%d/%s" % [world.get_instance_id(), var_to_str(at)]
	if _resolved.has(key): return _resolved[key]
	var spot := _resolve(at, world)
	if _resolved.size() > 4096: _resolved.clear()
	_resolved[key] = spot
	return spot


static var _resolved := {}  # "world id/anchor" -> spot


static func _resolve(at: Variant, world: GameWorld) -> Vector3:
	if at is Vector3:
		return open_spot(at, world) if world is IslandWorld else at
	if not at is Dictionary or not world is IslandWorld:
		return Vector3.INF
	var island := world as IslandWorld
	if at.has("astral"):
		return island.astral_anchor(str(at.astral))
	var want := Vector3.INF
	if at.has("village"):
		for v in island.generator.villages:
			if v.display_name == str(at.village):
				return _town_spot(v, at.get("offset", Vector3.ZERO), island)
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


## Keep social objectives in the town, close to their plaza/house offset.
static func _town_spot(town: VillageFeature, offset: Vector3, island: IslandWorld) -> Vector3:
	var center := Vector3(town.center.x + 0.5, 0, town.center.y + 0.5)
	var want := center + offset
	for ring in range(0, ceili(town.radius / 1.5)):
		for k in maxi(1, ring * 6):
			var angle := TAU * k / maxi(1, ring * 6)
			var point := want + Vector3(cos(angle), 0, sin(angle)) * ring * 1.5
			if Vector2(point.x - center.x, point.z - center.z).length() > town.radius - 3.0: continue
			point.y = island.ground_height(point.x, point.z)
			if spawn_clear(point, island): return point
	push_error("No clear campaign position inside " + town.display_name)
	return Vector3.INF


## Combat sites reserve enough clear space beyond every town's safe perimeter.
static func encounter_position(at: Variant, world: GameWorld) -> Vector3:
	var center := resolve(at, world)
	if not world is IslandWorld or center == Vector3.INF: return center
	var island := world as IslandWorld
	for ring in 65:
		for k in maxi(1, ring * 6):
			var angle := TAU * k / maxi(1, ring * 6)
			var point := center + Vector3(cos(angle), 0, sin(angle)) * ring * 1.5
			point.y = world.ground_height(point.x, point.z)
			var safe := true
			for village in island.generator.villages:
				if Vector2(point.x, point.z).distance_to(Vector2(village.center)) < village.radius + IslandGenerator.TOWN_PACK_MARGIN + 24.0:
					safe = false
					break
			if safe and spawn_clear(point, island): return point
	return Vector3.INF


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
	if not island.generator.enemy_spawn_clear(p, radius, height, true): return false
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
		for tree: Dictionary in village.trees:
			var prefab := ObstacleLibrary.get_prefab(tree.prefab)
			for bounds: AABB in prefab.collision_boxes:
				boxes.append(Transform3D(Basis(Vector3.UP, float(tree.yaw)), tree.pos) * bounds)
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


## Use the generator's actual mountain, regardless of the town's distance.
## Scan voxel columns so the chest sits on the highest clear summit column.
static func _mountain(island: IslandWorld, village: String) -> Array:
	var key := "%d/%s" % [island.get_instance_id(), village]
	if _mountains.has(key): return _mountains[key]
	var home := Vector2.INF
	for town in island.generator.villages:
		if town.display_name == village: home = Vector2(town.center)
	if home == Vector2.INF: return [Vector3.INF, Vector3.INF]
	var center := island.generator._mountain_center
	var radius := island.generator._mountain_radius
	var top := Vector3.INF
	var best := -INF
	var nearest := INF
	for z in range(floori(center.y - radius), ceili(center.y + radius) + 1):
		for x in range(floori(center.x - radius), ceili(center.x + radius) + 1):
			var horizontal := Vector2(x + 0.5, z + 0.5)
			var distance := horizontal.distance_squared_to(center)
			if distance > radius * radius: continue
			var h := island.ground_height(horizontal.x, horizontal.y)
			if h < best or (h == best and distance >= nearest): continue
			var point := Vector3(horizontal.x, h, horizontal.y)
			if not spawn_clear(point, island): continue
			best = h
			nearest = distance
			top = point
	# Search the lower mountain slopes toward the village for a clear, level
	# cabin footprint. Both the cabin and Halvard use this same anchor.
	var foot := Vector3.INF
	var toward := (home - center).normalized()
	for step in range(0, 25):
		var distance := radius * (0.65 + step * 0.025)
		for turn in range(0, 49):
			var angle := deg_to_rad(5.0 * ceili(turn / 2.0) * (1 if turn % 2 == 1 else -1))
			var horizontal := center + toward.rotated(angle) * distance
			var point := Vector3(floorf(horizontal.x) + 0.5, 0, floorf(horizontal.y) + 0.5)
			point.y = island.ground_height(point.x, point.z)
			if point.y >= best - 12.0 or island.is_road(point): continue
			if not spawn_clear(point, island, 3.3, 4.0): continue
			var npc := point + Vector3(3, 0, 3)
			npc.y = island.ground_height(npc.x, npc.z)
			if not spawn_clear(npc, island): continue
			foot = point
			break
		if foot != Vector3.INF: break
	if top == Vector3.INF or foot == Vector3.INF:
		push_error("Could not place mountain campaign landmarks for " + village)
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
static func objective_text(step: Dictionary, count: int, home_progress: Dictionary = {}, player_id := 0) -> String:
	if step.get("kind", "") == "set_home" and not home_progress.is_empty():
		var ready: Array = home_progress.get("ready", [])
		var total := int(home_progress.get("total", 1))
		if player_id in ready:
			return "Wait for your party to set home in %s (%d/%d ready)" % [str(step.village), ready.size(), total]
		return "%s (%d/%d ready)" % [str(step.get("text", "Set your home in " + str(step.village))), ready.size(), total]
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
