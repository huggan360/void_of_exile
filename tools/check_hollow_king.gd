extends Node3D
## Seconds, no fight simulation: measure actual hazard area and seated snapshots.
var failures := 0
func verify(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)

func _ready() -> void:
	var world := GameWorld.new()
	add_child(world)
	var director := EnemyDirector.new()
	director.world = world
	director.bullets = EnemyBullets.new()
	world.add_child(director)
	world.add_child(director.bullets)
	director.set_process(false)
	var pack := EnemyPack.new()
	pack.site = {id = "qa_king", pos = CastleWorld.THRONE_SEAT, seed = 1}
	var king := EnemyDirector._make_actor(Enemies.get_def("hollow_king")) as Boss
	king.setup(Enemies.get_def("hollow_king"), pack, director)
	king.position = CastleWorld.THRONE_SEAT
	director.add_child(king)
	king.set_physics_process(false)
	king.state = Enemy.State.ACTIVE
	king.phase = 2
	king.set("_barrage", true)
	var previous := 0.0
	var previous_warning := INF
	for wave in 10:
		king.hazards.clear()
		king.call("_barrage_warning")
		var red := 0.0
		for hazard: Dictionary in king.hazards._hazards: red += float(hazard.length) * float(hazard.width)
		var warning: float = king.hazards._hazards[0].warn
		verify(red >= previous if wave < 2 else red > previous, "Red area must grow on wave %d" % wave)
		verify(warning < previous_warning, "Warning must accelerate on wave %d" % wave)
		previous = red
		previous_warning = warning
		king._scheduled.clear()
		print("KING WAVE ", wave + 1, " safe=", snappedf(1.0 - red / (47.0 * 49.0), 0.001), " warning=", warning)
	king.hazards.clear()
	king.set("_barrage", false)
	king.set("_court", true)
	king.phase = 3
	king.call("_magic")
	verify(king.model._boss_pose_name != "cast", "Seated spells must preserve sit")
	king.call("_final_sweep")
	var lifetime: float = king.hazards._hazards[0].warn + king.hazards._hazards[0].active
	verify(float(king.get("_wall_timer")) <= lifetime, "Final sweeps must cover the entire clock")
	var seated := king.net_visuals()
	king.set("_court", false)
	king.mirror_visuals(seated)
	verify(king.model._boss_pose_name == "sit" and is_equal_approx(king.model.rotation.y, PI), "Seated snapshot must restore pose and straight facing")
	king.mirror_visuals([false])
	verify(king.model._boss_pose_name == "rise", "Standing snapshot must clear sit")
	print("HOLLOW KING CHECK failures=", failures)
	get_tree().quit(1 if failures else 0)
