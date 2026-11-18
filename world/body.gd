class_name Body
## Builds the placeholder block people. Real character models replace this later.


## A simple standing person, facing -Z.
static func build(clothes: Color, skin: Color) -> Node3D:
	var body := Node3D.new()
	add_part(body, CapsuleMesh.new(), Vector3(0, 0.75, 0), Vector3(0.7, 1.5, 0.5), clothes)       # torso and legs
	add_part(body, SphereMesh.new(), Vector3(0, 1.62, 0), Vector3(0.36, 0.4, 0.36), skin)        # head
	add_part(body, BoxMesh.new(), Vector3(0, 1.62, -0.19), Vector3(0.08, 0.08, 0.1), skin.darkened(0.15))  # nose, shows facing
	return body


static func add_part(body: Node3D, mesh: Mesh, at: Vector3, size: Vector3, color: Color) -> void:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.position = at
	# Primitive meshes are 1 m wide (capsules 2 m tall), so scale to the wanted size.
	part.scale = size / (Vector3(1, 2, 1) if mesh is CapsuleMesh else Vector3.ONE)
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	part.material_override = material
	body.add_child(part)
