class_name Phone
extends CanvasLayer
## The budget phone. Tab opens and closes it. The clock keeps running while it's open.
## Apps: Chats, Bank, University, Notebook.

const BG := Color(0.09, 0.1, 0.13)
const BAR := Color(0.14, 0.16, 0.2)
const MINE := Color(0.16, 0.42, 0.3)
const THEIRS := Color(0.2, 0.22, 0.27)

var _frame: PanelContainer
var _title: Label
var _clock: Label
var _back: Button
var _content: VBoxContainer
var _screen := "home"
var _person: Person
var _busy := false
var _chat_box: VBoxContainer
var _chat_scroll: ScrollContainer
var _message_box: LineEdit


func _ready() -> void:
	layer = 5
	_frame = PanelContainer.new()
	_frame.add_theme_stylebox_override("panel", _style(BG, 28, 12))
	_frame.custom_minimum_size = Vector2(380, 640)
	# Pinned to the right edge, centred vertically.
	_frame.anchor_left = 1.0
	_frame.anchor_right = 1.0
	_frame.anchor_top = 0.5
	_frame.anchor_bottom = 0.5
	_frame.offset_left = -420
	_frame.offset_right = -40
	_frame.offset_top = -320
	_frame.offset_bottom = 320
	add_child(_frame)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	_frame.add_child(column)

	var bar := HBoxContainer.new()
	column.add_child(bar)
	_back = Button.new()
	_back.text = " < "
	_back.flat = true
	_back.pressed.connect(_go_back)
	bar.add_child(_back)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 20)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(_title)
	_clock = Label.new()
	_clock.modulate.a = 0.7
	bar.add_child(_clock)

	_content = VBoxContainer.new()
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 8)
	column.add_child(_content)

	var hint := Label.new()
	hint.text = "Tab to put the phone away"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.modulate.a = 0.5
	hint.add_theme_font_size_override("font_size", 13)
	column.add_child(hint)

	Game.minute_passed.connect(func(): _clock.text = Game.clock_text())
	_clock.text = Game.clock_text()
	_frame.visible = false


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("phone") and not Game.modal_open:
		get_viewport().set_input_as_handled()
		toggle()


func toggle() -> void:
	Game.phone_open = not Game.phone_open
	_frame.visible = Game.phone_open
	if Game.phone_open:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_show(_screen)
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().gui_release_focus()


func _go_back() -> void:
	_show("chats" if _screen == "chat" else "home")


func _show(screen: String) -> void:
	_screen = screen
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	_back.visible = screen != "home"
	match screen:
		"home": _home()
		"chats": _chats()
		"chat": _chat()
		"bank": _bank()
		"university": _university()
		"notebook": _notebook()


# --- Home ---

func _home() -> void:
	_title.text = "  Phone"
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	_content.add_child(grid)
	for app in [["Chats", "chats", Color(0.15, 0.5, 0.3)], ["Bank", "bank", Color(0.2, 0.35, 0.6)],
			["University", "university", Color(0.55, 0.25, 0.25)], ["Notebook", "notebook", Color(0.55, 0.45, 0.2)]]:
		var button := Button.new()
		button.text = app[0]
		button.custom_minimum_size = Vector2(170, 110)
		button.add_theme_font_size_override("font_size", 20)
		button.add_theme_stylebox_override("normal", _style(app[2], 18, 8))
		button.add_theme_stylebox_override("hover", _style(app[2].lightened(0.15), 18, 8))
		button.add_theme_stylebox_override("pressed", _style(app[2].darkened(0.2), 18, 8))
		button.pressed.connect(_show.bind(app[1]))
		grid.add_child(button)
	_text("Street cred: %d" % Game.street_cred, 18)


# --- Chats ---

func _chats() -> void:
	_title.text = "Chats"
	for person in Game.contacts:
		var button := Button.new()
		var last: String = "" if person.history.is_empty() else person.history[-1].text
		button.text = "  %s\n  %s" % [person.name, last.left(40)]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size.y = 58
		button.add_theme_stylebox_override("normal", _style(BAR, 12, 6))
		button.pressed.connect(func():
			_person = person
			_show("chat"))
		_content.add_child(button)


