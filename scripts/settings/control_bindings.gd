class_name ControlBindings
extends RefCounted
## One canonical action catalog: defaults, labels, categories and persistence.
const ACTIONS := [
	{id="move_forward",title="Move forward",category="Movement",key=KEY_W},
	{id="move_back",title="Move backward",category="Movement",key=KEY_S},
	{id="move_left",title="Move left",category="Movement",key=KEY_A},
	{id="move_right",title="Move right",category="Movement",key=KEY_D},
	{context="global",id="nexus",title="Escape to the Tavern",category="Movement",key=KEY_R},
	{id="shoot",title="Shoot",category="Combat",mouse=MOUSE_BUTTON_LEFT},
	{id="charge",title="Charge attack",category="Combat",mouse=MOUSE_BUTTON_RIGHT},
	{id="magic",title="Shield / double-tap ring",category="Combat",key=KEY_SPACE},
	{id="quick_1",title="Use quickslot 1",category="Combat",key=KEY_F},
	{id="quick_2",title="Use quickslot 2",category="Combat",key=KEY_G},
	{id="orbit_left",title="Rotate camera left",category="Camera",key=KEY_Q},
	{id="orbit_right",title="Rotate camera right",category="Camera",key=KEY_E},
	{id="zoom_in",title="Zoom camera in",category="Camera",key=KEY_I},
	{id="zoom_out",title="Zoom camera out",category="Camera",key=KEY_O},
	{id="minimap_zoom_in",title="Zoom minimap in",category="Camera",mouse=MOUSE_BUTTON_WHEEL_UP},
	{id="minimap_zoom_out",title="Zoom minimap out",category="Camera",mouse=MOUSE_BUTTON_WHEEL_DOWN},
	{id="inventory",title="Hold backpack open",category="Interface",key=KEY_TAB},
	{id="stats",title="Toggle character stats",category="Interface",key=KEY_C},
	{id="map",title="Toggle large map",category="Interface",key=KEY_M},
	{id="interact",title="Interact / leave conversation",category="Interface",key=KEY_X},
	{context="global",id="chat",title="Open chat / send message",category="Interface",key=KEY_ENTER},
	{context="global",id="menu",title="Pause menu",category="Interface",key=KEY_ESCAPE},
	{context="ship",id="ship_forward",title="Forward thrust",category="Spaceship flight",key=KEY_W},
	{context="ship",id="ship_reverse",title="Reverse thrust",category="Spaceship flight",key=KEY_S},
	{context="ship",id="ship_left",title="Turn left",category="Spaceship flight",key=KEY_A},
	{context="ship",id="ship_right",title="Turn right",category="Spaceship flight",key=KEY_D},
	{context="ship",id="ship_pitch_up",title="Pitch up",category="Spaceship flight",key=KEY_UP},
	{context="ship",id="ship_pitch_down",title="Pitch down",category="Spaceship flight",key=KEY_DOWN},
	{context="ship",id="ship_roll_left",title="Roll left",category="Spaceship flight",key=KEY_Q},
	{context="ship",id="ship_roll_right",title="Roll right",category="Spaceship flight",key=KEY_E},
	{context="ship",id="ship_boost",title="Boost",category="Spaceship flight",key=KEY_SHIFT},
	{context="ship",id="ship_pulse",title="Toggle pulse drive",category="Spaceship flight",key=KEY_C},
	{context="ship",id="ship_launch",title="Launch",category="Spaceship flight",key=KEY_SPACE},
	{context="ship",id="ship_land",title="Land / dock / descend",category="Spaceship flight",key=KEY_X},
	{context="ship",id="ship_fire",title="Fire cannons",category="Spaceship weapons",mouse=MOUSE_BUTTON_LEFT},
	{context="ship",id="seat_camera",title="Change camera",category="Ship seats",key=KEY_V},
	{context="ship",id="seat_stand",title="Stand up",category="Ship seats",key=KEY_Z},

]
const RESERVED := []

static func spec(action: String) -> Dictionary:
	for entry: Dictionary in ACTIONS:
		if entry.id==action: return entry
	return {}

static func default_binding(action: String) -> Dictionary:
	var entry := spec(action)
	return {kind="mouse",code=int(entry.mouse)} if entry.has("mouse") else {kind="key",code=int(entry.get("key",0)),ctrl=false,alt=false,shift=false,meta=false}

static func from_event(event: InputEvent) -> Dictionary:
	if event is InputEventKey:
		var key := event as InputEventKey
		var code: int = key.physical_keycode if key.physical_keycode!=0 else key.keycode
		if code==0 or code in RESERVED: return {}
		return {kind="key",code=code,ctrl=key.ctrl_pressed and code!=KEY_CTRL,alt=key.alt_pressed and code!=KEY_ALT,shift=key.shift_pressed and code!=KEY_SHIFT,meta=key.meta_pressed and code!=KEY_META}
	if event is InputEventMouseButton:
		return {kind="mouse",code=int(event.button_index)}
	return {}

static func normalized(value: Variant) -> Dictionary:
	if not value is Dictionary: return {}
	var kind: String = value.get("kind","")
	var code: int = int(value.get("code",0))
	if kind=="mouse" and code>=1 and code<=9: return {kind="mouse",code=code}
	if kind!="key" or code<=0 or code in RESERVED or OS.get_keycode_string(code).is_empty(): return {}
	return {kind="key",code=code,ctrl=bool(value.get("ctrl",false)),alt=bool(value.get("alt",false)),shift=bool(value.get("shift",false)),meta=bool(value.get("meta",false))}

static func event_for(binding: Dictionary) -> InputEvent:
	if binding.kind=="mouse":
		var event := InputEventMouseButton.new()
		event.button_index = binding.code
		return event
	var event := InputEventKey.new()
	event.physical_keycode = binding.code
	event.ctrl_pressed = binding.get("ctrl",false)
	event.alt_pressed = binding.get("alt",false)
	event.shift_pressed = binding.get("shift",false)
	event.meta_pressed = binding.get("meta",false)
	return event

static func text(binding: Dictionary) -> String:
	if binding.is_empty(): return "Unassigned"
	if binding.kind=="mouse":
		return {1:"Left mouse",2:"Right mouse",3:"Middle mouse",4:"Wheel up",5:"Wheel down",6:"Wheel left",7:"Wheel right"}.get(int(binding.code),"Mouse %d" % binding.code)
	var prefix := ""
	if binding.get("ctrl",false): prefix += "Ctrl+"
	if binding.get("alt",false): prefix += "Alt+"
	if binding.get("shift",false): prefix += "Shift+"
	if binding.get("meta",false): prefix += "Meta+"
	return prefix+OS.get_keycode_string(binding.code)

## Flight and on-foot bindings can share keys; global menu/chat/recall stay available.
static func overlaps(a: String, b: String) -> bool:
	var first := str(spec(a).get("context", "foot"))
	var second := str(spec(b).get("context", "foot"))
	return first==second or first=="global" or second=="global"
