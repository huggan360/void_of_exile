extends RefCounted
## "What the Realm Remembers": the story of the realm, at the end of The Lily
## Thief. An old black-and-white reel (look.old/mono) of the kingdom, its
## King and the night something came to his throne, turning to colour when
## it reaches today. Format: scripts/cinematic/README.md.
## Shot indexes (for actors' `shots`): 0 card, 1-3 the kingdom, 4 the King,
## 5 card, 6 the shadow, 7 the Hollow King, 8-9 the curse spreads, 10 card,
## 11-13 today.
const OLD := {mono = 1.0, old = 1.0, grain = 0.6, vignette = 0.7, warmth = 0.25, contrast = 1.12}
const TODAY := {mono = 0.0, old = 0.0, grain = 0.3, vignette = 0.45, warmth = 0.15, contrast = 1.05}

const FILMS := {
	realm_history = {
		title = "What the Realm Remembers", world = "surface",
		loading = {title = "What the Realm Remembers", subtitle = "As the old reels tell it"},
		stage = "res://scenes/castle/hollow_castle.tscn", stage_offset = Vector3(0, -600, 0),
		stage_lights = [Vector3(0, 8, -70), Vector3(0, 8, -46), Vector3(0, 9, -20)],
		look = OLD,
		shots = [
			{title = "Before the realm gate. Before the Tavern. Before you.", duration = 5.0},
			{place = {village = "Hearthwick"}, from = Vector3(80, 58, 92), to = Vector3(46, 32, 54), look = Vector3(0, 4, 0), duration = 10.0,
				cards = [{text = "Once, the realm was a single kingdom, and [place]Hearthwick[/place] was its heart.", at = 1.0, hold = 3.4},
					{text = "Its roads were safe after dark. Its doors were never locked.", at = 5.4, hold = 3.2}]},
			{place = {village = "Hearthwick"}, from = Vector3(-16, 4, 20), to = Vector3(-6, 3, 9), look = Vector3(2, 1.6, 0), duration = 9.0,
				cards = [{text = "Bakers and smiths. Weavers and gardeners.", at = 0.8, hold = 3.0},
					{text = "People who had never needed a sword.", at = 4.8, hold = 3.0}]},
			{place = {village = "Bramblebrook"}, from = Vector3(52, 30, -58), to = Vector3(30, 17, -34), look = Vector3(0, 2, 0), duration = 9.0,
				cards = [{text = "In [place]Bramblebrook[/place], the lilies grew taller than the children.", at = 0.8, hold = 3.2},
					{text = "In [place]Snowbell[/place], the bells only ever rang for weddings.", at = 4.8, hold = 3.2}]},
			{from_marker = "ShotHallFrom", to_marker = "ShotHallTo", look_marker = "ShotHallLook", duration = 10.0,
				cards = [{text = "And all of it belonged to a [b]King[/b].", at = 0.8, hold = 3.0},
					{text = "A good one, the old songs say. He knew every one of his people by name.", at = 4.6, hold = 3.6}]},
			{title = "Then came the night the candles went out.", duration = 4.5},
			{stage_at = {from = Vector3(6.5, 4.2, -59), to = Vector3(2.8, 3.4, -66), look = Vector3(0, 3.2, -74)}, duration = 12.0, sound = "boss_intro",
				cards = [{text = "Something came to the throne room that night. Nobody ever saw it, only its shadow.", at = 1.2, hold = 3.6},
					{text = "It did not threaten the King. It [i]offered[/i]. And the King listened.", at = 6.4, hold = 3.4}]},
			{stage_at = {from = Vector3(2.8, 3.4, -66), to = Vector3(1.8, 3.2, -68.5), look = Vector3(0, 3.0, -74)}, duration = 9.0, cut = true,
				cards = [{text = "What sat on the throne afterwards was not a man.", at = 0.8, hold = 3.0},
					{text = "They called it [enemy][b]the Hollow King[/b][/enemy].", at = 4.6, hold = 3.4}]},
			{place = {glade = "Bramblebrook"}, from = Vector3(26, 14, 28), to = Vector3(14, 7, 15), look = Vector3(0, 1.2, 0), duration = 9.5,
				cards = [{text = "By morning the woods were full of things that had not been there the night before.", at = 0.8, hold = 3.6},
					{text = "Goblins in the hedgerows. Thorns with teeth.", at = 5.4, hold = 3.0}]},
			{place = {stronghold = "Doom"}, from = Vector3(0, 70, 200), to = Vector3(0, 44, 150), look = Vector3(0, 10, 0), duration = 9.5,
				cards = [{text = "Fortresses rose in the far corners of the realm, each with something terrible on its throne.", at = 0.8, hold = 3.8},
					{text = "The King took his castle and walked it out of the world. No map would show it again.", at = 5.4, hold = 3.6}]},
			{title = "The kingdom forgot his name. It never forgot its fear.", duration = 5.0},
			{place = {village = "Hearthwick"}, from = Vector3(-10, 3, 16), to = Vector3(-34, 24, 52), look = Vector3(0, 3, 0), look_to = Vector3(0, 6, 0), duration = 12.0,
				grade = OLD, grade_to = TODAY,
				cards = [{text = "That was a long time ago.", at = 1.0, hold = 3.0},
					{text = "[b]Today[/b], the lanterns of Hearthwick are lit again.", at = 5.6, hold = 3.6}]},
			{place = {village = "Bramblebrook"}, from = Vector3(-14, 5, 18), to = Vector3(-8, 3.2, 10), look = Vector3(0, 1.4, 0), duration = 10.0,
				grade = TODAY,
				cards = [{text = "Today, a gardener has his moon-lilies back, because someone came when he asked.", at = 0.8, hold = 3.6},
					{text = "Not everything turned with the King. Good people kept their doors open, and an old wizard still keeps watch.", at = 5.4, hold = 4.0}]},
			{place = {village = "Hearthwick"}, from = Vector3(40, 26, 46), to = Vector3(110, 80, 130), look = Vector3(0, 4, 0), look_to = Vector3(0, 10, -60), duration = 12.0,
				grade = TODAY,
				cards = [{text = "Somewhere out there, the King's castle is waiting to be found.", at = 1.0, hold = 3.4},
					{text = "Its map was torn into six pieces. The first one has already found you.", at = 5.8, hold = 4.0}]},
		],
		actors = [
			# The kingdom: townsfolk going about their day (shots 1-3, 11-13).
			{model = "npc_villager", place = {village = "Hearthwick"}, walk = [7.0, 0.35], shots = [1, 2, 11, 13]},
			{model = "npc_baker", place = {village = "Hearthwick"}, at = Vector3(2, 0, -2), walk = [10.0, -0.28], shots = [1, 2, 11, 13]},
			{model = "city_kid", place = {village = "Hearthwick"}, at = Vector3(-3, 0, 3), walk = [4.0, 0.7], shots = [1, 2, 11, 13]},
			{model = "npc_smith", place = {village = "Hearthwick"}, at = Vector3(4, 0, 4), walk = [12.0, 0.2], shots = [1, 2, 11, 13]},
			{model = "npc_gardener", place = {village = "Bramblebrook"}, walk = [5.0, 0.3], shots = [3, 12]},
			{model = "npc_villager", place = {village = "Bramblebrook"}, at = Vector3(3, 0, -2), walk = [9.0, -0.25], shots = [3, 12]},
			# The good King on his throne, his knights in the hall.
			{model = "city_noble", stage = Vector3(0, 2, -74.1), scale = 1.15, yaw = PI, shots = [4, 6]},
			{model = "castle_knight", stage = Vector3(-7, 0.15, -52), yaw = PI*0.5, shots = [4]},
			{model = "castle_knight", stage = Vector3(7, 0.15, -52), yaw = -PI*0.5, shots = [4]},
			{model = "castle_knight", stage = Vector3(-7, 0.15, -40), yaw = PI*0.5, shots = [4]},
			{model = "castle_knight", stage = Vector3(7, 0.15, -40), yaw = -PI*0.5, shots = [4]},
			# What came to the throne: never in frame, only its shadow.
			{shadow = {size = Vector3(6, 18, 6), light = Vector3(0, 9, 16), toward = Vector3(0, 0, -30)},
				stage = Vector3(0, 0, -40), march = Vector3(0, 0, -24), seconds = 9.0, delay = 1.0, shots = [6]},
			# Afterwards.
			{model = "hollow_king", stage = Vector3(0, 2, -74.1), scale = 0.85, yaw = PI, pose = "sit", shots = [7]},
			# The woods fill.
			{model = "goblin", place = {glade = "Bramblebrook"}, walk = [6.0, 0.5], shots = [8]},
			{model = "goblin", place = {glade = "Bramblebrook"}, at = Vector3(2, 0, 1), walk = [8.0, -0.4], shots = [8]},
			{model = "goblin_brute", place = {glade = "Bramblebrook"}, at = Vector3(-3, 0, 2), walk = [4.0, 0.3], shots = [8]},
			{model = "bramble_fox", place = {glade = "Bramblebrook"}, at = Vector3(1, 0, -3), walk = [9.0, 0.6], shots = [8]},
			{model = "thornmaw_bloom", place = {glade = "Bramblebrook"}, at = Vector3(0, 0, -6), yaw = PI, shots = [8]},
		],
	},
}
