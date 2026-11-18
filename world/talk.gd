class_name Talk
extends CanvasLayer
## Talking to someone face to face: the same conversation as texting, shown as
## speech bubbles, and more likely to go your way.

var _panel: PanelContainer
var _name: Label
var _their_line: Label
var _your_line: Label
var _box: LineEdit
var _person: Person
var _busy := false


func _ready() -> void:
	layer = 6
	_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.09, 0.12, 0.92)
	style.set_corner_radius_all(16)
	style.set_content_margin_all(16)
	_panel.add_theme_stylebox_override("panel", style)
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = -380
	_panel.offset_right = 380
	_panel.offset_top = -270
	_panel.offset_bottom = -30
	add_child(_panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	_panel.add_child(column)
	_name = Label.new()
	_name.add_theme_font_size_override("font_size", 22)
	_name.add_theme_color_override("font_color", Color(1.0, 0.85, 0.5))
	column.add_child(_name)
	_their_line = _line(column, 20)
	_their_line.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_your_line = _line(column, 16)
	_your_line.modulate = Color(0.6, 0.85, 0.65)

	var row := HBoxContainer.new()
	column.add_child(row)
	_box = LineEdit.new()
	_box.placeholder_text = "Say something…"
	_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_box.text_submitted.connect(_say)
	row.add_child(_box)
	var say := Button.new()
	say.text = "Say"
	say.pressed.connect(func(): _say(_box.text))
	row.add_child(say)
	var leave := Button.new()
	leave.text = "Walk away (Esc)"
	leave.pressed.connect(close)
	row.add_child(leave)
	_panel.visible = false


func _line(parent: Control, size: int) -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size)
	parent.add_child(label)
	return label


func is_open() -> bool:
	return _panel.visible


func open(person: Person) -> void:
	_person = person
	_name.text = person.name
	_your_line.text = ""
	if person.history.is_empty():
		# The first hello is written by the game so every introduction is clear.
		person.history.append({"from": "person", "text": "hey! i'm %s. you new here?" % person.name})
	_their_line.text = _last_from_them()
	_panel.visible = true
	Game.modal_open = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_box.placeholder_text = "Say something…" if Game.llm_ready else "They can't hear you over the music yet…"
	_box.grab_focus()


func close() -> void:
	if _busy:
		return
	_panel.visible = false
	Game.modal_open = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	get_viewport().gui_release_focus()


func _input(event: InputEvent) -> void:
	if _panel.visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func _say(text: String) -> void:
	text = text.strip_edges()
	if _busy or text.is_empty() or not Game.llm_ready:
		return
	_busy = true
	_box.clear()
	_your_line.text = "You: " + text
	_their_line.text = "…"
	_their_line.text = await Game.send(_person, text, true)
	_busy = false
	_box.grab_focus()


func _last_from_them() -> String:
	for i in range(_person.history.size() - 1, -1, -1):
		if _person.history[i].from == "person":
			return _person.history[i].text
	return ""
