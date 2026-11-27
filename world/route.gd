class_name Route
extends Node
## Finds the way through the streets from the player to a place, for the dotted line on the map.
##
## The city is felt out in 4 m squares: a ray dropped from the sky lands on a roof or on the
## ground. Only the squares between the player and the place are looked at, a few each frame,
## and each one only once. The way through the open squares is then found with AStarGrid2D.

const CELL := 4.0
const EDGE := 3900.0                 # the squares cover the map from -EDGE to +EDGE
const SIDE := int(2 * EDGE / CELL)
const MARGIN := 220.0                # how far round the player and the place the search may wander
const BUDGET := 3000                 # microseconds of feeling out the city per frame
const STRAY := 30.0                  # metres off the line before a new way is looked for

## The way, from the player to the place, as (x, z) points. Empty while there is none.
var path := PackedVector2Array()
## Its length in metres.
var length := 0.0
## True while the way is still being worked out.
var searching := false
## Bodies the rays pass through: the player.
var skip: Array[RID] = []

var _cells := PackedByteArray()  # per square: 0 not looked at yet, 1 open, 2 built on
var _on := false
var _to := Vector2.ZERO
var _start := Vector2.ZERO
var _failed_at := Vector2.INF
var _box := Rect2i()
var _stage := 0  # 0 feeling out the squares, 1 filling the grid
var _i := 0
var _grid: AStarGrid2D
var _ray := PhysicsRayQueryParameters3D.new()


func _ready() -> void:
	_cells.resize(SIDE * SIDE)


## Call often with where the player is and where they are going.
func aim(from: Vector3, to: Vector3) -> void:
	var a := Vector2(from.x, from.z)
	var b := Vector2(to.x, to.z)
	if not _on or b.distance_to(_to) > 1.0:
		_on = true
		_to = b
		path = PackedVector2Array()
		length = 0.0
		_begin(a)
		return
	if searching:
		return
	if path.is_empty():
		# No way was found from there; try again once the player has moved on.
		if a.distance_to(_failed_at) > 60.0:
			_begin(a)
		return
	# Drop the part of the line already walked.
	var near := 0
	var near_d := INF
	for i in mini(path.size(), 60):
		var d := path[i].distance_to(a)
		if d < near_d:
			near_d = d
			near = i
	if near_d > STRAY:
		_begin(a)  # the old line stays up until the new one is ready
		return
	if near > 0:
		path = path.slice(near)
	path[0] = a
	_measure()


func clear() -> void:
	_on = false
	searching = false
	path = PackedVector2Array()
	length = 0.0


func _begin(from: Vector2) -> void:
	_start = from
	_failed_at = Vector2.INF
	var a := _cell(from)
	var b := _cell(_to)
	var grow := int(MARGIN / CELL)
	var box := Rect2i(mini(a.x, b.x), mini(a.y, b.y), absi(a.x - b.x) + 1, absi(a.y - b.y) + 1).grow(grow).intersection(Rect2i(0, 0, SIDE, SIDE))
	if _grid != null and _grid.region.encloses(box):
		searching = false
		_solve()
		return
	_box = box
	_stage = 0
	_i = 0
	searching = true


func _process(_delta: float) -> void:
	if not searching:
		return
	var began := Time.get_ticks_usec()
	var width := _box.size.x
	var count := width * _box.size.y
	if _stage == 0:
		var space := get_viewport().find_world_3d().direct_space_state
		_ray.exclude = skip
		var steps := 0
		while _i < count:
			var cx := _box.position.x + _i % width
			var cz := _box.position.y + _i / width
			_i += 1
			steps += 1
			var id := cz * SIDE + cx
			if _cells[id] == 0:
				var x := (cx + 0.5) * CELL - EDGE
				var z := (cz + 0.5) * CELL - EDGE
				_ray.from = Vector3(x, 400.0, z)
				_ray.to = Vector3(x, 0.6, z)
				_cells[id] = 1 if space.intersect_ray(_ray).is_empty() else 2
				steps += 60
			if steps > 1500:
				steps = 0
				if Time.get_ticks_usec() - began > BUDGET:
					return
		_grid = AStarGrid2D.new()
		_grid.region = _box
		_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
		_grid.update()
		_stage = 1
		_i = 0
		return
	var steps := 0
	while _i < count:
		var at := Vector2i(_box.position.x + _i % width, _box.position.y + _i / width)
		_i += 1
		steps += 1
		if _cells[at.y * SIDE + at.x] == 2:
			_grid.set_point_solid(at)
			# The squares along a wall cost more, so the line keeps to the middle of the street.
			for side in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if _box.has_point(at + side):
					_grid.set_point_weight_scale(at + side, 3.0)
			steps += 12
		if steps > 3000:
			steps = 0
			if Time.get_ticks_usec() - began > BUDGET:
				return
	searching = false
	_solve()


func _solve() -> void:
	# A door's nearest open square can be a closed courtyard behind its wall, so a few are tried.
	var cells: Array[Vector2i] = []
	for a in _open_near(_start, 2):
		for b in _open_near(_to, 4):
			cells = _grid.get_id_path(a, b)
			if not cells.is_empty():
				break
		if not cells.is_empty():
			break
	if cells.is_empty():
		path = PackedVector2Array()
		length = 0.0
		_failed_at = _start
		return
	var points := PackedVector2Array([_start])
	for cell in cells:
		points.append(Vector2((cell.x + 0.5) * CELL - EDGE, (cell.y + 0.5) * CELL - EDGE))
	points.append(_to)
	# Round off the staircase the squares make.
	for pass_ in 2:
		var smooth := points.duplicate()
		for i in range(1, points.size() - 1):
			smooth[i] = (points[i - 1] + points[i] * 2.0 + points[i + 1]) / 4.0
		points = smooth
	path = points
	_measure()


func _measure() -> void:
	length = 0.0
	for i in range(1, path.size()):
		length += path[i - 1].distance_to(path[i])


func _cell(at: Vector2) -> Vector2i:
	return Vector2i(clampi(int((at.x + EDGE) / CELL), 0, SIDE - 1), clampi(int((at.y + EDGE) / CELL), 0, SIDE - 1))


## The open squares nearest a spot, nearest first. A door stands right against its wall,
## so its own square may be built on.
func _open_near(spot: Vector2, wanted: int) -> Array[Vector2i]:
	var cell := _cell(spot)
	var found: Array[Vector2i] = []
	for dx in range(-4, 5):
		for dz in range(-4, 5):
			var at := cell + Vector2i(dx, dz)
			if _grid.region.has_point(at) and _cells[at.y * SIDE + at.x] == 1:
				found.append(at)
	var middle := func(c: Vector2i) -> Vector2: return Vector2((c.x + 0.5) * CELL - EDGE, (c.y + 0.5) * CELL - EDGE)
	found.sort_custom(func(p, q): return middle.call(p).distance_squared_to(spot) < middle.call(q).distance_squared_to(spot))
	return found.slice(0, wanted)
