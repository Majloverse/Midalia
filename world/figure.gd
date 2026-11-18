class_name Figure
extends Node3D
## A person: head with a face and hair, torso, jointed arms and legs. Walks,
## idles and dances with stiff, slightly goofy movement. Faces -Z, feet at the origin.
## Still made of simple shapes; a proper character model can replace this later.

## How fast the person is moving: 0 standing, 1 walking, 2 running.
var walk := 0.0
## "idle", "dance" or "still" (frozen, for lying down).
var mood := "idle"

var _time := 0.0
var _phase := 0.0
var _amount := 0.0
var _offset := 0.0  # so a room full of people doesn't move in unison
var _hips: Node3D
var _head: Node3D
var _torso: Node3D
var _arms: Array[Node3D] = []
var _elbows: Array[Node3D] = []
var _legs: Array[Node3D] = []
var _knees: Array[Node3D] = []


func setup(look: Dictionary) -> void:
	var skin: Color = look.skin
	var shirt: Color = look.shirt
	var trousers: Color = look.trousers
	_offset = look.get("offset", 0.0)
	_hips = Node3D.new()
	add_child(_hips)

	# Legs: thigh, knee, shin, shoe.
	for side in [-1.0, 1.0]:
		var hip := _limb(_hips, Vector3(side * 0.095, 0.92, 0), 0.44, 0.08, 0.062, trousers)
		var knee := _limb(hip, Vector3(0, -0.44, 0), 0.42, 0.06, 0.048, trousers)
		_shape(knee, BoxMesh.new(), Vector3(0, -0.44, -0.05), Vector3(0.1, 0.08, 0.26), look.shoes)
		_legs.append(hip)
		_knees.append(knee)

	# Pelvis and torso. The torso widens to the shoulders and is flatter front to back.
	_shape(_hips, CylinderMesh.new(), Vector3(0, 0.98, 0), Vector3(0.34, 0.2, 0.22), trousers)
	_torso = Node3D.new()
	_torso.position = Vector3(0, 1.06, 0)
	_hips.add_child(_torso)
	var chest := CylinderMesh.new()
	chest.top_radius = 0.2
	chest.bottom_radius = 0.16
	chest.height = 0.5
	_shape(_torso, chest, Vector3(0, 0.25, 0), Vector3(1.0, 1.0, 0.62), shirt)
	_shape(_torso, SphereMesh.new(), Vector3(0, 0.47, 0), Vector3(0.46, 0.14, 0.24), shirt)   # shoulders
	_shape(_torso, CylinderMesh.new(), Vector3(0, 0.55, 0), Vector3(0.1, 0.1, 0.1), skin)     # neck

	# Arms: sleeve, elbow, bare forearm, hand.
	for side in [-1.0, 1.0]:
		var shoulder := _limb(_torso, Vector3(side * 0.235, 0.45, 0), 0.3, 0.055, 0.045, shirt)
		var elbow := _limb(shoulder, Vector3(0, -0.3, 0), 0.26, 0.042, 0.035, skin)
		_shape(elbow, SphereMesh.new(), Vector3(0, -0.3, 0), Vector3(0.085, 0.1, 0.07), skin)
		shoulder.rotation.z = side * 0.08
		_arms.append(shoulder)
		_elbows.append(elbow)

	# Head, with a face you can read from across a room.
	_head = Node3D.new()
	_head.position = Vector3(0, 0.6, 0)
	_torso.add_child(_head)
	_shape(_head, SphereMesh.new(), Vector3(0, 0.12, 0), Vector3(0.22, 0.27, 0.235), skin)
	for side in [-1.0, 1.0]:
		_shape(_head, SphereMesh.new(), Vector3(side * 0.043, 0.135, -0.095), Vector3(0.056, 0.056, 0.03), Color(0.97, 0.97, 0.95))  # eye
		_shape(_head, SphereMesh.new(), Vector3(side * 0.043, 0.135, -0.108), Vector3(0.026, 0.026, 0.012), Color(0.08, 0.06, 0.05))  # pupil
		var brow := _shape(_head, BoxMesh.new(), Vector3(side * 0.045, 0.18, -0.104), Vector3(0.055, 0.012, 0.012), look.hair.darkened(0.3))
		brow.rotation.z = side * look.get("brows", 0.0)
		_shape(_head, SphereMesh.new(), Vector3(side * 0.112, 0.12, 0.0), Vector3(0.035, 0.06, 0.04), skin)  # ear
	_shape(_head, SphereMesh.new(), Vector3(0, 0.1, -0.118), Vector3(0.036, 0.05, 0.04), skin.darkened(0.08))  # nose
	_shape(_head, BoxMesh.new(), Vector3(0, 0.045, -0.105), Vector3(0.06 + look.get("smile", 0.0) * 0.03, 0.014, 0.012), Color(0.45, 0.15, 0.15))  # mouth
	_hair(look.get("hair_style", 0), look.hair)

	var build: float = look.get("build", 1.0)
	scale = Vector3(build, look.get("height", 1.0), build)


