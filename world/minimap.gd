class_name Minimap
extends CanvasLayer
## A map in the corner of the screen: the real city seen from straight above,
## north up, with you in the middle. M makes it big and shows the names of the
## places you can go into. Under it: how far you are from the Duomo, which is
## the middle of the whole map, and what you should be doing now.
##
## Every place has its own badge. The place the quest sends you to wears a gold pin,
## and a dotted gold line follows the streets to it. When it is off the map, a gold
## arrow on the map's edge points its way.
##
## It is a second camera high over the player looking straight down, so it
## always shows exactly what is there: streets, roofs, parks, trees.

const SMALL := 460.0        # pixels across, in the corner
const BIG := 620.0          # pixels across, when opened with M
const SPAN_SMALL := 320.0   # metres of city across the small map
const SPAN_BIG := 1500.0    # metres of city across the big map
const REDRAW_EVERY := 0.25  # seconds between pictures; the arrow turns every frame regardless
const GOLD := Color(1.0, 0.8, 0.2)
## What each kind of place looks like on the map: the colour of its badge.
const BADGES := {
	"station": Color(0.24, 0.36, 0.6), "bank": Color(0.13, 0.5, 0.3), "university": Color(0.46, 0.3, 0.62),
	"shop": Color(0.82, 0.48, 0.12), "petrol": Color(0.72, 0.2, 0.2), "flat": Color(0.3, 0.33, 0.4),
	"party": Color(0.78, 0.25, 0.52), "home": Color(0.1, 0.52, 0.52),
}
const COMPASS := ["north", "north-east", "east", "south-east", "south", "south-west", "west", "north-west"]

## Set by the world every frame: where the player is on the streets (the door of
## the building, while indoors), and which way they face.
var focus := Vector3.ZERO
var facing := 0.0
## sign -> where its street door is. Set once by the world.
var places := {}
## sign -> which badge it wears (a key of BADGES). Set once by the world.
var icons := {}
## Finds the way along the streets to where the quest sends you.
var route := Route.new()

var _frame: Panel
var _view: SubViewport
var _camera: Camera3D
var _marks: Control
var _where: Label
var _tracker: PanelContainer
var _title: Label
var _goal: Label
var _note: Label
var _quest := {}
var _targets: Array = []  # the signs the quest sends you to
var _target := ""         # the nearest of them, where the dotted line leads
var _big := false
var _wait := 0.0


func _ready() -> void:
	layer = 2
	if not InputMap.has_action("map"):
		InputMap.add_action("map")
		var key := InputEventKey.new()
		key.physical_keycode = KEY_M
		InputMap.action_add_event("map", key)

	_view = SubViewport.new()
	_view.size = Vector2i(512, 512)
	_view.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(_view)
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.rotation = Vector3(-PI / 2, 0, 0)  # straight down, with north (-Z) at the top
	_camera.near = 1.0
	_camera.far = 1200.0
	# Its own flat light, so the map reads the same at midnight as at noon.
	var light := Environment.new()
	light.background_mode = Environment.BG_COLOR
	light.background_color = Color(0.25, 0.27, 0.3)
	light.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	light.ambient_light_color = Color.WHITE
	light.ambient_light_energy = 0.9
	_camera.environment = light
	_view.add_child(_camera)

	_frame = Panel.new()
	var border := StyleBoxFlat.new()
	border.bg_color = Color(0.05, 0.06, 0.08)
	border.set_border_width_all(3)
	border.border_color = Color(0.05, 0.06, 0.08, 0.9)
	border.set_corner_radius_all(6)
	_frame.add_theme_stylebox_override("panel", border)
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_frame)
	var picture := TextureRect.new()
	picture.texture = _view.get_texture()
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 3)
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.add_child(picture)
	_marks = Control.new()
	_marks.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marks.clip_contents = true
	_marks.draw.connect(_draw_marks)
	_frame.add_child(_marks)
	_where = Label.new()
	_where.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_where.add_theme_font_size_override("font_size", 15)
	_where.add_theme_color_override("font_outline_color", Color.BLACK)
	_where.add_theme_constant_override("outline_size", 5)
	add_child(_where)
	add_child(route)
	_build_tracker()
	_lay_out()
	get_viewport().size_changed.connect(_lay_out)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("map") and not Game.modal_open and not Game.phone_open:
		_big = not _big
		_wait = 0.0
		_lay_out()


