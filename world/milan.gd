class_name Milan
## The real streets and buildings of Milan in a circle round the Duomo, 3.8 km out:
## from Stazione Centrale to Corvetto, CityLife to the Politecnico. Made by world/milan/build_map.py
## from the Comune's topographic database, a laser survey, an aerial photo and OpenStreetMap: see CREDITS.md.
## The city comes in 300 m chunks; only those within the camera's reach are drawn.

const MODEL := "res://world/milan/milan.glb.zst"
const INFO := "res://world/milan/places.json"
const TREES := "res://world/milan/trees.bin"
const CHUNK := 300.0  # metres: trees are grouped like the city, so only those near the camera are drawn

const NOISE := "
float random(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(random(i), random(i + vec2(1, 0)), f.x), mix(random(i + vec2(0, 1)), random(i + vec2(1, 1)), f.x), f.y);
}
float box(vec2 p, vec2 lo, vec2 hi) { return step(lo.x, p.x) * step(p.x, hi.x) * step(lo.y, p.y) * step(p.y, hi.y); }
"

## A Milanese façade, drawn on a flat wall: a stone ground floor of shops, then plastered floors with a window
## in every bay, stone surrounds, shutters, balconies on some, a cornice under the roof. Towers are glass;
## churches, the castle and the Duomo are bare brick or marble with tall windows.
## The model gives each wall UV = (window bays across, 1 - metres above the street) and
## UV2 = (the top of the building, 1 - tag), tag = a number 0..1 that picks the building's looks,
## + 2 if the wall stands against a neighbour and so has no windows, + 4 for a glass tower, + 8 for a monument.
const WALL_SHADER := "
shader_type spatial;
uniform vec3 wall : source_color;
uniform float night = 0.0;
varying vec3 at;
void vertex() {
	at = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
%s
void fragment() {
	float h = 1.0 - UV.y;
	float top = UV2.x;
	float tag = 1.0 - UV2.y;
	float seed = fract(tag);
	float open = 1.0 - mod(floor(tag * 0.5), 2.0);
	float style = floor(tag * 0.25);
	float storey = 3.1 + 0.5 * fract(seed * 7.13);
	float shop = 4.0 + 0.8 * fract(seed * 3.71);
	float bay = fract(UV.x);
	float column = floor(UV.x);
	float grime = 0.5 * noise(at.xz * 0.7 + at.y * 0.3) + 0.5 * noise(vec2(UV.x * 3.0, h * 0.15));
	vec3 colour = wall * (0.86 + 0.18 * grime);
	vec3 far = colour * 0.8;   // what the wall looks like from too far away to make out its windows
	float rough = 0.92;
	float glass = 0.0;
	float lit = 0.0;
	if (style > 1.5) {
		// Brick or marble in courses, a tall window in every other bay.
		colour *= 1.0 - 0.18 * step(fract(h / 0.45), 0.08) - 0.08 * step(fract(UV.x * 9.0 + floor(h / 0.45) * 0.5), 0.06);
		float window = box(vec2(bay, mod(h, 9.0)), vec2(0.4, 3.0), vec2(0.6, 7.5)) * step(0.5, mod(column, 2.0)) * step(h, top - 2.0) * open;
		colour = mix(colour, vec3(0.1, 0.1, 0.12), window);
		lit = window * 0.4;
		far = colour;
	} else if (style > 0.5) {
		// Glass and thin mullions, floor after floor.
		vec2 g = vec2(fract(UV.x * 2.0), fract(h / 3.4));
		glass = box(g, vec2(0.05, 0.1), vec2(0.95, 0.95));
		colour = mix(wall * 0.5, vec3(0.13, 0.18, 0.23) + 0.05 * grime, glass);
		rough = mix(0.5, 0.35, glass);
		lit = glass * step(0.72, random(vec2(floor(UV.x * 2.0), floor(h / 3.4)) + seed));
		far = vec3(0.16, 0.2, 0.25);
	} else if (h < shop) {
		// Stone, with a shop window, a pulled-down shutter or a wooden door in each bay.
		colour = vec3(0.55, 0.53, 0.5) * (0.82 + 0.22 * grime) * (1.0 - 0.25 * step(fract(h / 0.55), 0.06));
		far = colour * 0.6;
		float opening = box(vec2(bay, h), vec2(0.17, 0.0), vec2(0.83, shop - 0.75)) * open;
		float kind = random(vec2(column, seed * 91.0));
		vec3 inside = kind < 0.25 ? vec3(0.45, 0.45, 0.47) * (0.85 + 0.15 * step(0.5, fract(h * 4.0)))
			: kind < 0.38 ? vec3(0.24, 0.14, 0.08) : vec3(0.04, 0.05, 0.06);
		colour = mix(colour, inside, opening);
		glass = opening * step(0.38, kind);
		rough = mix(rough, 0.45, glass);
		lit = glass * 1.4;
	} else {
		vec2 cell = vec2(bay, mod(h - shop, storey));
		float level = floor((h - shop) / storey);
		float window = box(cell, vec2(0.36, 0.9), vec2(0.64, 2.5)) * open;
		float surround = box(cell, vec2(0.32, 0.78), vec2(0.68, 2.68)) * open - window;
		float shutters = step(0.3, seed) * open * box(cell, vec2(0.2, 0.9), vec2(0.8, 2.5)) * (1.0 - window - surround);
		float closed = step(0.8, random(vec2(column, level) + seed));
		vec3 shutter = seed < 0.62 ? vec3(0.16, 0.24, 0.16) : vec3(0.32, 0.21, 0.12);
		colour = mix(colour, vec3(0.8, 0.77, 0.7) * (0.9 + 0.1 * grime), surround);
		colour = mix(colour, shutter * (0.85 + 0.15 * step(0.5, fract(cell.y * 12.0))), max(shutters, window * closed));
		glass = window * (1.0 - closed);
		colour = mix(colour, vec3(0.05, 0.06, 0.08), glass);
		rough = mix(rough, 0.45, glass);
		lit = glass * step(0.7, random(vec2(column, level) + seed * 13.0));
		float balcony = step(0.55, fract(seed * 5.3)) * step(0.5, level) * open;
		colour = mix(colour, vec3(0.5, 0.5, 0.48), balcony * box(cell, vec2(0.0), vec2(1.0, 0.18)));
		float rail = box(cell, vec2(0.0, 0.18), vec2(1.0, 1.12)) * step(0.72, fract(UV.x * 24.0)) + box(cell, vec2(0.0, 1.06), vec2(1.0, 1.14));
		colour = mix(colour, vec3(0.07), balcony * min(rail, 1.0));
		float band = step(h, shop + 0.35) + step(top - 0.7, h);
		colour = mix(colour, vec3(0.8, 0.77, 0.7) * (0.9 + 0.1 * grime), min(band, 1.0));
		colour *= 1.0 - 0.35 * step(top - 0.95, h) * step(h, top - 0.7);
		far = mix(colour, far, open);
	}
	// Far off, a window is smaller than a pixel: show the wall's average instead of flickering dots.
	float blur = smoothstep(0.12, 0.35, max(fwidth(UV.x), fwidth(h) / storey));
	ALBEDO = mix(colour, far, blur);
	ROUGHNESS = mix(rough, 0.9, blur);
	EMISSION = vec3(1.0, 0.8, 0.45) * lit * night * 0.9;
}
" % NOISE

## Roofs: rows of terracotta coppi where they slope, a weathered surface where they are flat. The roof's colour
## comes from the aerial photo. The mesh shares corners between triangles, so each face's slope is worked out here.
const ROOF_SHADER := "
shader_type spatial;
uniform vec3 roof : source_color;
varying vec3 at;
void vertex() {
	at = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
%s
void fragment() {
	vec3 n = normalize(cross(dFdy(at), dFdx(at)));
	n *= sign(n.y + 0.0001);
	NORMAL = (VIEW_MATRIX * vec4(n, 0.0)).xyz;
	vec2 down = normalize(n.xz + vec2(0.0001));
	vec2 across = vec2(-down.y, down.x);
	vec2 tile = vec2(dot(at.xz, across) / 0.22, dot(at.xz, down) / 0.36);
	float coppi = (0.72 + 0.28 * sin(fract(tile.x) * 6.2832)) * (1.0 - 0.3 * step(0.86, fract(tile.y)));
	float blur = smoothstep(0.2, 0.6, max(fwidth(tile.x), fwidth(tile.y)));   // tiles smaller than a pixel: their average
	vec3 sloped = roof * mix(coppi * (0.85 + 0.3 * random(floor(tile))), 0.86, blur);
	vec3 level = roof * (0.78 + 0.3 * noise(at.xz * 0.8)) * (0.92 + 0.08 * noise(at.xz * 9.0));
	ALBEDO = mix(level, sloped, step(0.08, length(n.xz)));
	ROUGHNESS = 0.9;
}
" % NOISE


## Adds the city to the world. Returns:
##   places: sign -> {x, z, yaw} of that door on a real wall (its own -Z points into the building)
##   lamps: street lamp spots near the station
##   walls: the wall materials, for set_night()
static func build(parent: Node3D) -> Dictionary:
	var info: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(INFO))
	# Unpacked and read straight from the file, so the game runs without opening the editor first.
	# ponytail: an exported build doesn't carry the file; add *.zst to the export filter then.
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	document.append_from_buffer(FileAccess.get_file_as_bytes(MODEL).decompress(info.model_bytes, FileAccess.COMPRESSION_ZSTD), "", state)
	var city := document.generate_scene(state)
	parent.add_child(city)

	var shaders := {"wall": Shader.new(), "roof": Shader.new()}
	shaders.wall.code = WALL_SHADER
	shaders.roof.code = ROOF_SHADER
	var made := {}  # material name -> its shader material, shared by every chunk of the city
	for node in city.find_children("buildings*", "MeshInstance3D", true, false) + city.find_children("roofs*", "MeshInstance3D", true, false):
		var houses: MeshInstance3D = node
		houses.create_trimesh_collision()
		for surface in houses.mesh.get_surface_count():
			var original: BaseMaterial3D = houses.mesh.surface_get_material(surface)
			var kind := original.resource_name.get_slice("_", 0)
			if not shaders.has(kind):
				continue
			if not made.has(original.resource_name):
				var material := ShaderMaterial.new()
				material.shader = shaders[kind]
				material.set_shader_parameter(kind, original.albedo_color)
				made[original.resource_name] = material
			houses.set_surface_override_material(surface, made[original.resource_name])
	var walls := made.keys().filter(func(name): return name.begins_with("wall")).map(func(name): return made[name])
	# Streets, paving and grass are matt: without this they shine like wet glass when looked along.
	for node in city.find_children("*", "MeshInstance3D", true, false):
		if not node.name.begins_with("buildings") and not node.name.begins_with("roofs") and not node.name.begins_with("water"):
			for surface in node.mesh.get_surface_count():
				var ground: BaseMaterial3D = node.mesh.surface_get_material(surface)
				ground.roughness = 1.0
				ground.metallic_specular = 0.15

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
	return {"places": info.places, "lamps": info.lamps, "walls": walls}


## Stands a tree on every spot in trees.bin (x, z, metres tall, ...): the trees the Comune mapped, as tall as
## the laser survey saw them. Each chunk's trees are one MultiMesh.
## ponytail: trees have no collision, you walk through the trunks; add a capsule per tree near the player if that matters.
static func _plant(parent: Node3D) -> void:
	var spots := FileAccess.get_file_as_bytes(TREES).to_float32_array()
	var chunks := {}
	for i in range(0, spots.size(), 3):
		chunks.get_or_add(Vector2i(floori(spots[i] / CHUNK), floori(spots[i + 1] / CHUNK)), []).append(Vector3(spots[i], spots[i + 2], spots[i + 1]))
	var tree := _tree()
	for key in chunks:
		var grove := MultiMesh.new()
		grove.transform_format = MultiMesh.TRANSFORM_3D
		grove.mesh = tree
		grove.instance_count = chunks[key].size()
		for i in grove.instance_count:
			var spot: Vector3 = chunks[key][i]
			var size := spot.y / 7.0   # the model is 7 m tall
			grove.set_instance_transform(i, Transform3D(Basis(Vector3.UP, spot.x + spot.z).scaled(Vector3.ONE * size), Vector3(spot.x, 0, spot.z)))
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
