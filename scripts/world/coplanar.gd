class_name Coplanar
## No z-fighting between art parts: whenever two parts' faces lie on the same
## plane (a sign flush on a wall, a trim strip on a floor, a pad on a deck),
## the smaller part wins. Every batched part is drawn a hair larger than its
## size, and the smaller the part (by volume) the larger that hair, so its
## faces always sit just in front of a bigger neighbour's. Only the drawn
## mesh grows; collision keeps the exact size.
const PAD := 0.012  # metres added to each face of a tiny part
const FALLOFF := 0.5  # how fast the pad shrinks with the part's size

## The size to draw a part of `size` at.
static func grow(size: Vector3) -> Vector3:
	var a := size.abs()
	var scale := pow(maxf(a.x, 0.01)*maxf(a.y, 0.01)*maxf(a.z, 0.01), 1.0/3.0)
	var pad := PAD/(1.0+scale*FALLOFF)*2.0
	return Vector3(size.x+signf(size.x)*pad if size.x!=0.0 else pad, size.y+signf(size.y)*pad if size.y!=0.0 else pad,
		size.z+signf(size.z)*pad if size.z!=0.0 else pad)
