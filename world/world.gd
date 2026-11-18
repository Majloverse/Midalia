extends Node3D
## The neighbourhood and the first night: walking, the party, finding a couch,
## and passing out at 5:00 if you didn't. Everything is built from simple blocks
## here; proper models replace them later.
##
## Two streets cross in the middle. Each place sits on the "main" street (runs
## east-west) or the "cross" street (runs north-south): `along` is how far down
## that street, `side` is which side of it (-1 or 1).

const ROAD_HALF_WIDTH := 5.0
const SETBACK := 8.0  # distance from the street's centre line to building fronts
## The party flat's inside is a separate room, far from the streets.
const PARTY_ROOM := Vector3(500, 0, 0)
const PARTY_DOOR_OUTSIDE := Vector3(-22, 0.1, 5.5)

const PLACES := [
	{"sign": "STAZIONE CENTRALE", "road": "main", "along": -70, "side": -1, "width": 30, "depth": 16, "height": 12,
		"color": Color(0.75, 0.7, 0.6), "prompt": "Enter the station", "action": "message", "message": "Nothing for you here. You just got off the train."},
	{"sign": "BANCA", "road": "main", "along": 28, "side": -1, "width": 16, "depth": 12, "height": 10,
		"color": Color(0.8, 0.8, 0.75), "prompt": "Enter the bank", "action": "bank"},
	{"sign": "UNIVERSITÀ", "road": "main", "along": 70, "side": 1, "width": 34, "depth": 20, "height": 14,
		"color": Color(0.7, 0.55, 0.45), "prompt": "Enter the university", "action": "message", "message": "School hasn't started yet."},
	{"sign": "VIA ROMA 12", "road": "main", "along": -22, "side": 1, "width": 14, "depth": 12, "height": 18,
		"color": Color(0.85, 0.65, 0.4), "prompt": "Go up to the party", "action": "party"},
	{"sign": "VIA VERDI 3", "road": "cross", "along": 40, "side": 1, "width": 12, "depth": 12, "height": 15,
		"color": Color(0.8, 0.5, 0.45), "prompt": "Ring the bell", "action": "flat"},
	{"sign": "VIA DANTE 7", "road": "cross", "along": -45, "side": -1, "width": 12, "depth": 12, "height": 15,
		"color": Color(0.6, 0.7, 0.6), "prompt": "Ring the bell", "action": "flat"},
	{"sign": "VIA MILANO 21", "road": "cross", "along": 75, "side": -1, "width": 12, "depth": 12, "height": 15,
		"color": Color(0.65, 0.65, 0.8), "prompt": "Ring the bell", "action": "flat"},
]
## Buildings you can't enter: [road, along, side, width, height]
const FILLERS := [
	["main", -45, -1, 16, 14], ["main", -22, -1, 18, 20], ["main", 50, -1, 18, 16], ["main", 76, -1, 20, 12],
	["main", -48, 1, 20, 13], ["main", -75, 1, 18, 17], ["main", 26, 1, 22, 15],
	["cross", 58, 1, 14, 12], ["cross", -65, 1, 16, 16], ["cross", -70, -1, 14, 13], ["cross", 95, 1, 16, 18],
	["cross", 52, -1, 14, 14], ["cross", -42, 1, 14, 17],
]
const FILLER_COLORS := [Color(0.72, 0.68, 0.62), Color(0.78, 0.7, 0.58), Color(0.66, 0.62, 0.6), Color(0.8, 0.74, 0.66)]
const CLOTHES := [Color(0.7, 0.2, 0.25), Color(0.2, 0.55, 0.4), Color(0.75, 0.6, 0.15), Color(0.45, 0.25, 0.6), Color(0.15, 0.5, 0.65), Color(0.8, 0.4, 0.15)]
const SKINS := [Color(0.95, 0.8, 0.68), Color(0.82, 0.62, 0.48), Color(0.6, 0.42, 0.3), Color(0.42, 0.28, 0.2)]

var _sun: DirectionalLight3D
var _environment: Environment
var _lamps: Array[OmniLight3D] = []
var _hud: Hud
var _phone: Phone
var _talk: Talk
var _wheel: WheelScreen
var _bank: BankScreen
var _player: Player
var _flat_doors := {}  # sign -> the Area3D at that flat's door
var _in_party := false
var _game_over := false


