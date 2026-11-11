# Black UI texture set

Black charcoal stone with white/silver trim and ivy. The account XP frame
keeps warm gold/amber metal, with black bar and badge insets and an obsidian
jewel. Normal and recessed pressed textures are included. The item slot is
prepared at the existing 60 x 60 native size; its generated source is retained.

Active temporarily through `UIStyle.TEXTURE_SET = "black"`. Set it to `""`
to restore the original artwork. This also controls the account XP frame.
Original textures remain in the parent folder.

The level wheel uses `ui_xp_ring.png`, a dedicated black stone and white ivy
dial. Its inset track is filled dynamically from white through yellow to
orange by `shaders/xp_ring.gdshader`. The dial width is derived from two
72px item slots plus their 6px gap (150px total).
