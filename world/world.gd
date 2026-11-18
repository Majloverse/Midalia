extends Node3D
## Step 2 of the build order: one small neighbourhood to walk around.
## Everything is built from simple blocks here; proper models replace them later.
##
## Two streets cross in the middle. Each place sits on the "main" street (runs
## east-west) or the "cross" street (runs north-south): `along` is how far down
## that street, `side` is which side of it (-1 or 1).

const ROAD_HALF_WIDTH := 5.0
const SETBACK := 8.0  # distance from the street's centre line to building fronts

const PLACES := [
	{"sign": "STAZIONE CENTRALE", "road": "main", "along": -70, "side": -1, "width": 30, "depth": 16, "height": 12,
		"color": Color(0.75, 0.7, 0.6), "prompt": "Enter the station", "message": "Nothing for you here. You just got off the train."},
	{"sign": "BANCA", "road": "main", "along": 28, "side": -1, "width": 16, "depth": 12, "height": 10,
		"color": Color(0.8, 0.8, 0.75), "prompt": "Enter the bank", "message": "The bank is open 9:00 to 16:00. Opening an account comes in a later step."},
	{"sign": "UNIVERSITÀ", "road": "main", "along": 70, "side": 1, "width": 34, "depth": 20, "height": 14,
		"color": Color(0.7, 0.55, 0.45), "prompt": "Enter the university", "message": "School hasn't started yet."},
	{"sign": "VIA ROMA 12", "road": "main", "along": -22, "side": 1, "width": 14, "depth": 12, "height": 18,
		"color": Color(0.85, 0.65, 0.4), "prompt": "Ring the bell", "message": "The party starts at 21:00. It comes in a later step."},
	{"sign": "VIA VERDI 3", "road": "cross", "along": 40, "side": 1, "width": 12, "depth": 12, "height": 15,
		"color": Color(0.8, 0.5, 0.45), "prompt": "Ring the bell", "message": "Student flat. Nobody you know lives here yet."},
	{"sign": "VIA DANTE 7", "road": "cross", "along": -45, "side": -1, "width": 12, "depth": 12, "height": 15,
		"color": Color(0.6, 0.7, 0.6), "prompt": "Ring the bell", "message": "Student flat. Nobody you know lives here yet."},
	{"sign": "VIA MILANO 21", "road": "cross", "along": 75, "side": -1, "width": 12, "depth": 12, "height": 15,
		"color": Color(0.65, 0.65, 0.8), "prompt": "Ring the bell", "message": "Student flat. Nobody you know lives here yet."},
]
## Buildings you can't enter: [road, along, side, width, height]
const FILLERS := [
	["main", -45, -1, 16, 14], ["main", -22, -1, 18, 20], ["main", 50, -1, 18, 16], ["main", 76, -1, 20, 12],
	["main", -48, 1, 20, 13], ["main", -75, 1, 18, 17], ["main", 26, 1, 22, 15],
	["cross", 58, 1, 14, 12], ["cross", -65, 1, 16, 16], ["cross", -70, -1, 14, 13], ["cross", 95, 1, 16, 18],
	["cross", 52, -1, 14, 14], ["cross", -42, 1, 14, 17],
]
const FILLER_COLORS := [Color(0.72, 0.68, 0.62), Color(0.78, 0.7, 0.58), Color(0.66, 0.62, 0.6), Color(0.8, 0.74, 0.66)]

var _sun: DirectionalLight3D
var _environment: Environment
var _sky: ProceduralSkyMaterial
var _lamps: Array[OmniLight3D] = []
var _hud: Hud


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

	_hud = Hud.new()
	add_child(_hud)
	var player := Player.new()
	player.position = Vector3(-70, 0.1, -3)
	add_child(player)
	player.prompt_changed.connect(_hud.set_prompt)
	player.message.connect(_hud.show_message)
	_hud.show_message("You just landed in Milan. The party is at Via Roma 12.")


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


func _build_sky() -> void:
	_sun = DirectionalLight3D.new()
	_sun.shadow_enabled = true
	add_child(_sun)
	_sky = ProceduralSkyMaterial.new()
	_sky.sky_top_color = Color(0.25, 0.45, 0.8)
	_sky.sky_horizon_color = Color(0.7, 0.78, 0.9)
	_sky.ground_horizon_color = Color(0.7, 0.78, 0.9)
	var sky := Sky.new()
	sky.sky_material = _sky
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
	var doorstep := Area3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4, 3, 4)
	shape.shape = box
	doorstep.add_child(shape)
	doorstep.position = Vector3(0, 1.5, 2)
	doorstep.set_meta("prompt", place.prompt)
	doorstep.set_meta("message", place.message)
	lot.add_child(doorstep)


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
