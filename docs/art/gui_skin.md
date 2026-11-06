# Shared GUI skin

Built-in imagegen was used with the preview from the user's `Downloads/BG.pxo` as a palette reference. The original RGBA outputs are retained without repainting in:

- `assets/ui/ui_ivy_panel.png`
- `assets/ui/ui_stone_button.png`

`UIStyle` samples each sprite's atlas region and gives the nine-patch texture a consistent logical size. Ivy is reserved for the account journey, backpack, campaign browser, and outer options window. Smaller cards and buttons use the matching undecorated blue-stone material. Conversation panels intentionally remain background-free.

Panel prompt:

> Use case: stylized-concept. Asset type: reusable blank nine-patch PANEL texture for a pixel-art fantasy RPG game UI, no lettering. Reference image is ONLY a palette and atmosphere reference: enchanted blue ancient ruins with green plants. Create ONE square flat front-facing UI panel, tightly filling the image with a very small transparent exterior margin. The panel is opaque deep midnight/slate BLUE stone, with gentle irregular blue color variation and a few fine weathering marks, readable quiet interior. Thin carefully shaded carved blue-stone border, one restrained antique brass inner hairline, clipped pixel corners, professional detailed hand-painted PIXEL ART like an RPG inventory interface, NOT smooth vector, NOT photographic. Small green climbing ivy grows around TOP LEFT corner and BOTTOM RIGHT corner ONLY, concentrated in the outer 10 percent edges, a few lively jade and moss leaves, less than 8 percent coverage total. Other corners bare. Main center 75 percent is open quiet blue stone for UI text. No vines crossing text interior, no giant gems, no heavy golden frame, no text, no symbols, no interface content, no shadows extending far outside border. Everything outside the single panel fully alpha-transparent. Output one single blank panel suitable for nine-patch borders; no mockup, no multiple tiles.

Button prompt:

> Use case: stylized-concept. Asset type: reusable blank BUTTON sprite for a pixel-art fantasy RPG UI. Palette reference image ONLY: ancient blue stone, moss green, cyan magical light. Create ONE wide short rectangular button, front view, centered, flat UI sprite, approx 4:1 width to height, with only small transparent padding outside. Detailed hand-painted PIXEL ART that remains legible when downscaled, hard stepped pixel edges, NOT vector graphics. Button face subtly mottled desaturated sapphire and slate BLUE stone, gentle highlights, thin carved dark blue-stone rim, a very restrained aged brass accent on top edge, small chamfered corners, shallow believable bevel, shaded base. Simple clean professional fantasy button that can repeat throughout an RPG. No green plant decorations on the button itself (plants belong on larger panels), no gold keycap block, no double thick borders, no inset icon, no writing, no lettering, no symbols, no states sheet, no multiple buttons. Blank center for runtime title. Exterior genuinely transparent. Single UI asset, not an in-game screenshot.
