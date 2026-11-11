class_name AstralLaunchCinematic
extends CanvasLayer
## One server clock, one rocket pose and one camera timeline for the party.
## The normal portal transition owns the subsequent world-loading handoff.
var campaign: CampaignClient
var _camera := Camera3D.new()
var _previous: Camera3D
var _was_locked := false
var _playing := false
var _from := Transform3D.IDENTITY
var _caption := Label.new()
var _root := Control.new()
var _hidden_avatars: Array[Node3D] = []
var _sky: ShaderMaterial
var _environment: Environment
var _ambient := 0.5

func _ready() -> void:
	layer=95
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter=Control.MOUSE_FILTER_STOP
	add_child(_root)
	for bottom in [false,true]:
		var bar := ColorRect.new()
		bar.color=Color.BLACK
		bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE if bottom else Control.PRESET_TOP_WIDE)
		bar.offset_top=-65 if bottom else 0
		bar.offset_bottom=0 if bottom else 65
		_root.add_child(bar)
	_root.add_child(_caption)
	_caption.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_caption.offset_top=-53
	_caption.offset_bottom=-12
	_caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	_caption.add_theme_font_override("font",UIStyle.font())
	_caption.add_theme_font_size_override("font_size",26)
	_caption.add_theme_color_override("font_color",UIStyle.GOLD)
	add_child(_camera)
	hide()

func update(camp: Dictionary,world: GameWorld) -> void:
	if world is IslandWorld and is_instance_valid(world.astral_station): world.astral_station.update_campaign(camp)
	var flight: Dictionary=camp.get("astral",{}).get("flight",{})
	if camp.get("status","")!="active" or flight.is_empty() or not world is IslandWorld or not is_instance_valid(world.astral_station) or campaign.main._traveling:
		if _playing: cancel()
		return
	var player: Player=campaign.main.player
	if not is_instance_valid(player) or player.frozen: return
	if not _playing:
		_playing=true
		_previous=get_viewport().get_camera_3d()
		_from=_previous.global_transform if is_instance_valid(_previous) else player.camera.global_transform
		_was_locked=player.cinematic_locked
		player.cinematic_locked=true
		player._cancel_weapon_actions()
		# The crew is inside the cabin during the exterior launch shot.
		for actor: Node3D in get_tree().get_nodes_in_group("remote_players") + [player]:
			if actor.visible and (actor is Player or actor.player_id in flight.get("members",[])):
				actor.hide()
				_hidden_avatars.append(actor)
		campaign.main.hud.interaction.close()
		campaign.main.hud.interaction.suppressed=true
		_camera.global_transform=_from
		_camera.fov=60
		_camera.far=1800
		var original := _previous.environment if is_instance_valid(_previous) and _previous.environment!=null else player.get_world_3d().environment
		_environment=original.duplicate() as Environment if original!=null else Environment.new()
		_ambient=_environment.ambient_light_energy
		_environment.background_mode=Environment.BG_SKY
		var sky := Sky.new()
		sky.process_mode=Sky.PROCESS_MODE_REALTIME
		_sky=ShaderMaterial.new()
		_sky.shader=preload("res://shaders/astral_launch_sky.gdshader")
		var biome := world.biome_at(player.global_position)
		_sky.set_shader_parameter("day_top",biome.sky_top_color)
		_sky.set_shader_parameter("day_horizon",biome.sky_horizon_color)
		sky.sky_material=_sky
		_environment.sky=sky
		_camera.environment=_environment
		_camera.make_current()
		show()
	campaign.main.hud.visible=false
	var now := Net.client.server_time() if Net.is_client() else Net.now()
	var age := now-float(flight.start)
	var center: Vector3=world.astral_anchor("rocket")-AstralStation.ROCKET_OFFSET
	var t := clampf(age,0,AstralCampaign.FLIGHT_SECONDS)
	var lift := pow(maxf(0,t-3.2),2)*2.2
	var ascent := smoothstep(4.7,10.1,t)
	_sky.set_shader_parameter("ascent",ascent)
	_environment.ambient_light_energy=lerpf(_ambient,0.16,ascent)
	_environment.fog_density=lerpf(_environment.fog_density,0.0,ascent)
	var from: Vector3
	var look: Vector3
	if t<3.2:
		from=center+Vector3(15,6,9).lerp(Vector3(13,4.5,6),smoothstep(0,3.2,t))
		look=center+Vector3(6,3.5,-5)
		_caption.text="STARLING / AETHER HEART IGNITION" if t>0.7 else "All crew aboard"
	elif t<6.6:
		var w := smoothstep(3.2,6.6,t)
		from=center+Vector3(13,4.5,6).lerp(Vector3(38,25,34),w)
		look=center+Vector3(6,lift+3.5,-5)
		_caption.text="STARFALL LAUNCHWORKS / LIFTOFF"
	else:
		var w := smoothstep(6.6,10.5,t)
		from=center+Vector3(38,25,34).lerp(Vector3(85,95,90),w)
		look=center+Vector3(6,lift+3.5,-5)
		_caption.text="DESTINATION / AURORA OBSERVATION VESSEL"
	var target := Transform3D(Basis.IDENTITY,from).looking_at(look,Vector3.UP)
	_camera.global_transform=_from.interpolate_with(target,smoothstep(-0.9,0.25,age))
	_camera.fov=lerpf(60,70,smoothstep(4,10,t))

func cancel() -> void:
	if not _playing: return
	_playing=false
	for actor: Node3D in _hidden_avatars:
		if is_instance_valid(actor): actor.show()
	_hidden_avatars.clear()
	hide()
	if is_instance_valid(campaign) and is_instance_valid(campaign.main):
		var player: Player=campaign.main.player
		if is_instance_valid(player): player.cinematic_locked=_was_locked
		campaign.main.hud.interaction.suppressed=false
		if not campaign.main._traveling: campaign.main.hud.visible=true
	if is_instance_valid(_previous): _previous.make_current()
	elif is_instance_valid(campaign.main.player): campaign.main.player.camera.make_current()
	_camera.clear_current()
	_camera.environment=null
	_environment=null
	_sky=null