func add_backpack(color: Color) -> void:
	_shape(_torso, BoxMesh.new(), Vector3(0, 0.26, 0.2), Vector3(0.32, 0.42, 0.16), color)
	_shape(_torso, BoxMesh.new(), Vector3(0, 0.2, 0.3), Vector3(0.22, 0.2, 0.05), color.darkened(0.25))


func _process(delta: float) -> void:
	if mood == "still":
		return
	_time += delta
	_amount = lerpf(_amount, clampf(walk, 0.0, 2.0), minf(1.0, delta * 8.0))
	var stride := minf(_amount, 1.0)
	if _amount > 0.02:
		_phase += delta * (5.5 + 3.5 * _amount)

	if mood == "dance" and stride < 0.1:
		var beat := _time * 6.0 + _offset
		_hips.position.y = absf(sin(beat)) * 0.05
		_hips.rotation.y = sin(beat * 0.5) * 0.3
		_arms[0].rotation.x = 2.3 + sin(beat) * 0.45
		_arms[1].rotation.x = sin(beat + PI) * 0.7
		_elbows[0].rotation.x = 0.6
		_elbows[1].rotation.x = 0.9
		_knees[0].rotation.x = -maxf(0.0, sin(beat)) * 0.5
		_knees[1].rotation.x = -maxf(0.0, -sin(beat)) * 0.5
		_legs[0].rotation.x = maxf(0.0, sin(beat)) * 0.25
		_legs[1].rotation.x = maxf(0.0, -sin(beat)) * 0.25
		_head.rotation = Vector3(sin(beat) * 0.15, 0, 0)
		return

	# Walking: legs swing opposite each other, arms opposite the legs, a little bounce.
	var swing := sin(_phase) * 0.7 * stride
	_hips.position.y = absf(sin(_phase)) * 0.035 * stride
	_hips.rotation.y = 0.0
	for i in 2:
		var direction := 1.0 if i == 0 else -1.0
		_legs[i].rotation.x = swing * direction
		_knees[i].rotation.x = -maxf(0.0, sin(_phase * direction + 1.9)) * 1.0 * stride
		_arms[i].rotation.x = -swing * direction * 0.8 + sin(_time * 1.4 + _offset + i) * 0.03
		_elbows[i].rotation.x = 0.15 + 0.5 * stride
	# Standing around: look about a bit.
	_head.rotation = Vector3(0, sin(_time * 0.5 + _offset) * 0.3 * (1.0 - stride), 0)


func _hair(style: int, color: Color) -> void:
	if style == 3:  # shaved
		_shape(_head, SphereMesh.new(), Vector3(0, 0.135, 0.008), Vector3(0.222, 0.25, 0.236), color.lerp(Color(0.5, 0.4, 0.35), 0.5))
		return
	_shape(_head, SphereMesh.new(), Vector3(0, 0.16, 0.022), Vector3(0.24, 0.25, 0.25), color)  # the top and back
	match style:
		1:  # long
			_shape(_head, BoxMesh.new(), Vector3(0, 0.0, 0.085), Vector3(0.22, 0.34, 0.09), color)
			for side in [-1.0, 1.0]:
				_shape(_head, BoxMesh.new(), Vector3(side * 0.105, 0.03, 0.02), Vector3(0.04, 0.26, 0.12), color)
		2:  # bun
			_shape(_head, SphereMesh.new(), Vector3(0, 0.3, 0.05), Vector3(0.11, 0.1, 0.11), color)
		4:  # mop with a fringe
			_shape(_head, BoxMesh.new(), Vector3(0, 0.215, -0.08), Vector3(0.2, 0.06, 0.08), color)
			_shape(_head, SphereMesh.new(), Vector3(0, 0.24, 0.0), Vector3(0.27, 0.14, 0.27), color)


## A limb segment hanging down from a joint. Returns the joint so it can be rotated.
func _limb(parent: Node3D, at: Vector3, length: float, top: float, bottom: float, color: Color) -> Node3D:
	var joint := Node3D.new()
	joint.position = at
	parent.add_child(joint)
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = length
	mesh.radial_segments = 12
	_shape(joint, mesh, Vector3(0, -length / 2, 0), Vector3.ONE, color)
	_shape(joint, SphereMesh.new(), Vector3.ZERO, Vector3.ONE * top * 2.0, color)  # rounds off the joint
	return joint


func _shape(parent: Node3D, mesh: Mesh, at: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.position = at
	# Spheres and plain cylinders start 1 m across (cylinders 2 m tall), so `size` is the real size.
	if mesh is SphereMesh:
		part.scale = size
	elif mesh is BoxMesh:
		part.scale = size
	elif mesh is CylinderMesh and is_equal_approx(mesh.height, 2.0):
		part.scale = Vector3(size.x, size.y / 2.0, size.z)
	else:
		part.scale = size
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.85
	part.material_override = material
	parent.add_child(part)
	return part
