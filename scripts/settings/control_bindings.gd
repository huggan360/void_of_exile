class_name ControlBindings
extends RefCounted
## One canonical action catalog: defaults, labels, categories and persistence.
const ACTIONS := [
	{id="move_forward",title="Move forward",category="Movement",key=KEY_W},
	{id="move_back",title="Move backward",category="Movement",key=KEY_S},
	{id="move_left",title="Move left",category="Movement",key=KEY_A},
	{id="move_right",title="Move right",category="Movement",key=KEY_D},
	{id="nexus",title="Escape to the Tavern",category="Movement",key=KEY_R},
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
	{id="interact",title="Interact / leave conversation",category="Interface",key=KEY_X},
	{id="chat",title="Open chat / send message",category="Interface",key=KEY_ENTER},
	{id="menu",title="Pause menu",category="Interface",key=KEY_ESCAPE},
]
const RESERVED := [KEY_F3,KEY_F4,KEY_F6,KEY_F7,KEY_F9]

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