func _ready() -> void:
	_build_sky()
	_build_ground()
	for place in PLACES:
		_build_building(place.road, place.along, place.side, place.width, place.depth, place.height, place.color, place)
	for i in FILLERS.size():
		var f: Array = FILLERS[i]
		_build_building(f[0], f[1], f[2], f[3], 12, f[4], FILLER_COLORS[i % FILLER_COLORS.size()], {})
	for x in range(-90, 91, 30):
		_build_lamp(Vector3(x, 0, ROAD_HALF_WIDTH + 1.0))
		_build_lamp(Vector3(x + 15, 0, -ROAD_HALF_WIDTH - 1.0))
	for z in [-80, -50, -25, 25, 55, 85]:
		_build_lamp(Vector3(ROAD_HALF_WIDTH + 1.0, 0, z))
	_build_party_room()

	_hud = Hud.new()
	add_child(_hud)
	_phone = Phone.new()
	add_child(_phone)
	_talk = Talk.new()
	add_child(_talk)
	_wheel = WheelScreen.new()
	add_child(_wheel)
	_bank = BankScreen.new()
	add_child(_bank)
	_bank.closed.connect(_on_bank_closed)
	_player = Player.new()
	_player.position = Vector3(-70, 0.1, -3)
	add_child(_player)
	_player.prompt_changed.connect(_hud.set_prompt)
	_player.interacted.connect(_on_interact)
	Game.notice.connect(_hud.show_message)
	Game.shelter_changed.connect(_refresh_flat_doors)
	Game.night_ended.connect(_pass_out)
	_hud.show_message("You just landed in Milan. The party at Via Roma 12 starts at 21:00. Tab for your phone.")


func _process(_delta: float) -> void:
	# Sun rises at 6:00, is highest at 12:00 and sets at 18:00... roughly; dusk lingers a little.
	var hour := Game.hour()
	var angle := (hour - 6.0) / 24.0 * TAU
	var height := sin(angle)  # 1 at noon, -1 at midnight
	_sun.rotation = Vector3(-angle, 0.6, 0)
	var daylight := clampf(height * 3.0 + 0.4, 0.0, 1.0)
	_sun.light_energy = daylight * 1.2
	_sun.light_color = Color(1.0, 0.75, 0.55).lerp(Color.WHITE, clampf(height * 2.5, 0.0, 1.0))
	_environment.background_energy_multiplier = lerpf(0.06, 1.0, daylight)
	_environment.ambient_light_energy = lerpf(0.35, 1.0, daylight)
	for lamp in _lamps:
		lamp.visible = daylight < 0.6
	if Game.wellbeing <= 0 and not _game_over and not Game.modal_open:
		_show_game_over()


# --- Things the player can do ---

func _on_interact(area: Area3D) -> void:
	match area.get_meta("action", "message"):
		"message":
			_hud.show_message(area.get_meta("message"))
		"bank":
			if Game.bank_is_open():
				_bank.open()
			else:
				_hud.show_message("The bank is closed. It is open %d:00 to %d:00." % [Settings.BANK_OPENS_HOUR, Settings.BANK_CLOSES_HOUR])
		"party":
			if Game.is_night():
				_in_party = true
				_player.teleport(PARTY_ROOM + Vector3(0, 0.1, 2.5), 0.0)
				_hud.show_message("The party. Walk up to people and press E to talk.")
			else:
				_hud.show_message("Nobody answers. The party starts at 21:00.")
		"leave_party":
			_in_party = false
			_player.teleport(PARTY_DOOR_OUTSIDE, 0.0)
		"talk":
			_talk.open(area.get_meta("person"))
		"flat":
			var host := Game.shelter_host
			if host == null or host.home != area.get_meta("sign"):
				_hud.show_message("A student flat. Nobody here has invited you.")
			elif not Game.is_night():
				_hud.show_message("%s isn't home. Come back tonight." % host.name)
			else:
				_hud.show_message(Game.sleep_on_couch())


func _refresh_flat_doors() -> void:
	for sign in _flat_doors:
		var host := Game.shelter_host
		var prompt := "Ring the bell"
		if host != null and host.home == sign:
			prompt = "Sleep on %s's couch" % host.name
		_flat_doors[sign].set_meta("prompt", prompt)
	_player.refresh_prompt()


