# Expandable blue UI textures

Created with the built-in imagegen tool, using `ui_stone_button.png` as a style
reference. The existing artwork is preserved. Project assets:

- `ui_blue_stone_tile_source.png`: generated blue stone artwork.
- `ui_blue_stone_tile.png`: seamless 256px fill, made from mirrored 128px quadrants.
- `ui_blue_stone_panel.png`: fixed 9px original stone borders around the fill.
- `ui_blue_ivy_panel.png`: fixed 48px original ivy corners around the fill.
- `ui_item_slot_source.png`: generated square slot artwork.
- `ui_item_slot.png`: dedicated 60px item-slot texture.

Panel nine-patches tile in both axes with no stretch-to-fit. Their interior
pixel detail stays the same size when the quest tracker, options content or
other panels expand. Item slots use their own square sprite. Reward cards
and scrollbar tracks do not reuse the item-slot sprite.

Rebuild native-size assets with:

```
/home/hugo/Godot/godot_voxel_editor --headless --path . --script tools/bake_ui_textures.gd
```

## Generation prompts

Panel fill (opaque):

> Use case: stylized-concept. Asset type: seamless repeating pixel-art game UI background texture. The attached blue stone button is a STYLE REFERENCE ONLY. Create a single square, fully opaque, borderless blue slate/enchanted stone texture that matches its cool navy and desaturated cobalt surface, subtle cyan mineral veins, and hand-painted chunky pixel clusters. Intended for a readable dark RPG menu background. Completely flat front view, uniform quiet illumination and overall brightness, no vignette, no central focal point, no frame, no UI elements, no text, no gold accents, no ivy, no transparency. It MUST tile seamlessly on both horizontal and vertical axes: matching color and texture at opposite edges, no visible seams or large directional gradient when repeated. Design as a 128 by 128 pixel-art texture enlarged with nearest-neighbor pixel blocks to a square output. Keep small-scale visual detail consistent and low contrast, with occasional fine diagonal slate layers. Make the navy-blue face close to the reference's interior. Fill the entire square.

Item slot (transparent outside corners):

> Use case: stylized-concept. Asset type: one inventory equipment-slot sprite for a pixel-art action RPG. The attached blue stone button is a STYLE REFERENCE ONLY. Create ONE perfectly square empty item slot, front view, designed on a 60 by 60 pixel-art grid and enlarged with nearest-neighbor edges. Fill almost the entire canvas with the slot, leaving only a very small transparent margin outside clipped corner pixels. Thin 3-pixel-at-native-size beveled dark blue stone border with tiny cyan top-left edge highlights, dark indigo/navy recessed center with subtle fine slate texture, sparse tiny stone chips. Match the reference's blue/cyan palette and chunky pixel rendering. The center must be dark enough behind a colorful item icon. Equal border thickness on all four sides, unornamented corners, no gold, no ivy, no symbols, no object/icon, no text, no glow outside the frame, no heavy outer drop shadow. Make this dedicated square slot, not a horizontal button forced into a square. Preserve small fine texture detail rather than large stretched streaks. Transparent pixels only outside the outer clipped corners; the slot interior is opaque.

## Shared window treatment

Windows use the original `ui_ivy_panel.png` moss frame and its existing dark
blue interior. The theme crops this source directly; it does not insert the
brighter `ui_blue_stone_tile.png` fill. Nested tab and scroll pages are
transparent. Small inner cards sample only the original dark interior, at the
same tint as their parent window. Buttons and item slots keep their artwork.
The baked blue panel files remain available but are not used by the theme.

## Button depth

`ui_stone_button_pressed.png` and `ui_ivy_button_pressed.png` are matching
imagegen edits of the original button/frame artwork, with recessed faces and
inset shadows. Pressed and hover-pressed states use these textures, move label
padding down three pixels, and shorten the drop shadow. Total content padding
is unchanged so clicking does not resize controls or move neighbouring rows.
