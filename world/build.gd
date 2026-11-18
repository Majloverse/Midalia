class_name Build
## Small helpers for making the block world.


## A coloured box. Solid ones can be walked into; the rest are decoration.
static func box(parent: Node3D, at: Vector3, size: Vector3, color: Color, solid: bool = false) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	if color.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh_instance.material_override = material
	if solid:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = size
		shape.shape = box_shape
		body.add_child(shape)
		body.position = at
		body.add_child(mesh_instance)
		parent.add_child(body)
	else:
		mesh_instance.position = at
		parent.add_child(mesh_instance)
	return mesh_instance


## Makes a box glow, for screens, windows and lamps.
static func glow(mesh_instance: MeshInstance3D, color: Color, energy: float = 1.0) -> void:
	var material: StandardMaterial3D = mesh_instance.material_override
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy


## An invisible zone that shows a prompt and does something when the player presses E in it.
static func trigger(parent: Node3D, at: Vector3, size: Vector3, prompt: String, action: String) -> Area3D:
	var area := Area3D.new()
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	area.add_child(shape)
	area.position = at
	area.set_meta("prompt", prompt)
	area.set_meta("action", action)
	parent.add_child(area)
	return area


static func light(parent: Node3D, at: Vector3, color: Color, energy: float, reach: float) -> OmniLight3D:
	var lamp := OmniLight3D.new()
	lamp.position = at
	lamp.light_color = color
	lamp.light_energy = energy
	lamp.omni_range = reach
	parent.add_child(lamp)
	return lamp


static func sign(parent: Node3D, at: Vector3, text: String, size: int, yaw: float = 0.0, color: Color = Color.WHITE) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font_size = size
	label.pixel_size = 0.006
	label.outline_size = size / 5
	label.modulate = color
	label.position = at
	label.rotation.y = yaw
	parent.add_child(label)
	return label


## A standing block person with a solid body. Faces `yaw`.
static func person(parent: Node3D, at: Vector3, yaw: float, clothes: Color, skin: Color) -> StaticBody3D:
	var npc := StaticBody3D.new()
	npc.position = at
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	shape.shape = capsule
	shape.position.y = 0.9
	npc.add_child(shape)
	var body := Body.build(clothes, skin)
	body.rotation.y = yaw
	npc.add_child(body)
	parent.add_child(npc)
	return npc