func _process(delta: float) -> void:
	# The phone sits where the small map is; it wins.
	var shown := not Game.phone_open
	_frame.visible = shown
	_where.visible = shown
	_tracker.visible = shown
	if not shown:
		return
	_wait -= delta
	if _wait <= 0.0:
		_wait = REDRAW_EVERY
		_camera.size = _span()
		_camera.position = Vector3(focus.x, 700.0, focus.z)
		_view.render_target_update_mode = SubViewport.UPDATE_ONCE
		_where.text = _where_text()
		_track()
	_marks.queue_redraw()


func _span() -> float:
	return SPAN_BIG if _big else SPAN_SMALL


## Small in the top right corner, or big in the middle of the screen.
func _lay_out() -> void:
	var screen := get_viewport().get_visible_rect().size
	# Never taller than the window leaves room for.
	var side := minf(BIG if _big else SMALL, screen.y - 110.0)
	_frame.size = Vector2(side, side)
	_frame.position = (screen - _frame.size) / 2 - Vector2(0, 14) if _big else Vector2(screen.x - side - 16, 16)
	_where.size = Vector2(maxf(side, 260.0), 24)
	_where.position = _frame.position + Vector2((side - _where.size.x) / 2, side + 4)
	_tracker.size = Vector2(side, 0)
	_tracker.position = _frame.position + Vector2(0, side + 32)


## The quest tracker under the map: the quest's name, the next thing to do, and how far it is.
func _build_tracker() -> void:
	_tracker = PanelContainer.new()
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0.05, 0.06, 0.08, 0.72)
	back.set_corner_radius_all(6)
	back.border_width_left = 4
	back.border_color = GOLD
	back.set_content_margin_all(10)
	back.content_margin_left = 14
	_tracker.add_theme_stylebox_override("panel", back)
	_tracker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tracker)
	var lines := VBoxContainer.new()
	lines.add_theme_constant_override("separation", 2)
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tracker.add_child(lines)
	_title = _line(lines, 15, GOLD)
	_goal = _line(lines, 19, Color.WHITE)
	_note = _line(lines, 14, Color(0.78, 0.8, 0.84))


