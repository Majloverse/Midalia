class_name Milan
## The real streets and buildings of Milan in a circle round the Duomo, 3.8 km out:
## from Stazione Centrale to Corvetto, CityLife to the Politecnico. Made from
## OpenStreetMap by world/milan/build_map.py.
## The city comes in 300 m chunks; only those within the camera's reach are drawn.
## Map data (c) OpenStreetMap contributors, ODbL.

const MODEL := "res://world/milan/milan.glb.gz"
const INFO := "res://world/milan/places.json"
const TREES := "res://world/milan/trees.bin"
const CHUNK := 300.0  # metres: trees are grouped like the city, so only those near the camera are drawn

## House walls: flat colour with rows of windows drawn on, some of them lit at night.
const WALL_SHADER := "
shader_type spatial;
uniform vec3 wall : source_color;
uniform float night = 0.0;
varying vec3 at;
varying vec3 facing;
void vertex() {
	at = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	facing = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
float random(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void fragment() {
	vec2 along = normalize(vec2(-facing.z, facing.x) + vec2(0.0001));
	vec2 cell = vec2(dot(at.xz, along) / 3.2, (at.y - 0.7) / 3.3);  // one window per 3.2 m, one floor per 3.3 m
	vec2 f = fract(cell);
	float window = step(0.28, f.x) * step(f.x, 0.72) * step(0.25, f.y) * step(f.y, 0.8) * step(0.7, at.y);
	float lit = window * step(0.7, random(floor(cell) + floor(facing.xz * 7.0)));
	float ledge = 1.0 - 0.18 * step(f.y, 0.05);
	ALBEDO = mix(wall * ledge, vec3(0.07, 0.09, 0.13), window);
	ROUGHNESS = mix(0.9, 0.25, window);
	EMISSION = vec3(1.0, 0.8, 0.45) * lit * night * 0.9;
}
"


## Adds the city to the world. Returns:
##   places: sign -> {x, z, yaw} of that door on a real wall (its own -Z points into the building)
##   lamps: street lamp spots near the station
##   walls: the wall materials, for set_night()
static func build(parent: Node3D) -> Dictionary:
	var info: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(INFO))
	# Unpacked and read straight from the file, so the game runs without opening the editor first.
	# ponytail: an exported build doesn't carry the file; add *.gz to the export filter then.
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	document.append_from_buffer(FileAccess.get_file_as_bytes(MODEL).decompress_dynamic(-1, FileAccess.COMPRESSION_GZIP), "", state)
	var city := document.generate_scene(state)
	parent.add_child(city)

	var shader := Shader.new()
	shader.code = WALL_SHADER
	var walls := {}  # wall colour -> its material, shared by every chunk of the city
	for node in city.find_children("buildings*", "MeshInstance3D", true, false):
		var houses: MeshInstance3D = node
		houses.create_trimesh_collision()
		for surface in houses.mesh.get_surface_count():
			var original: BaseMaterial3D = houses.mesh.surface_get_material(surface)
			if original.resource_name.begins_with("wall"):
				if not walls.has(original.resource_name):
					var material := ShaderMaterial.new()
					material.shader = shader
					material.set_shader_parameter("wall", original.albedo_color)
					walls[original.resource_name] = material
				houses.set_surface_override_material(surface, walls[original.resource_name])

	_plant(parent)

	# The ground to stand on, and invisible walls where the map ends.
	var radius: float = info.radius
	Build.blocker(parent, Vector3(0, -0.5, 0), Vector3(radius * 2, 1, radius * 2))
	var walls_round := 90
	for i in walls_round:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(TAU * radius / walls_round + 4, 40, 2)
		shape.shape = box
		body.add_child(shape)
		body.rotation.y = -i * TAU / walls_round + PI / 2
		body.position = Vector3(cos(i * TAU / walls_round), 0, sin(i * TAU / walls_round)) * (radius - 2) + Vector3(0, 20, 0)
		parent.add_child(body)
	return {"places": info.places, "lamps": info.lamps, "walls": walls.values()}


## Stands a tree on every spot in trees.bin (x, z, x, z, ...). Each chunk's trees are one MultiMesh.
## ponytail: trees have no collision, you walk through the trunks; add a capsule per tree near the player if that matters.
static func _plant(parent: Node3D) -> void:
	var spots := FileAccess.get_file_as_bytes(TREES).to_float32_array()
	var chunks := {}
	for i in range(0, spots.size(), 2):
		chunks.get_or_add(Vector2i(floori(spots[i] / CHUNK), floori(spots[i + 1] / CHUNK)), []).append(Vector3(spots[i], 0, spots[i + 1]))
	var tree := _tree()
	for key in chunks:
		var grove := MultiMesh.new()
		grove.transform_format = MultiMesh.TRANSFORM_3D
		grove.mesh = tree
		grove.instance_count = chunks[key].size()
		for i in grove.instance_count:
			var at: Vector3 = chunks[key][i]
			var size := 0.7 + 0.6 * fposmod(at.x * 12.9898 + at.z * 78.233, 1.0)   # the same tree is the same size every time
			grove.set_instance_transform(i, Transform3D(Basis(Vector3.UP, at.x + at.z).scaled(Vector3.ONE * size), at))
		var instance := MultiMeshInstance3D.new()
		instance.multimesh = grove
		parent.add_child(instance)


## One simple tree, about 7 m tall: a trunk and a round crown.
static func _tree() -> ArrayMesh:
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.15
	trunk.bottom_radius = 0.22
	trunk.height = 2.8
	trunk.radial_segments = 5
	trunk.rings = 1
	var crown := SphereMesh.new()
	crown.radius = 2.3
	crown.height = 4.8
	crown.radial_segments = 7
	crown.rings = 4
	var mesh := ArrayMesh.new()
	for part in [[trunk, 1.4, Color(0.33, 0.24, 0.16)], [crown, 4.6, Color(0.17, 0.38, 0.15)]]:
		var tool := SurfaceTool.new()
		tool.append_from(part[0], 0, Transform3D(Basis(), Vector3(0, part[1], 0)))
		var material := StandardMaterial3D.new()
		material.albedo_color = part[2]
		tool.set_material(material)
		tool.commit(mesh)
	return mesh


## 0 by day, 1 at night: how brightly the lit windows shine.
static func set_night(walls: Array, amount: float) -> void:
	for material in walls:
		material.set_shader_parameter("night", amount)
