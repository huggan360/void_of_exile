extends "res://scripts/main.gd"
## Online purchase check (a real, non-test server and account service): waits
## for the shops, buys the cheapest thing at Bits and Bobs, checks the Dots and
## the backpack. Run as a test account (p2).
var _done := false

func _ready() -> void:
	super._ready()
	_run.call_deferred()
	get_tree().create_timer(90.0).timeout.connect(func() -> void:
		if not _done: print("[shop-online] TIMEOUT")
		get_tree().quit(2))

func _run() -> void:
	while not (Net.is_client() and Net.client.connected and is_instance_valid(world) and not _traveling and not player.frozen):
		await get_tree().process_frame
	while Shops.state.is_empty(): await get_tree().process_frame
	print("[shop-online] shops arrived: ", Shops.state.shops.size(), " shops, ", Shops.state.offers.size(), " offers")
	var cheapest := {}
	for e: Dictionary in Shops.stock("general"):
		if cheapest.is_empty() or int(e.price)<int(cheapest.price): cheapest = e
	var dots := Account.dots()
	var had := player.stats.find_item(str(cheapest.id))
	print("[shop-online] buying %s for %d with %d Dots" % [cheapest.id, cheapest.price, dots])
	Net.client.send_action("shop", ["general", str(cheapest.id), int(cheapest.price)])
	var until := Time.get_ticks_msec()+15000
	while Account.dots()==dots and Time.get_ticks_msec()<until: await get_tree().process_frame
	await get_tree().create_timer(1.0).timeout
	var got := not player.stats.find_item(str(cheapest.id)).is_empty()
	print("[shop-online] ", "PASS" if Account.dots()==dots-int(cheapest.price) else "FAIL", " Dots %d -> %d" % [dots, Account.dots()])
	print("[shop-online] ", "PASS" if got and had.is_empty() or got else "FAIL", " item in backpack: ", got)
	_done = true
	get_tree().quit(0)
