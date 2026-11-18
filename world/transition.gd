class_name Transition
extends CanvasLayer
## Fades the screen to black and back, and shows time passing as a rolling clock
## so that hours never jump abruptly.

var _black: ColorRect
var _clock: Label
var _caption: Label


func _ready() -> void:
	layer = 15
	_black = ColorRect.new()
	_black.color = Color(0, 0, 0, 0)
	_black.set_anchors_preset(Control.PRESET_FULL_RECT)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_black)
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_black.add_child(column)
	_clock = _label(column, 72)
	_caption = _label(column, 24)
	_clock.modulate.a = 0.0
	_caption.modulate.a = 0.0


func _label(parent: Control, size: int) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	parent.add_child(label)
	return label


## Fades to black (darkness 1) or back to the game (darkness 0).
func fade(darkness: float, seconds: float) -> void:
	var tween := create_tween()
	tween.tween_property(_black, "color:a", darkness, seconds)
	await tween.finished


## With the screen dark, rolls the clock forward by some in-game minutes.
func roll_clock(game_minutes: int, seconds: float, caption: String) -> void:
	_caption.text = caption
	var from := Game.day * 1440.0 + Game.minutes
	var appear := create_tween().set_parallel()
	appear.tween_property(_clock, "modulate:a", 1.0, 0.4)
	appear.tween_property(_caption, "modulate:a", 0.8, 0.4)
	var roll := create_tween()
	roll.tween_method(_set_time, from, from + game_minutes, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await roll.finished
	_set_time(from + game_minutes)
	await get_tree().create_timer(0.6).timeout
	var vanish := create_tween().set_parallel()
	vanish.tween_property(_clock, "modulate:a", 0.0, 0.4)
	vanish.tween_property(_caption, "modulate:a", 0.0, 0.4)
	await vanish.finished


func _set_time(total: float) -> void:
	Game.day = int(total / 1440.0)
	Game.minutes = fmod(total, 1440.0)
	_clock.text = "Day %d   %s" % [Game.day, Game.clock_text()]
