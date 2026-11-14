# Cutscenes

A film is a plain dictionary. All of them live in `films/*.gd` (one `const FILMS`
per file, listed in `Cutscenes.SOURCES`). The server sends only a film's id;
every client looks it up in `Cutscenes`, builds a `FilmSet` for it in its own
world and plays it with `CampaignCinematic`.

- **Opening a tale:** give the campaign `intro = "<film id>"` (Campaigns.LIST).
  Each tale's opening plays once, when it starts fresh.
- **After a step:** give the step `cutscene = "<film id>"`.
- **To watch one:** `godot --path . -- --watch-cutscene=<film id>`. Every film
  gets a viewer automatically; Desktop launchers are in
  `~/Desktop/Cutscene Watchers/` (see `tools/cutscene_watch/`).

## A film

| key | what |
|---|---|
| `title` | its name |
| `world` | where it is shot: `"tavern"` (the party's own Tavern), `"surface"`, `"space"`, `"castle"` or `"any"`. A client keeps the film until its player is in such a world, then plays it. |
| `campaign` | the tale it opens: a chapter card comes first ("Chapter Three", then the title over the pack's name) |
| `loading` | `{title, subtitle}`: a title card for films that open no tale |
| `look` | the film's look (below) |
| `stage`, `stage_offset`, `stage_lights` | a scene loaded far from the world for its shots (the Hollow Castle) |
| `show_map` | hold up the six map pieces first |
| `fireworks` | fireworks over `village` shots |
| `astral_station` | (viewer hint) the Surface with Orin's launch station |
| `fov` | the film's field of view (default 55) |
| `shots`, `actors` | below |

## A shot

Every picture fades up from black only when its place has streamed in (Surface
chunks and voxel terrain meshed, a moment for Space to build round the camera),
so a cut never shows an empty world. Captions are timed against the shot; a
shot is stretched when its last caption needs longer to be read.

Where the camera stands (one of):

| form | meaning |
|---|---|
| `place = <anchor>`, `from`, `to`, `look`, `look_to` | the Surface: any `Campaigns.resolve` anchor (`{village}`, `{stronghold = biome}`, `{summit}`, `{cabin}`, `{glade}`, `{astral = "rocket"}`, with `offset`). Offsets are metres from it, heights above its ground; `turn` rotates them (degrees). |
| `space = {at, planet, place, from, to, look, look_to}` | the Reach: `at` = `orbit` (the planet's centre), `town` (+`spot`), `dock`, `pad`, `fort`, `place` (a `SpaceLayout.PLACES` name in `place`), `nexus` or `diner` |
| `stage_at = {from, to, look}` | offsets on the stage |
| `from_marker`, `to_marker`, `look_marker` | the stage scene's Marker3D names |
| `village = "Hearthwick"` | a ready-made slow glide down to a town |
| `from`, `to`, `look_from`, `look_to` | world positions (the Tavern films) |
| `title`, `subtitle` (no camera) | words on black between pictures; the next picture streams in behind them |

The camera glides from `from` to `to` looking from `look` to `look_to`, and never
dips into the ground or a planet. Also on a shot:

- `duration` (seconds), `cards = [{text, at, hold}]` (TextMarkup: `[npc]`, `[place]`,
  `[enemy]`, `[b]`, `[i]`)
- `focus`: where the lens is sharp (same space as `look`; default the look point).
  Nearer and farther things go soft, if the player's Graphics setting allows depth of field.
- `fov`, `fov_to`; `sound` (a GameAudio event at the start); `cut = true`
  (a hard cut from the previous shot, for the same place)
- `grade` (this shot's look) and `grade_to` (blends to it over the shot)

## Look

`{vignette, grain, mono, old, warmth, contrast}` (shaders/film_look.gdshader),
drawn over the world only, never over the captions. `mono` 1 = black and
white; `old` 1 = a worn reel on an old television (flicker, scan lines,
dust, scratches, a rounded tube). Every film gets a light vignette and grain
by default. `realm_history.gd` shows a film turning from an old reel to colour.

## Actors

`{model, yaw, scale, walk = [radius, speed] | march = Vector3, variant, pose}` placed with
`stage = Vector3`, `space = {..., at_local}` or `place = <anchor>` (+`at`, on the
ground). `shots = [indexes]` shows an actor only in those shots (a hard cut
can swap who sits on a throne). `pose` is a boss pose ("sit").

`shadow = {size, light, toward}` with `march`, `seconds`, `delay`: something
enormous that never comes into frame. Only its shadow does, thrown by a cold
light behind it, and it starts walking when its first shot begins.