## 5:00 and still not asleep: you pass out where you are. Two wheels decide the cost.
func _pass_out() -> void:
	if _game_over:
		return
	if _talk.is_open():
		_talk.close()
	if _bank.is_open():
		_bank.close()
	if Game.phone_open:
		_phone.toggle()
	Game.modal_open = true
	Game.clock_running = false
	if _in_party:
		_in_party = false
		_player.teleport(PARTY_DOOR_OUTSIDE, 0.0)

	var damages: Array = Settings.STREET_DAMAGE
	var hit := Game.rng.randi() % damages.size()
	var labels: Array = damages.map(func(d): return "-%d" % d)
	await _wheel.spin("5:00. You pass out on the street.\nSpin to see what the night does to you.",
		labels, [Color(0.25, 0.3, 0.45), Color(0.4, 0.3, 0.5), Color(0.55, 0.3, 0.4), Color(0.7, 0.25, 0.25)],
		hit, "Wellbeing -%d" % damages[hit])
	Game.wellbeing = clampi(Game.wellbeing - damages[hit], 0, 100)

	if Game.cash > 0:
		# Looks like an even chance. It isn't.
		var robbed := Game.rng.randf() < Settings.ROBBED_CHANCE
		var slots := [0, 2, 4] if robbed else [1, 3, 5]
		var lost := Game.cash
		await _wheel.spin("You have %d euro in your pockets.\nSpin to see if it's still there in the morning." % Game.cash,
			["ROBBED", "SAFE", "ROBBED", "SAFE", "ROBBED", "SAFE"], [Color(0.6, 0.08, 0.08), Color(0.08, 0.08, 0.08)],
			slots[Game.rng.randi() % 3], ("ROBBED. All %d euro is gone." % lost) if robbed else "SAFE. Your money is still there.")
		if robbed:
			Game.cash = 0
			Game.add_note("I passed out on the street and woke up with empty pockets. %d euro, gone." % lost)

	Game.shelter_host = null
	Game.shelter_changed.emit()
	Game.skip_to_morning()
	Game.modal_open = false
	Game.clock_running = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_hud.show_message("You wake up on the pavement. It's 9:00.")


## The first build's finish line: you got through a night and have a bank account.
func _on_bank_closed() -> void:
	if not Game.bank_account or not Game.night_survived or Game.survived_shown:
		return
	Game.survived_shown = true
	var friends := Game.contacts.filter(func(p): return p.is_friend).size()
	var text := "You survived.\n\nOne night in Milan and one Italian bank account.\n\n"
	text += "Wellbeing %d%%\nIn your pocket: %d euro\nIn the bank: %d euro\n" % [Game.wellbeing, Game.cash, Game.bank_balance]
	text += "Numbers in your phone: %d\nFriends: %d\n" % [Game.contacts.size() - 4, friends]
	text += "Tuition: %s" % ("paid" if Game.tuition_owed <= 0 else "%d euro still owed" % Game.tuition_owed)
	_show_end(text, "Keep playing", false)


func _show_game_over() -> void:
	_game_over = true
	_show_end("Your wellbeing hit zero.\nMilan won. You go home on day %d." % Game.day, "", true)


## A full-screen ending. A non-empty keep_playing adds a button that closes it and carries on.
func _show_end(text: String, keep_playing: String, final: bool) -> void:
	Game.modal_open = true
	Game.clock_running = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var layer := CanvasLayer.new()
	layer.layer = 30
	add_child(layer)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.9)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 20)
	dim.add_child(column)
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 32 if final else 26)
	column.add_child(label)
	if keep_playing != "":
		var carry_on := Button.new()
		carry_on.text = keep_playing
		carry_on.custom_minimum_size = Vector2(220, 56)
		carry_on.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		carry_on.pressed.connect(func():
			layer.queue_free()
			Game.modal_open = false
			Game.clock_running = true
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED)
		column.add_child(carry_on)
	var again := Button.new()
	again.text = "Start again"
	again.custom_minimum_size = Vector2(220, 56)
	again.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	again.pressed.connect(func():
		Game.reset()
		get_tree().reload_current_scene())
	column.add_child(again)


# --- Building the world ---

