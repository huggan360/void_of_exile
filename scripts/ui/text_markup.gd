class_name TextMarkup
## Story text with highlighted words: [npc]Gerald[/npc] in green,
## [enemy]Thorn Hoppers[/enemy] in red, [place]Bramblebrook[/place] in blue,
## [b]...[/b] bold. "|" splits a speech into pages. Any other bracket is
## shown as written (players can't inject formatting).

const PAGE_CHARS := 150  # a page longer than this is split between sentences

const _TAGS := {
	"[npc]": "[b][color=#7ee08a]", "[/npc]": "[/color][/b]",
	"[enemy]": "[b][color=#ff6b5e]", "[/enemy]": "[/color][/b]",
	"[place]": "[b][color=#6fb8ff]", "[/place]": "[/color][/b]",
	"[b]": "[b]", "[/b]": "[/b]", "[i]": "[i]", "[/i]": "[/i]",
}


## BBCode for a RichTextLabel.
static func to_bbcode(text: String) -> String:
	var keep := {}
	var i := 0
	for tag: String in _TAGS:
		var mark := "\u0001%d\u0002" % i
		keep[mark] = _TAGS[tag]
		text = text.replace(tag, mark)
		i += 1
	text = text.replace("[", "[lb]")
	for mark: String in keep:
		text = text.replace(mark, keep[mark])
	return text


## The words alone (for plain labels and lengths).
static func plain(text: String) -> String:
	for tag: String in _TAGS:
		text = text.replace(tag, "")
	return text.replace("|", " ")


## A speech as pages: at every "|", and between sentences when too long.
static func pages(text: String) -> Array[String]:
	var out: Array[String] = []
	for part: String in text.split("|", false):
		var page := ""
		for sentence: String in _sentences(part.strip_edges()):
			if page != "" and plain(page + " " + sentence).length() > PAGE_CHARS:
				out.append(page)
				page = sentence
			else:
				page = sentence if page == "" else page + " " + sentence
		if page != "":
			out.append(page)
	return out


static func _sentences(text: String) -> Array[String]:
	var out: Array[String] = []
	var start := 0
	for k in text.length():
		if text[k] in [".", "!", "?"] and (k + 1 == text.length() or text[k + 1] == " "):
			out.append(text.substr(start, k + 1 - start).strip_edges())
			start = k + 1
	if start < text.length() and text.substr(start).strip_edges() != "":
		out.append(text.substr(start).strip_edges())
	return out