func _line(parent: Control, size: int, colour: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


## Works out what the quest is now, which of its places is nearest, and the way there.
func _track() -> void:
	_quest = Quests.now()
	_targets = _quest.places.filter(func(sign): return places.has(sign))
	_target = ""
	var here: bool = _targets.has(Game.inside)
	if not here:
		for sign in _targets:
			if _target == "" or focus.distance_to(places[sign]) < focus.distance_to(places[_target]):
				_target = sign
	_title.text = _quest.title.to_upper()
	_goal.text = _quest.goal
	var far := ""
	if here:
		far = "You are here."
		route.clear()
	elif _target == "":
		route.clear()
	else:
		route.aim(focus, places[_target])
		if focus.distance_to(places[_target]) < 12.0:
			far = "You are at the door."
		elif not route.path.is_empty():
			far ="%s on foot, along the dotted line." % _metres(route.length)
		elif route.searching:
			far = "%s away. Finding the way..." % _metres(focus.distance_to(places[_target]))
		else:
			far = "%s away, as the crow flies." % _metres(focus.distance_to(places[_target]))
	_note.text = (far + "\n" + _quest.note).strip_edges()
	_note.visible = _note.text != ""
	_tracker.size.y = 0


func _metres(distance: float) -> String:
	return "%.1f km" % (distance / 1000.0) if distance >= 950.0 else "%d m" % (int(round(distance / 10.0)) * 10)


## Where you are in words: the Duomo is the middle of the map, at (0, 0).
func _where_text() -> String:
	var from_duomo := Vector2(focus.x, focus.z)
	var hint := "   M: small map" if _big else "   M: big map"
	if from_duomo.length() < 150.0:
		return "At the Duomo" + hint
	# 0 is north, turning clockwise through east.
	var turn := fposmod(atan2(from_duomo.x, -from_duomo.y), TAU)
	var way: String = COMPASS[int(round(turn / (TAU / 8))) % 8]
	return "%.1f km %s of the Duomo%s" % [from_duomo.length() / 1000.0, way, hint]


## A point in the world as a spot on the map picture.
func _on_map(at: Vector3) -> Vector2:
	return _frame.size / 2 + Vector2(at.x - focus.x, at.z - focus.z) / _span() * _frame.size.x


func _draw_marks() -> void:
	var font := ThemeDB.fallback_font
	var inside := Rect2(Vector2.ZERO, _frame.size).grow(-8)
	_draw_route(inside)
	# The places you can go into: a badge each. The quest's places are drawn last, on top.
	var order := places.keys().filter(func(sign): return not _targets.has(sign)) + _targets
	var taken: Array[Rect2] = []  # where names already stand on the big map
	for sign in order:
		var spot := _on_map(places[sign])
		var wanted: bool = _targets.has(sign) and sign != Game.inside
		if not inside.has_point(spot):
			if sign == _target:
				_draw_pointer(spot)
			continue
		var kind: String = "home" if sign == Game.home else icons.get(sign, "flat")
		var size := 0.8 if _big else 1.0
		if wanted:
			# A gold ring that breathes, and a pin standing on the badge.
			var beat := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 260.0)
			_marks.draw_arc(spot, (15.0 + 4.0 * beat) * size, 0, TAU, 32, Color(GOLD, 0.9 - 0.5 * beat), 2.5, true)
		_draw_badge(spot, kind, size, wanted)
		if wanted:
			_draw_pin(spot + Vector2(0, -13.0 * size))
	if _big:
		# Names, the quest's first; one that would sit on top of another is left out.
		for sign in _targets + order:
			var spot := _on_map(places[sign])
			if not inside.has_point(spot):
				continue
			var name: String = sign.capitalize()
			var at := spot + Vector2(14, 5)
			var box := Rect2(at + Vector2(0, -13), font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, 14)).grow(2)
			if taken.any(func(other): return other.intersects(box)):
				continue
			taken.append(box)
			_marks.draw_string_outline(font, at, name, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 5, Color.BLACK)
			_marks.draw_string(font, at, name, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, GOLD if _targets.has(sign) else Color.WHITE)
	# You: an arrow in the middle, pointing the way you face.
	var middle := _frame.size / 2
	var arrow := PackedVector2Array([Vector2(0, -11), Vector2(8, 9), Vector2(0, 4), Vector2(-8, 9)])
	var outline := PackedVector2Array()
	var turned := PackedVector2Array()
	for point in arrow:
		# Facing 0 is north (up); turning left on the street is turning anticlockwise on the map.
		turned.append(middle + point.rotated(-facing))
		outline.append(middle + (point * 1.45).rotated(-facing))
	_marks.draw_colored_polygon(outline, Color.BLACK)
	_marks.draw_colored_polygon(turned, Color(0.25, 0.75, 1.0))
	# North.
	_marks.draw_string_outline(font, Vector2(_frame.size.x / 2 - 5, 18), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 5, Color.BLACK)
	_marks.draw_string(font, Vector2(_frame.size.x / 2 - 5, 18), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1.0, 0.4, 0.35))


## The way to the quest's place: gold dots along the streets. They are counted back from
## the place, so they stay put on the map as you walk.
func _draw_route(inside: Rect2) -> void:
	var path := route.path
	if path.size() < 2:
		return
	var gap := 10.0
	var carry := 0.0
	var scale := _frame.size.x / _span()
	var middle := _frame.size / 2 - Vector2(focus.x, focus.z) * scale
	var from := middle + path[path.size() - 1] * scale
	for i in range(path.size() - 2, -1, -1):
		var to := middle + path[i] * scale
		var run := from.distance_to(to)
		if run > 0.0 and (inside.has_point(from) or inside.has_point(to)):
			var along := gap - carry
			while along <= run:
				var dot := from.lerp(to, along / run)
				_marks.draw_circle(dot, 3.6, Color(0, 0, 0, 0.85))
				_marks.draw_circle(dot, 2.4, GOLD)
				along += gap
		carry = fmod(carry + run, gap)
		from = to


## The quest's place is off the map: a gold arrow on the edge points its way.
func _draw_pointer(spot: Vector2) -> void:
	var middle := _frame.size / 2
	var way := spot - middle
	var reach := middle - Vector2(20, 20)
	var at := middle + way * minf(reach.x / maxf(absf(way.x), 0.001), reach.y / maxf(absf(way.y), 0.001))
	var turn := way.angle() + PI / 2
	var shape := PackedVector2Array([Vector2(0, -13), Vector2(10, 8), Vector2(0, 3), Vector2(-10, 8)])
	var outline := PackedVector2Array()
	var turned := PackedVector2Array()
	for point in shape:
		turned.append(at + point.rotated(turn))
		outline.append(at + (point * 1.4).rotated(turn))
	_marks.draw_colored_polygon(outline, Color.BLACK)
	_marks.draw_colored_polygon(turned, GOLD)


