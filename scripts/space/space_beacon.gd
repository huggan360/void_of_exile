class_name SpaceBeacon
extends Node3D
## A campaign mark: a soft column of light (tall for flight targets) that
## can be seen from far away.
var big := false

func _ready() -> void:
	var beam := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 6.0 if big else 0.35
	mesh.bottom_radius = 6.0 if big else 0.35
	mesh.height = 900.0 if big else 14.0
	mesh.radial_segments = 12
	mesh.cap_top = false
	mesh.cap_bottom = false
	beam.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = Color(1.0, 0.82, 0.35, 0.35) if big else Color(0.45, 1.0, 0.6, 0.55)
	beam.material_override = mat
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	beam.position = Vector3.UP*mesh.height*0.5
	add_child(beam)
	if not big:
		var light := OmniLight3D.new()
		light.light_color = Color("7dff9a")
		light.light_energy = 1.2
		light.omni_range = 5.0
		light.position = Vector3.UP
		add_child(light)

func orient(up: Vector3) -> void:
	var right := up.cross(Vector3.FORWARD if absf(up.dot(Vector3.FORWARD))<0.95 else Vector3.RIGHT).normalized()
	global_basis = Basis(right, up, right.cross(up))
