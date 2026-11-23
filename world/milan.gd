class_name Milan
## The real streets and buildings of central Milan (Duomo and around, about 1.9 km
## across), made from OpenStreetMap by world/milan/build_map.py.
## Map data (c) OpenStreetMap contributors, ODbL.

const MODEL := "res://world/milan/milan.glb"
const INFO := "res://world/milan/places.json"

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
##   lamps: street lamp spots near the university
##   walls: the wall materials, for set_night()
static func build(parent: Node3D) -> Dictionary:
	var info: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(INFO))
	# Read straight from the file, so the game runs without opening the editor first.
	# ponytail: an exported build doesn't carry the .glb; load() the imported scene there.
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	document.append_from_file(MODEL, state)
	var city := document.generate_scene(state)
	parent.add_child(city)

	var shader := Shader.new()
	shader.code = WALL_SHADER
	var walls: Array[ShaderMaterial] = []
	for node in city.find_children("buildings*", "MeshInstance3D", true, false):
		var houses: MeshInstance3D = node
		houses.create_trimesh_collision()
		for surface in houses.mesh.get_surface_count():
			var original: BaseMaterial3D = houses.mesh.surface_get_material(surface)
			if original.resource_name.begins_with("wall"):
				var material := ShaderMaterial.new()
				material.shader = shader
				material.set_shader_parameter("wall", original.albedo_color)
				houses.set_surface_override_material(surface, material)
				walls.append(material)

	# The ground to stand on, and invisible walls where the map ends.
	var half := Vector2(info.half[0], info.half[1])
	Build.blocker(parent, Vector3(0, -0.5, 0), Vector3(half.x * 2, 1, half.y * 2))
	for edge in [Vector3(half.x, 20, 0), Vector3(-half.x, 20, 0)]:
		Build.blocker(parent, edge, Vector3(2, 40, half.y * 2))
	for edge in [Vector3(0, 20, half.y), Vector3(0, 20, -half.y)]:
		Build.blocker(parent, edge, Vector3(half.x * 2, 40, 2))
	return {"places": info.places, "lamps": info.lamps, "walls": walls}


## 0 by day, 1 at night: how brightly the lit windows shine.
static func set_night(walls: Array, amount: float) -> void:
	for material in walls:
		material.set_shader_parameter("night", amount)
