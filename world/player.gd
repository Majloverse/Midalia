class_name Player
extends CharacterBody3D
## The wanderer. WASD to walk, Shift to run, Space to jump, mouse to look, E to use things.
## A placeholder body for now; the real character model comes later.

signal prompt_changed(text: String)
signal interacted(area: Area3D)

var _yaw := PI  # start facing away from the station, down the street
var _pitch := -0.25
var _pivot: Node3D
var _body: Node3D
var _nearby: Array[Area3D] = []
var _lying := false
var _arm: SpringArm3D


func _ready() -> void:
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	shape.shape = capsule
	shape.position.y = 0.9
	add_child(shape)

	_body = Body.build(Color(0.2, 0.3, 0.6), Color(0.9, 0.72, 0.6))
	_body.rotation.y = _yaw
	add_child(_body)
	Body.add_part(_body, BoxMesh.new(), Vector3(0, 1.1, 0.3), Vector3(0.45, 0.55, 0.2), Color(0.5, 0.15, 0.15))  # backpack

	_pivot = Node3D.new()
	_pivot.position.y = 1.6
	add_child(_pivot)
	var arm := SpringArm3D.new()
	_arm = arm
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


func _busy() -> bool:
	return Game.phone_open or Game.modal_open


## Moves the player somewhere else at once, facing the given direction.
func teleport(to: Vector3, yaw: float) -> void:
	position = to
	_nearby.clear()
	prompt_changed.emit("")
	velocity = Vector3.ZERO
	_yaw = yaw
	_body.rotation.y = yaw


## How far behind the player the camera sits. Rooms need it closer than streets.
func set_camera_distance(distance: float) -> void:
	_arm.spring_length = distance


## Which way the body is facing.
func facing() -> float:
	return _body.rotation.y


## Lies down with feet at `at` and head pointing along `yaw`.
func lie_down(at: Vector3, yaw: float) -> void:
	_lying = true
	velocity = Vector3.ZERO
	var tween := create_tween().set_parallel()
	tween.tween_property(_body, "global_position", at, 0.9).set_trans(Tween.TRANS_SINE)
	tween.tween_property(_body, "rotation", Vector3(-PI / 2, yaw, 0), 0.9).set_trans(Tween.TRANS_SINE)
	await tween.finished


func stand_up() -> void:
	var tween := create_tween().set_parallel()
	tween.tween_property(_body, "position", Vector3.ZERO, 0.9).set_trans(Tween.TRANS_SINE)
	tween.tween_property(_body, "rotation", Vector3(0, _body.rotation.y, 0), 0.9).set_trans(Tween.TRANS_SINE)
	await tween.finished
	_lying = false


## Call after something a nearby door says has changed.
func refresh_prompt() -> void:
	prompt_changed.emit("" if _nearby.is_empty() else "E  " + str(_nearby[-1].get_meta("prompt")))


func _unhandled_input(event: InputEvent) -> void:
	if _busy():
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_yaw -= event.relative.x * Settings.MOUSE_SENSITIVITY
		_pitch = clampf(_pitch - event.relative.y * Settings.MOUSE_SENSITIVITY, -1.2, 0.5)
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed("interact") and not _nearby.is_empty():
		interacted.emit(_nearby[-1])


func _physics_process(delta: float) -> void:
	_pivot.rotation = Vector3(_pitch, _yaw, 0)

	if _lying:
		return
	var input := Vector2.ZERO if _busy() else Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := Vector3(input.x, 0, input.y).rotated(Vector3.UP, _yaw)
	var speed: float = Settings.RUN_SPEED if Input.is_action_pressed("run") else Settings.WALK_SPEED
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	if is_on_floor():
		if Input.is_action_just_pressed("jump") and not _busy():
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
	refresh_prompt()
