class_name BuffArt
extends RefCounted
## Shared authored pixels with runtime outlines, just like inventory item silhouettes.
## The original 16x16 flag remains intact inside an 18x18 outlined composite.
static var _textures := {}
static var _badges := {}

static func texture(file: String) -> Texture2D:
	if not _textures.has(file):
		var path := "res://buffs/"+file+".png"
		if not ResourceLoader.exists(path): path = "res://buffs/"+file+".svg"
		_textures[file] = load(path) if ResourceLoader.exists(path) else null
	return _textures[file]

static func badge(e: Dictionary) -> Texture2D:
	var key := StatusEffects.banner(e)+"/"+StatusEffects.icon(e.id)
	if not _badges.has(key):
		var banner := texture("banners/"+StatusEffects.banner(e))
		var icon := texture("icons/"+StatusEffects.icon(e.id))
		if banner == null or icon == null: return null
		var flag := banner.get_image()
		flag.convert(Image.FORMAT_RGBA8)
		var pixels := icon.get_image()
		pixels.convert(Image.FORMAT_RGBA8)
		var img := Image.create_empty(18,18,false,Image.FORMAT_RGBA8)
		_outline(img,flag,Vector2i(1,1),Color.BLACK)
		img.blend_rect(flag,Rect2i(0,0,16,16),Vector2i(1,1))
		# Icon stays centered at (4,4) relative to the original flag; outline grows outwards.
		_outline(img,pixels,Vector2i(5,5),Color.WHITE)
		img.blend_rect(pixels,Rect2i(0,0,8,8),Vector2i(5,5))
		_badges[key] = ImageTexture.create_from_image(img)
	return _badges[key]

static func _outline(target: Image, source: Image, offset: Vector2i, color: Color) -> void:
	for y in source.get_height():
		for x in source.get_width():
			if source.get_pixel(x,y).a<.1: continue
			for step in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
				var p: Vector2i = Vector2i(x,y)+offset+step
				if p.x>=0 and p.y>=0 and p.x<target.get_width() and p.y<target.get_height():
					target.set_pixelv(p,color)
