class_name PlanetPalette
extends RefCounted
## Ground colours of the Reach's planets (palette: earth, bright, shade, magic,
## accent, sky). Pure functions of the terrain, safe on mesh worker threads.
## Alpha carries how much the ground glows (magic veins, crystal beds).

static func ground(p: Dictionary, dir: Vector3, height: float, normal: Vector3) -> Color:
	var pal: Array = p.palette
	var earth := Color(str(pal[0]))
	var bright := Color(str(pal[1]))
	var shade := Color(str(pal[2]))
	var magic := Color(str(pal[3]))
	var scale := float(p.terrain.height)
	var t := height/scale
	var slope := 1.0-clampf(normal.dot(dir), 0.0, 1.0)
	# Broad stylised bands, like painted contour lines.
	var band := floorf(clampf(t*0.5+0.5, 0.0, 0.999)*6.0)/5.0
	var color := shade.lerp(earth, smoothstep(0.1, 0.55, band)).lerp(bright, smoothstep(0.62, 1.0, band)*0.85)
	var vein := SpaceLayout._noise(p, 0).get_noise_3dv(dir*float(p.radius)*3.3)
	var glow := 0.0
	match str(p.terrain.style):
		"islands":
			if height< -0.5: color = earth.darkened(0.25).lerp(bright, 0.15)
			elif height<1.6: color = shade
			else: color = magic.lerp(Color("2f6e43"), smoothstep(6.0, 22.0, height)*0.6)
		"hills":
			# Mossy meadows with darker forest floor in the hollows.
			color = color.lerp(Color("5aa04f"), 0.25)
			if vein>0.66: glow = 0.35
		"terraces":
			if fposmod((t*0.5+0.5)*5.0, 1.0)>0.8: color = bright.lightened(0.15)
			if vein>0.66: glow = 0.55
		"dunes":
			color = color.lerp(bright, absf(sin(dir.dot(Vector3(0.6, 0.2, 0.77))*float(p.radius)*0.15))*0.25)
		"crystal":
			if vein>0.58: glow = 0.8
		"craters":
			color = color.lerp(Color("2f3238"), smoothstep(0.0, -0.6, t)*0.6)
			if vein>0.68: glow = 0.7
		"fungal":
			if vein>0.6: glow = 0.8
		"spires":
			color = color.darkened(smoothstep(0.2, 0.9, t)*0.45)
			if vein>0.66: glow = 0.75
	# Steep faces show bare rock.
	color = color.lerp(shade.darkened(0.35), smoothstep(0.22, 0.5, slope)*0.8)
	if glow>0.0: color = color.lerp(magic, 0.6)
	color.a = glow
	return color
