class_name Hud
extends CanvasLayer
## What's always on screen while walking: wellbeing, cash and the clock.

var _stats: Label
var _prompt: Label
var _message: Label
var _message_time := 0.0


func _ready() -> void:
	_stats = _label(Control.PRESET_TOP_LEFT, 26)
	_stats.position = Vector2(20, 14)
	_prompt = _label(Control.PRESET_CENTER_BOTTOM, 24)
	_prompt.position.y -= 150
	_message = _label(Control.PRESET_CENTER_BOTTOM, 22)
	_message.position.y -= 90
	var help := _label(Control.PRESET_BOTTOM_LEFT, 15)
	help.position = Vector2(20, -40)
	help.text = "WASD walk   Shift run   Space jump   Mouse look   E use   Tab phone   Esc free the mouse"
	help.modulate.a = 0.7
	Game.minute_passed.connect(_refresh)
	_refresh()


func _process(delta: float) -> void:
	_refresh()
	if _message_time > 0.0:
		_message_time -= delta
		if _message_time <= 0.0:
			_message.text = ""


func set_prompt(text: String) -> void:
	_prompt.text = text


func show_message(text: String) -> void:
	_message.text = text
	_message_time = 5.0


func _refresh() -> void:
	_stats.text = "Day %d   %s\nWellbeing %d%%\nCash %d euro" % [Game.day, Game.clock_text(), Game.wellbeing, Game.cash]


func _label(preset: Control.LayoutPreset, size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if preset == Control.PRESET_CENTER_BOTTOM else HORIZONTAL_ALIGNMENT_LEFT
	add_child(label)
	label.set_anchors_and_offsets_preset(preset)
	label.grow_horizontal = Control.GROW_DIRECTION_BOTH if preset == Control.PRESET_CENTER_BOTTOM else Control.GROW_DIRECTION_END
	label.grow_vertical = Control.GROW_DIRECTION_BEGIN if preset != Control.PRESET_TOP_LEFT else Control.GROW_DIRECTION_END
	return label
