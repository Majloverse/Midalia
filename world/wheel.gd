class_name WheelScreen
extends CanvasLayer
## A wheel the player spins themselves. The result is decided before the spin;
## the wheel only reveals it. Used when you pass out on the street.

signal _spin_pressed
signal _continue_pressed

var _wheel: _WheelDrawing
var _title: Label
var _result: Label
var _button: Button
var _dim: ColorRect


func _ready() -> void:
	layer = 20
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.85)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_dim)
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 14)
	_dim.add_child(column)

	_title = _label(column, 30)
	_wheel = _WheelDrawing.new()
	_wheel.custom_minimum_size = Vector2(380, 400)
	_wheel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(_wheel)
	_result = _label(column, 26)
	_button = Button.new()
	_button.custom_minimum_size = Vector2(220, 56)
	_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_button.add_theme_font_size_override("font_size", 24)
	_button.pressed.connect(func():
		if _button.text == "SPIN":
			_spin_pressed.emit()
		else:
			_continue_pressed.emit())
	column.add_child(_button)
	_dim.visible = false


func _label(parent: Control, size: int) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	parent.add_child(label)
	return label


## Shows a wheel, waits for the player to spin it, lands on `winner` (an index
## into `labels`) and waits for the player to continue.
func spin(title: String, labels: Array, colors: Array, winner: int, result_text: String) -> void:
	_title.text = title
	_result.text = " "
	_button.text = "SPIN"
	_button.disabled = false
	_wheel.labels = labels
	_wheel.colors = colors
	_wheel.turn = 0.0
	_wheel.queue_redraw()
	_dim.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_button.grab_focus()
	await _spin_pressed

	_button.disabled = true
	# Land somewhere inside the winning segment, after several full turns.
	var segment := TAU / labels.size()
	var landing := (winner + randf_range(0.15, 0.85)) * segment
	var tween := create_tween()
	tween.tween_property(_wheel, "turn", TAU * 6 - landing, 4.5).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	await tween.finished

	_result.text = result_text
	_button.text = "Continue"
	_button.disabled = false
	_button.grab_focus()
	await _continue_pressed
	_dim.visible = false


class _WheelDrawing extends Control:
	var labels: Array = []
	var colors: Array = []
	var turn := 0.0:
		set(value):
			turn = value
			queue_redraw()

	func _draw() -> void:
		if labels.is_empty():
			return
		var centre := size / 2 + Vector2(0, 10)
		var radius := minf(size.x, size.y) / 2 - 24
		var segment := TAU / labels.size()
		var font := get_theme_default_font()
		for i in labels.size():
			var points := PackedVector2Array([centre])
			for step in 25:
				points.append(centre + _at(i * segment + segment * step / 24.0 + turn) * radius)
			draw_colored_polygon(points, colors[i % colors.size()])
			# Label, written along the middle of the segment.
			var middle := (i + 0.5) * segment + turn
			draw_set_transform(centre + _at(middle) * radius * 0.62, middle, Vector2.ONE)
			var text := str(labels[i])
			var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
			draw_string(font, Vector2(-width / 2, 8), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		draw_arc(centre, radius, 0, TAU, 96, Color(0.9, 0.9, 0.9), 4.0)
		draw_circle(centre, 14, Color(0.9, 0.9, 0.9))
		# The pointer at the top.
		var tip := centre + Vector2(0, -radius + 18)
		draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-14, -34), tip + Vector2(14, -34)]), Color(1.0, 0.85, 0.2))

	## Direction for an angle measured clockwise from straight up.
	func _at(angle: float) -> Vector2:
		return Vector2(sin(angle), -cos(angle))
