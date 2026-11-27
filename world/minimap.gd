class_name Minimap
extends CanvasLayer
## A map in the corner of the screen: the real city seen from straight above,
## north up, with you in the middle. M makes it big and shows the names of the
## places you can go into. Under it: how far you are from the Duomo, which is
## the middle of the whole map.
##
## It is a second camera high over the player looking straight down, so it
## always shows exactly what is there: streets, roofs, parks, trees.

const SMALL := 460.0        # pixels across, in the corner
const BIG := 620.0          # pixels across, when opened with M
const SPAN_SMALL := 320.0   # metres of city across the small map
const SPAN_BIG := 1500.0    # metres of city across the big map
const REDRAW_EVERY := 0.25  # seconds between pictures; the arrow turns every frame regardless
const COMPASS := ["north", "north-east", "east", "south-east", "south", "south-west", "west", "north-west"]

## Set by the world every frame: where the player is on the streets (the door of
## the building, while indoors), and which way they face.
var focus := Vector3.ZERO
var facing := 0.0
## sign -> where its street door is. Set once by the world.
var places := {}

var _frame: Panel
var _view: SubViewport
var _camera: Camera3D
var _marks: Control
var _where: Label
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
	if not shown:
		return
	_wait -= delta
	if _wait <= 0.0:
		_wait = REDRAW_EVERY
		_camera.size = _span()
		_camera.position = Vector3(focus.x, 700.0, focus.z)
		_view.render_target_update_mode = SubViewport.UPDATE_ONCE
		_where.text = _where_text()
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
	# The places you can go into: a dot each, and their names on the big map.
	for sign in places:
		var spot := _on_map(places[sign])
		if not Rect2(Vector2.ZERO, _frame.size).grow(-6).has_point(spot):
			continue
		_marks.draw_circle(spot, 5.0, Color.BLACK)
		_marks.draw_circle(spot, 3.5, Color(1.0, 0.8, 0.2))
		if _big:
			var name: String = sign.capitalize()
			_marks.draw_string_outline(font, spot + Vector2(8, 5), name, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 5, Color.BLACK)
			_marks.draw_string(font, spot + Vector2(8, 5), name, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
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
