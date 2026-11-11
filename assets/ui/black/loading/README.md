# Ink loading animations

Three six-frame firing sheets, derived from the game's G8 bow, wand and
trident icons with imagegen. Each sheet is a 3-column, 2-row atlas, read left
to right then top to bottom. The loader chooses a weapon for each departure
and plays the six poses at exactly 5 FPS. The stipple shader removes grey haze
and draws white engraved dots on black. There is no SubViewport or 3D actor.

Destination text uses the shared Bree Serif font. LoadingVine follows actual
load progress. LoadingFootsteps confines curved trails to the outer screen
margins, with a hard exclusion around the central content, then fades prints.

Render all variants with `tools/preview_ink_loader.tscn`.