func _build_sky() -> void:
	_sun = DirectionalLight3D.new()
	_sun.shadow_enabled = true
	add_child(_sun)
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.25, 0.45, 0.8)
	sky_material.sky_horizon_color = Color(0.7, 0.78, 0.9)
	sky_material.ground_horizon_color = Color(0.7, 0.78, 0.9)
	var sky := Sky.new()
	sky.sky_material = sky_material
	_environment = Environment.new()
	_environment.background_mode = Environment.BG_SKY
	_environment.sky = sky
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_environment.ambient_light_color = Color(0.55, 0.6, 0.75)
	_environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_environment := WorldEnvironment.new()
	world_environment.environment = _environment
	add_child(world_environment)


func _build_ground() -> void:
	_box(self, Vector3(0, -0.5, 0), Vector3(240, 1, 240), Color(0.55, 0.55, 0.5), true)       # pavement
	_box(self, Vector3(0, 0.02, 0), Vector3(240, 0.04, ROAD_HALF_WIDTH * 2), Color(0.2, 0.2, 0.22), false)  # main street
	_box(self, Vector3(0, 0.02, 0), Vector3(ROAD_HALF_WIDTH * 2, 0.04, 240), Color(0.2, 0.2, 0.22), false)  # cross street
	for i in range(-110, 111, 8):  # centre line dashes
		if absi(i) > 6:
			_box(self, Vector3(i, 0.05, 0), Vector3(3, 0.02, 0.2), Color(0.9, 0.9, 0.85), false)
			_box(self, Vector3(0, 0.05, i), Vector3(0.2, 0.02, 3), Color(0.9, 0.9, 0.85), false)
	# Invisible walls at the edge of the neighbourhood.
	for edge in [Vector3(115, 0, 0), Vector3(-115, 0, 0), Vector3(0, 0, 115), Vector3(0, 0, -115)]:
		var wall := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(2, 40, 240) if edge.x != 0 else Vector3(240, 40, 2)
		shape.shape = box
		wall.add_child(shape)
		wall.position = edge
		add_child(wall)


## Builds one building. A "lot" node sits at the front door, turned so that its
## own -Z points into the building; everything else is placed relative to it.
func _build_building(road: String, along: float, side: int, width: float, depth: float, height: float, color: Color, place: Dictionary) -> void:
	var lot := Node3D.new()
	if road == "main":
		lot.position = Vector3(along, 0, side * SETBACK)
		lot.rotation.y = 0.0 if side < 0 else PI
	else:
		lot.position = Vector3(side * SETBACK, 0, along)
		lot.rotation.y = PI / 2 if side < 0 else -PI / 2
	add_child(lot)

	_box(lot, Vector3(0, height / 2, -depth / 2), Vector3(width, height, depth), color, true)
	# Windows on the street side; they glow a little so the street has life at night.
	var columns := int(width / 3.5)
	for row in range(1, int(height / 3.2)):
		for column in columns:
			var x := (column - (columns - 1) / 2.0) * 3.5
			var lit := (int(along) + row * 7 + column * 13) % 3 != 0
			var window := _box(lot, Vector3(x, 1.5 + row * 3.2, 0.03), Vector3(1.4, 1.8, 0.06), Color(0.15, 0.18, 0.25), false)
			if lit:
				var material: StandardMaterial3D = window.material_override
				material.emission_enabled = true
				material.emission = Color(1.0, 0.85, 0.5)
				material.emission_energy_multiplier = 0.6

	if place.is_empty():
		return
	_box(lot, Vector3(0, 1.2, 0.05), Vector3(1.6, 2.4, 0.1), Color(0.25, 0.15, 0.1), false)  # door
	var sign := Label3D.new()
	sign.text = place.sign
	sign.font_size = 96
	sign.pixel_size = 0.012
	sign.outline_size = 24
	sign.position = Vector3(0, 3.3, 0.15)
	lot.add_child(sign)
	var doorstep := _trigger(lot, Vector3(0, 1.5, 2), Vector3(4, 3, 4), place.prompt, place.action)
	doorstep.set_meta("sign", place.sign)
	doorstep.set_meta("message", place.get("message", ""))
	if place.action == "flat":
		_flat_doors[place.sign] = doorstep


