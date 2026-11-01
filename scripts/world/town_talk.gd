class_name TownTalk
## What townsfolk say when you talk to them: nothing special, a line of
## small talk picked at random for their trade (and the town they live in).

const LINES := {
	baker = ["Fresh loaves at dawn, if the goblins leave my flour alone.",
		"Smell that? Honey bread. Don't tell the smith, he eats it all.",
		"An adventurer once paid me in dragon scales. I still can't slice bread with them."],
	gardener = ["The soil here remembers every footstep. Mind the tulips.",
		"Something in the woods keeps eating my turnips. Something big.",
		"Water the roots, not the leaves. That's all the wisdom I've got."],
	villager = ["Roads are safer than the woods. Mostly.",
		"My cousin went looking for the fortress in the frost. He came back... colder.",
		"Have you seen the lights over the old ruins? Best not to look too long.",
		"The steward keeps a book of everyone who calls %s home."],
	traveler = ["I've walked every road on this island. My boots haven't forgiven me.",
		"The deserts sing at night. Don't sing back.",
		"Follow the paved roads: you'll travel half again as fast."],
	smith = ["A good bow needs good string. A good string needs patience.",
		"Bring me something shiny from a fortress and I'll tell you what it's worth.",
		"Sparks don't bite. Usually."],
	magician = ["The void hums under these stones. Can you hear it?",
		"Every spell is a question. Most answers are explosions.",
		"Keep your shield up near the Hollow Throne. Trust me."],
	herbalist = ["Bitterleaf for courage, sweetroot for sleep. Never mix them.",
		"The jungle grows remedies and poisons side by side."],
	steward = ["Welcome to %s. The town book is open, if you'd like to settle here."],
}
const ANY := ["Lovely weather for not being eaten.", "Stay safe out there, traveler.",
	"They say the realm never ends. My feet agree.", "Watch for dark shapes in the tall grass."]


static func line(role: String, village: String) -> String:
	var lines: Array = LINES.get(role, ANY) + ANY
	var text: String = lines[randi() % lines.size()]
	return text % village if "%s" in text else text
