# Account XP frame

Generated with the built-in imagegen tool using `/home/hugo/Downloads/account xp.png` as the edit target. The original generated PNG is retained with transparency in `assets/ui/account_xp_frame.png`. Godot samples the ornamental region as an atlas; XP fill and labels are runtime UI.

Final prompt:

> Use case: precise-object-edit. Asset type: pixel-art fantasy game HUD bar frame for Godot. Edit target: supplied account XP concept image. Preserve the original ornate gold pixel-art XP bar, pointed end ornaments, foliage, top blue diamond jewel, bottom small gold diamond, and large level diamond badge on the right, closely matching the original proportions and palette. Remove ALL text and ALL numerals: erase '0 / 600 Account XP', 'Lv', and '1', repairing the dark purple/navy inset beneath them. The XP trough must be EMPTY, completely unfilled, and flat dark purple/navy for runtime text and runtime XP fill. The right level badge must have an empty dark inset for a runtime level number. Replace the surrounding black canvas with genuine alpha transparency; keep the dark inset interiors opaque. Crop composition tightly around the complete wide bar with small transparent padding, preserving all ornaments. Hard-edged chunky pixel art matching the input, no smooth vector substitute, no blur, no lettering, no extra elements. Output only the reusable blank UI frame asset on transparency.

Font: Bree Serif, from the Google Fonts `ofl/breeserif` directory, with its bundled OFL in `fonts/BreeSerif-OFL.txt`. Weight is increased at runtime using Godot FontVariation; the font file is unchanged.