## The inside of the party flat: one room, coloured lights, six students.
func _build_party_room() -> void:
	var room := Node3D.new()
	room.position = PARTY_ROOM
	add_child(room)
	var wall := Color(0.3, 0.22, 0.3)
	_box(room, Vector3(0, -0.25, 0), Vector3(16, 0.5, 12), Color(0.35, 0.25, 0.18), true)   # floor
	_box(room, Vector3(0, 4.25, 0), Vector3(16, 0.5, 12), Color(0.2, 0.18, 0.2), true)      # ceiling
	_box(room, Vector3(0, 2, -6.25), Vector3(16.5, 4.5, 0.5), wall, true)
	_box(room, Vector3(0, 2, 6.25), Vector3(16.5, 4.5, 0.5), wall, true)
	_box(room, Vector3(-8.25, 2, 0), Vector3(0.5, 4.5, 12), wall, true)
	_box(room, Vector3(8.25, 2, 0), Vector3(0.5, 4.5, 12), wall, true)
	_box(room, Vector3(0, 1.2, 5.95), Vector3(1.6, 2.4, 0.1), Color(0.25, 0.15, 0.1), false)  # the way out
	_trigger(room, Vector3(0, 1.5, 5.2), Vector3(3, 3, 1.4), "Leave the party", "leave_party")
	_box(room, Vector3(-6, 0.5, -4.5), Vector3(3, 1, 1.2), Color(0.5, 0.2, 0.2), true)       # sofa
	_box(room, Vector3(5.5, 0.45, -4.8), Vector3(3.5, 0.9, 1), Color(0.25, 0.2, 0.15), true)  # drinks table
	for light in [[Vector3(-5, 3.5, -2), Color(1.0, 0.3, 0.6)], [Vector3(5, 3.5, -2), Color(0.3, 0.6, 1.0)], [Vector3(0, 3.5, 3), Color(1.0, 0.8, 0.4)]]:
		var lamp := OmniLight3D.new()
		lamp.position = light[0]
		lamp.light_color = light[1]
		lamp.light_energy = 3.0
		lamp.omni_range = 11.0
		room.add_child(lamp)

	var spots := [Vector3(-5.5, 0, -1.5), Vector3(-2.5, 0, -3.5), Vector3(1.5, 0, -3), Vector3(5, 0, -1.5), Vector3(-4, 0, 2), Vector3(4.5, 0, 2.5)]
	for i in Game.partygoers.size():
		var person := Game.partygoers[i]
		var spot: Vector3 = spots[i % spots.size()]
		var npc := StaticBody3D.new()
		npc.position = spot
		var shape := CollisionShape3D.new()
		var capsule := CapsuleShape3D.new()
		capsule.radius = 0.35
		capsule.height = 1.8
		shape.shape = capsule
		shape.position.y = 0.9
		npc.add_child(shape)
		var body := Body.build(CLOTHES[i % CLOTHES.size()], SKINS[Game.rng.randi() % SKINS.size()])
		body.rotation.y = atan2(spot.x, spot.z)  # face the middle of the room
		npc.add_child(body)
		var tag := Label3D.new()
		tag.text = person.name
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.font_size = 48
		tag.pixel_size = 0.006
		tag.outline_size = 12
		tag.position.y = 2.15
		npc.add_child(tag)
		room.add_child(npc)
		var reach := _trigger(npc, Vector3(0, 1, 0), Vector3(2.6, 2, 2.6), "Talk to %s" % person.name, "talk")
		reach.set_meta("person", person)


func _trigger(parent: Node3D, at: Vector3, size: Vector3, prompt: String, action: String) -> Area3D:
	var area := Area3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	area.add_child(shape)
	area.position = at
	area.set_meta("prompt", prompt)
	area.set_meta("action", action)
	parent.add_child(area)
	return area


func _build_lamp(at: Vector3) -> void:
	_box(self, at + Vector3(0, 2.5, 0), Vector3(0.15, 5, 0.15), Color(0.15, 0.15, 0.15), false)
	var lamp := OmniLight3D.new()
	lamp.position = at + Vector3(0, 5.2, 0)
	lamp.omni_range = 16.0
	lamp.light_energy = 2.5
	lamp.light_color = Color(1.0, 0.8, 0.55)
	add_child(lamp)
	_lamps.append(lamp)


func _box(parent: Node3D, at: Vector3, size: Vector3, color: Color, solid: bool) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	mesh_instance.material_override = material
	if solid:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		shape.shape = box
		body.add_child(shape)
		body.position = at
		body.add_child(mesh_instance)
		parent.add_child(body)
	else:
		mesh_instance.position = at
		parent.add_child(mesh_instance)
	return mesh_instance
