@tool
extends Marker3D
## Fixed, editor-positioned outdoor station or starting spot for a town resident.
@export_enum("smith", "magician", "baker", "gardener", "villager", "traveler") var role := "villager"
@export var resident_name := "Resident"
@export var stationary := false
@export_multiline var greeting := "Welcome to Hearthhaven!"
@export var interaction_enabled := false