func _chat() -> void:
	_title.text = _person.name
	_chat_scroll = ScrollContainer.new()
	_chat_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_chat_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_content.add_child(_chat_scroll)
	_chat_box = VBoxContainer.new()
	_chat_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chat_box.add_theme_constant_override("separation", 6)
	_chat_scroll.add_child(_chat_box)
	for line in _person.history:
		_bubble(line.text, line.from == "player")

	var row := HBoxContainer.new()
	_content.add_child(row)
	_message_box = LineEdit.new()
	_message_box.placeholder_text = "Message" if Game.llm_ready else "No signal yet…"
	_message_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_message_box.text_submitted.connect(_send)
	row.add_child(_message_box)
	var send := Button.new()
	send.text = "Send"
	send.pressed.connect(func(): _send(_message_box.text))
	row.add_child(send)
	_message_box.grab_focus()
	_scroll_down()


func _send(text: String) -> void:
	text = text.strip_edges()
	if _busy or text.is_empty() or not Game.llm_ready:
		return
	_busy = true
	_message_box.clear()
	var person := _person
	_bubble(text, true)
	var typing := _bubble("…", false)
	var reply: String = await Game.send(person, text, false)
	_busy = false
	# The player may have left this chat while the reply was being written.
	if is_instance_valid(typing):
		typing.queue_free()
		if _screen == "chat" and _person == person:
			_bubble(reply, false)


func _bubble(text: String, mine: bool) -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END if mine else BoxContainer.ALIGNMENT_BEGIN
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(MINE if mine else THEIRS, 12, 8))
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = minf(260.0, 14.0 + text.length() * 8.5)
	panel.add_child(label)
	row.add_child(panel)
	_chat_box.add_child(row)
	_scroll_down()
	return row


func _scroll_down() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if is_instance_valid(_chat_scroll):
		_chat_scroll.scroll_vertical = int(_chat_scroll.get_v_scroll_bar().max_value)


# --- Bank ---

func _bank() -> void:
	_title.text = "Bank"
	if not Game.bank_account:
		_text("No account", 24)
		_text("You don't have an Italian bank account yet.\n\nOpen one in person at the Banca. It's open 9:00 to 16:00.\n\nUntil then, all your money is cash in your pocket.")
		return
	_text("Balance", 16)
	_text("%d euro" % Game.bank_balance, 34)
	_text("Cash in your pocket: %d euro\n\nDeposit cash at the bank counter." % Game.cash)


# --- University ---

func _university() -> void:
	_title.text = "University"
	if Game.tuition_owed <= 0:
		_text("Tuition paid", 24)
		_text("You're cleared to sit your exams.")
		return
	_text("Tuition due", 16)
	_text("%d euro" % Game.tuition_owed, 34)
	_text("Exams are on days 10, 20 and 30. You can't sit them until this is paid.")
	var pay := Button.new()
	pay.text = "Pay now"
	pay.custom_minimum_size.y = 48
	pay.disabled = not Game.bank_account or Game.bank_balance < Game.tuition_owed
	pay.pressed.connect(func():
		Game.pay_tuition()
		_show("university"))
	_content.add_child(pay)
	if not Game.bank_account:
		_text("Payment needs an Italian bank account.")
	elif Game.bank_balance < Game.tuition_owed:
		_text("Not enough in your account (%d euro)." % Game.bank_balance)


# --- Notebook ---

func _notebook() -> void:
	_title.text = "Notebook"
	if Game.notebook.is_empty():
		_text("Nothing yet. Things people tell you get written down here.")
	for note in Game.notebook:
		_text("•  " + note)


# --- Helpers ---

func _text(text: String, size: int = 16) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size)
	_content.add_child(label)


func _style(color: Color, radius: int, padding: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(padding)
	return style
