class_name Player
extends CharacterBody3D
## The wanderer. WASD to walk, Shift to run, Space to jump, mouse to look, E to use doors.
## A placeholder body for now; the real character model comes later.

signal prompt_changed(text: String)
signal message(text: String)

var _yaw := PI  # start facing away from the station, down the street
var _pitch := -0.25
var _pivot: Node3D
var _body: Node3D
var _nearby: Array[Area3D] = []


func _ready() -> void:
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	shape.shape = capsule
	shape.position.y = 0.9
	add_child(shape)

	_body = Node3D.new()
	_body.rotation.y = _yaw
	add_child(_body)
	_add_part(CapsuleMesh.new(), Vector3(0, 0.75, 0), Vector3(0.7, 1.5, 0.5), Color(0.2, 0.3, 0.6))    # torso and legs
	_add_part(SphereMesh.new(), Vector3(0, 1.62, 0), Vector3(0.36, 0.4, 0.36), Color(0.9, 0.72, 0.6))  # head
	_add_part(BoxMesh.new(), Vector3(0, 1.62, -0.19), Vector3(0.08, 0.08, 0.1), Color(0.8, 0.6, 0.5))  # nose, shows facing
	_add_part(BoxMesh.new(), Vector3(0, 1.1, 0.3), Vector3(0.45, 0.55, 0.2), Color(0.5, 0.15, 0.15))   # backpack

	_pivot = Node3D.new()
	_pivot.position.y = 1.6
	add_child(_pivot)
	var arm := SpringArm3D.new()
	arm.spring_length = Settings.CAMERA_DISTANCE
	arm.margin = 0.2
	arm.add_excluded_object(get_rid())
	_pivot.add_child(arm)
	var camera := Camera3D.new()
	camera.far = 500.0
	arm.add_child(camera)
	camera.make_current()

	var sensor := Area3D.new()
	var sensor_shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.6
	sensor_shape.shape = sphere
	sensor_shape.position.y = 0.9
	sensor.add_child(sensor_shape)
	sensor.area_entered.connect(_on_area.bind(true))
	sensor.area_exited.connect(_on_area.bind(false))
	add_child(sensor)

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _add_part(mesh: Mesh, at: Vector3, size: Vector3, color: Color) -> void:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.position = at
	# Primitive meshes are 1 m wide (capsules and spheres 2 m tall), so scale to the wanted size.
	part.scale = size / (Vector3(1, 2, 1) if mesh is CapsuleMesh else Vector3.ONE)
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	part.material_override = material
	_body.add_child(part)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_yaw -= event.relative.x * Settings.MOUSE_SENSITIVITY
		_pitch = clampf(_pitch - event.relative.y * Settings.MOUSE_SENSITIVITY, -1.2, 0.5)
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed("interact") and not _nearby.is_empty():
		message.emit(_nearby[-1].get_meta("message"))


func _physics_process(delta: float) -> void:
	_pivot.rotation = Vector3(_pitch, _yaw, 0)

	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := Vector3(input.x, 0, input.y).rotated(Vector3.UP, _yaw)
	var speed: float = Settings.RUN_SPEED if Input.is_action_pressed("run") else Settings.WALK_SPEED
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	if is_on_floor():
		if Input.is_action_just_pressed("jump"):
			velocity.y = Settings.JUMP_SPEED
	else:
		velocity.y -= Settings.GRAVITY * delta
	move_and_slide()

	if direction.length() > 0.1:
		var target := atan2(-direction.x, -direction.z)
		_body.rotation.y = lerp_angle(_body.rotation.y, target, minf(1.0, delta * 10.0))


func _on_area(area: Area3D, entered: bool) -> void:
	if not area.has_meta("prompt"):
		return
	if entered:
		_nearby.append(area)
	else:
		_nearby.erase(area)
	prompt_changed.emit("" if _nearby.is_empty() else "E  " + str(_nearby[-1].get_meta("prompt")))
