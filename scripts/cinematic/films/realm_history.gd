extends RefCounted
## "What the Realm Remembers": the story of the realm, at the end of The Lily
## Thief. An old black-and-white reel (look.old/mono) of the kingdom, its
## King and the night something came to his throne, turning to colour when
## it reaches today. Format: scripts/cinematic/README.md.
## Shot indexes (for actors' `shots`): 0 card, 1-3 the kingdom, 4 the King,
## 5 card, 6 the Hollow King, 7 the curse spreads, 8 card, 9-10 today.
## Cut to the length of its score (music.intro, 124 s) plus a breath.
const OLD := {mono = 1.0, old = 1.0, grain = 0.6, vignette = 0.7, warmth = 0.25, contrast = 1.12}
const TODAY := {mono = 0.0, old = 0.0, grain = 0.3, vignette = 0.45, warmth = 0.15, contrast = 1.05}

const FILMS := {
	realm_history = {
		title = "What the Realm Remembers", world = "surface", music = "music.intro",
		loading = {title = "What the Realm Remembers", subtitle = "As the old reels tell it"},
		stage = "res://scenes/castle/hollow_castle.tscn", stage_offset = Vector3(0, -600, 0),
		stage_lights = [Vector3(0, 8, -70), Vector3(0, 8, -46), Vector3(0, 9, -20)],
		look = OLD,
		shots = [
			{title = "Before the realm gate. Before the Tavern. Before you.", duration = 4.0},
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
			{title = "Then came the night the candles went out.", duration = 4.0},
			{stage_at = {from = Vector3(4.5, 5.4, -61), to = Vector3(2.0, 4.8, -66.5), look = Vector3(0, 3.8, -74)}, duration = 13.5, sound = "boss_intro",
				cards = [{text = "Something came to the throne room that night. It [i]offered[/i], and the King listened.", at = 0.8, hold = 3.4},
					{text = "What sat on the throne afterwards was not a man.", at = 5.4, hold = 2.8},
					{text = "They called it [enemy][b]the Hollow King[/b][/enemy].", at = 9.2, hold = 3.2}]},
			{place = {glade = "Bramblebrook"}, from = Vector3(26, 14, 28), to = Vector3(14, 7, 15), look = Vector3(0, 1.2, 0), duration = 14.5,
				cards = [{text = "By morning the woods were full of things that had not been there the night before.", at = 0.8, hold = 3.2},
					{text = "Goblins in the hedgerows. Thorns with teeth. Fortresses in the far corners of the realm.", at = 5.0, hold = 3.2},
					{text = "The King took his castle and walked it out of the world. No map would show it again.", at = 9.4, hold = 3.4}]},
			{title = "The kingdom forgot his name. It never forgot its fear.", duration = 4.0},
			{place = {village = "Hearthwick"}, from = Vector3(-10, 3, 16), to = Vector3(-34, 24, 52), look = Vector3(0, 3, 0), look_to = Vector3(0, 6, 0), duration = 14.0,
				grade = OLD, grade_to = TODAY,
				cards = [{text = "That was a long time ago.", at = 1.0, hold = 2.6},
					{text = "[b]Today[/b], the lanterns of [place]Hearthwick[/place] are lit again.", at = 4.6, hold = 3.0},
					{text = "And a gardener has his moon-lilies back, because someone came when he asked.", at = 8.8, hold = 3.4}]},
			{place = {village = "Hearthwick"}, from = Vector3(40, 26, 46), to = Vector3(110, 80, 130), look = Vector3(0, 4, 0), look_to = Vector3(0, 10, -60), duration = 14.5,
				grade = TODAY,
				cards = [{text = "Not everything turned with the King. Good people kept their doors open, and an old wizard still keeps watch.", at = 0.8, hold = 3.4},
					{text = "Somewhere out there, the King's castle is waiting to be found.", at = 5.6, hold = 3.0},
					{text = "Its map was torn into six pieces. The first one has already found you.", at = 9.8, hold = 3.8}]},
		],
		actors = [
			# The kingdom: townsfolk going about their day (shots 1-3, 11-13).
			{model = "npc_villager", place = {village = "Hearthwick"}, walk = [7.0, 0.35], shots = [1, 2, 9, 10]},
			{model = "npc_baker", place = {village = "Hearthwick"}, at = Vector3(2, 0, -2), walk = [10.0, -0.28], shots = [1, 2, 9, 10]},
			{model = "city_kid", place = {village = "Hearthwick"}, at = Vector3(-3, 0, 3), walk = [4.0, 0.7], shots = [1, 2, 9, 10]},
			{model = "npc_smith", place = {village = "Hearthwick"}, at = Vector3(4, 0, 4), walk = [12.0, 0.2], shots = [1, 2, 9, 10]},
			{model = "npc_gardener", place = {village = "Bramblebrook"}, walk = [5.0, 0.3], shots = [3]},
			{model = "npc_villager", place = {village = "Bramblebrook"}, at = Vector3(3, 0, -2), walk = [9.0, -0.25], shots = [3]},
			# The good King on his throne, his knights in the hall.
			{model = "city_noble", stage = Vector3(0, 2, -74.1), scale = 1.15, yaw = PI, shots = [4]},
			{model = "castle_knight", stage = Vector3(-7, 0.15, -52), yaw = PI*0.5, shots = [4]},
			{model = "castle_knight", stage = Vector3(7, 0.15, -52), yaw = -PI*0.5, shots = [4]},
			{model = "castle_knight", stage = Vector3(-7, 0.15, -40), yaw = PI*0.5, shots = [4]},
			{model = "castle_knight", stage = Vector3(7, 0.15, -40), yaw = -PI*0.5, shots = [4]},
			# Afterwards.
			{model = "hollow_king", stage = Vector3(0, 2, -74.1), scale = 0.85, yaw = PI, pose = "sit", shots = [6]},
			# The woods fill.
			{model = "goblin", place = {glade = "Bramblebrook"}, walk = [6.0, 0.5], shots = [7]},
			{model = "goblin", place = {glade = "Bramblebrook"}, at = Vector3(2, 0, 1), walk = [8.0, -0.4], shots = [7]},
			{model = "goblin_brute", place = {glade = "Bramblebrook"}, at = Vector3(-3, 0, 2), walk = [4.0, 0.3], shots = [7]},
			{model = "bramble_fox", place = {glade = "Bramblebrook"}, at = Vector3(1, 0, -3), walk = [9.0, 0.6], shots = [7]},
			{model = "thornmaw_bloom", place = {glade = "Bramblebrook"}, at = Vector3(0, 0, -6), yaw = PI, shots = [7]},
		],
	},
}
