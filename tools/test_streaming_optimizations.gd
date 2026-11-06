extends Node3D
var failed := 0
class TestWorld:
	extends IslandWorld
	func _init() -> void: super({id="performance_test",seed=92811,destroyed=[]})
	func _ready() -> void: pass
func check(value: bool, label: String) -> void:
	if value: print("PERF PASS: ",label)
	else: failed += 1; push_error(label)
func _ready() -> void: run.call_deferred()
func run() -> void:
	GameServer.set_physics_process(false)
	WorldServer.set_process(false)
	var world := TestWorld.new()
	add_child(world)
	var chunk := Node3D.new()
	world.add_child(chunk)
	var collider := StaticBody3D.new()
	chunk.add_child(collider)
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	collider.add_child(shape)
	for i in 30: chunk.add_child(Node3D.new())
	world._chunks[Vector2i.ZERO] = chunk
	await get_tree().physics_frame
	world._prune_chunks({},false)
	check(not chunk.visible and chunk.process_mode==Node.PROCESS_MODE_DISABLED,"retired chunk becomes invisible and disabled")
	check(not world._chunks.has(Vector2i.ZERO),"retired chunk leaves active streaming index")
	await get_tree().physics_frame
	check(not PhysicsServer3D.body_get_space(collider.get_rid()).is_valid(),"retired collision leaves physics space immediately")
	var before := chunk.get_child_count()
	world._retire_step()
	check(chunk.get_child_count()<before and before-chunk.get_child_count()<=8,"chunk cleanup frees bounded batches")
	for i in 10:
		world._retire_step()
		await get_tree().process_frame
	check(world._retired.is_empty(),"retired chunk cleanup completes")
	var a := Atmosphere.new()
	add_child(a)
	a.snap_to(Biomes.get_biome(Biomes.WOODS))
	check(a._settled,"atmosphere stops updating after snap")
	a.blend_to(Biomes.get_biome(Biomes.DOOM),.016)
	check(not a._settled,"biome change restarts smooth atmosphere blending")
	for i in 600: a.blend_to(Biomes.get_biome(Biomes.DOOM),.016)
	check(a._settled,"biome blend converges and settles")
	var bullets := EnemyBullets.new()
	var one := bullets._pixel_trail({color=Color.RED,size=1.0})
	var two := bullets._pixel_trail({color=Color.RED,size=1.0})
	check(one.process_material==two.process_material and one.draw_pass_1==two.draw_pass_1,"matching projectile trails share immutable resources")
	one.free(); two.free(); bullets.free()
	VoxelFire.warm(1)
	var count := VoxelFire._resources.size()
	VoxelFire.warm(1)
	check(VoxelFire._resources.size()==count,"fire resources are cached")
	if DisplayServer.get_name()!="headless":
		var image := Image.create_empty(32,32,false,Image.FORMAT_RGB8)
		image.fill(Color.RED)
		var texture := ImageTexture.create_from_image(image)
		var snapshot: Image = image.duplicate()
		image.fill(Color.BLUE)
		var task := WorkerThreadPool.add_task(Minimap._upload_snapshot.bind(texture,snapshot))
		while not WorkerThreadPool.is_task_completed(task): await get_tree().process_frame
		WorkerThreadPool.wait_for_task_completion(task)
		await RenderingServer.frame_post_draw
		check(texture.get_image().get_pixel(0,0).is_equal_approx(Color.RED),"asynchronous map upload owns an immutable snapshot")
		var minimap := Minimap.new()
		minimap._upload_task = WorkerThreadPool.add_task(Minimap._upload_snapshot.bind(texture,snapshot))
		minimap._finish_tasks()
		check(minimap._upload_task==-1,"map reset joins pending texture uploads")
		minimap.free()
	a.queue_free(); world.queue_free()
	await get_tree().process_frame
	print("PERFORMANCE CHECKS: ",failed," failures")
	get_tree().quit(failed)