## A gold pin with its point on the spot.
func _draw_pin(tip: Vector2) -> void:
	var head := tip + Vector2(0, -15)
	for layer in [[1.0, Color.BLACK], [0.0, GOLD]]:
		var grow: float = layer[0] * 2.0
		_marks.draw_colored_polygon(PackedVector2Array([tip + Vector2(0, grow * 1.5), head + Vector2(6.5 + grow, 2), head + Vector2(-6.5 - grow, 2)]), layer[1])
		_marks.draw_circle(head, 7.5 + grow, layer[1])
	_marks.draw_circle(head, 3.0, Color(0.1, 0.08, 0.02))


## A round badge with a small white picture of what the place is.
func _draw_badge(at: Vector2, kind: String, size: float, wanted: bool) -> void:
	var white := Color.WHITE
	var dark := Color(0.08, 0.09, 0.12)
	_marks.draw_circle(at, 13.0 * size, GOLD if wanted else dark)
	_marks.draw_circle(at, 11.0 * size, BADGES.get(kind, BADGES.flat))
	_marks.draw_set_transform(at, 0.0, Vector2(size, size))
	match kind:
		"station":  # the front of a train
			_marks.draw_rect(Rect2(-5.5, -7, 11, 11), white)
			_marks.draw_rect(Rect2(-4, -5.5, 3.2, 4), dark)
			_marks.draw_rect(Rect2(0.8, -5.5, 3.2, 4), dark)
			_marks.draw_circle(Vector2(-3.5, 6.5), 1.8, white)
			_marks.draw_circle(Vector2(3.5, 6.5), 1.8, white)
		"bank":  # a temple front: roof, columns, step
			_marks.draw_colored_polygon(PackedVector2Array([Vector2(-7.5, -2.5), Vector2(0, -8), Vector2(7.5, -2.5)]), white)
			for x in [-5.5, -1.2, 3.1]:
				_marks.draw_rect(Rect2(x, -1.5, 2.4, 6), white)
			_marks.draw_rect(Rect2(-7.5, 5.2, 15, 2.2), white)
		"university":  # a mortarboard
			_marks.draw_colored_polygon(PackedVector2Array([Vector2(0, -7), Vector2(9, -2.5), Vector2(0, 2), Vector2(-9, -2.5)]), white)
			_marks.draw_colored_polygon(PackedVector2Array([Vector2(-5, 1.5), Vector2(0, 4), Vector2(5, 1.5), Vector2(5, 5), Vector2(0, 7.5), Vector2(-5, 5)]), white)
		"shop":  # a basket
			_marks.draw_colored_polygon(PackedVector2Array([Vector2(-7.5, -1), Vector2(7.5, -1), Vector2(5, 7), Vector2(-5, 7)]), white)
			_marks.draw_polyline(PackedVector2Array([Vector2(-4.5, -1), Vector2(-2.5, -7), Vector2(2.5, -7), Vector2(4.5, -1)]), white, 2.0, true)
		"petrol":  # a drop
			_marks.draw_circle(Vector2(0, 2.5), 5.2, white)
			_marks.draw_colored_polygon(PackedVector2Array([Vector2(0, -8), Vector2(4.6, 0.5), Vector2(-4.6, 0.5)]), white)
		"party":  # a note of music
			_marks.draw_circle(Vector2(-2.5, 4.5), 3.4, white)
			_marks.draw_line(Vector2(0.2, 4.5), Vector2(0.2, -7), white, 2.0, true)
			_marks.draw_colored_polygon(PackedVector2Array([Vector2(0.2, -7.5), Vector2(6, -5), Vector2(6, -1.5), Vector2(0.2, -4)]), white)
		_:  # a house
			_marks.draw_colored_polygon(PackedVector2Array([Vector2(-8, -1), Vector2(0, -8), Vector2(8, -1)]), white)
			_marks.draw_rect(Rect2(-5.5, -1, 11, 7.5), white)
			_marks.draw_rect(Rect2(-1.5, 2, 3, 4.5), BADGES.get(kind, BADGES.flat))
	_marks.draw_set_transform(Vector2.ZERO)
