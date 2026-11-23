class_name Computer
extends CanvasLayer
## The computer in your room. It has internet: an online marketplace, and
## messages to everyone in your phone, on a bigger screen.

const DESK := Color(0.07, 0.09, 0.14, 0.98)
const BAR := Color(0.14, 0.17, 0.24)
const MINE := Color(0.16, 0.42, 0.3)
const THEIRS := Color(0.2, 0.22, 0.27)

var _panel: PanelContainer
var _clock: Label
var _content: VBoxContainer
var _screen := "market"
var _person: Person
var _busy := false
var _chat_box: VBoxContainer
var _chat_scroll: ScrollContainer
var _message_box: LineEdit
var _note := ""


func _ready() -> void:
	layer = 6
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", _style(DESK, 10, 14))
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 0.5
	_panel.anchor_bottom = 0.5
	_panel.offset_left = -450
	_panel.offset_right = 450
	_panel.offset_top = -290
	_panel.offset_bottom = 290
	add_child(_panel)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 10)
	_panel.add_child(rows)

	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)
	rows.add_child(bar)
	for tab in [["Mercatino", "market"], ["Messages", "people"]]:
		var button := Button.new()
		button.text = "  %s  " % tab[0]
		button.custom_minimum_size.y = 38
		button.pressed.connect(_show.bind(tab[1]))
		bar.add_child(button)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(gap)
	_clock = Label.new()
	_clock.modulate.a = 0.7
	bar.add_child(_clock)
	var off := Button.new()
	off.text = "  Shut down (Esc)  "
	off.pressed.connect(close)
	bar.add_child(off)

	_content = VBoxContainer.new()
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 8)
	rows.add_child(_content)
	Game.minute_passed.connect(func(): _clock.text = Game.clock_text())
	_panel.visible = false


func is_open() -> bool:
	return _panel.visible


func open() -> void:
	_panel.visible = true
	Game.modal_open = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_clock.text = Game.clock_text()
	_note = ""
	_show("market")


func close() -> void:
	if not _panel.visible:
		return
	_panel.visible = false
	Game.modal_open = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	get_viewport().gui_release_focus()


func _input(event: InputEvent) -> void:
	if _panel.visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func _show(screen: String) -> void:
	_screen = screen
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	match screen:
		"market": _market()
		"people": _people()
		"chat": _chat()


# --- The marketplace ---

func _market() -> void:
	_text("Mercatino", 26)
	if Game.bank_account:
		_text("Used things from strangers, delivered to your door. In your account: %d euro." % Game.bank_balance, 15)
	else:
		_text("Used things from strangers, delivered to your door. Online payments need an Italian bank account.", 15).modulate = Color(1.0, 0.7, 0.5)
	if _note != "":
		_text(_note, 15).modulate = Color(1.0, 0.85, 0.5)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_content.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)
	for entry in Settings.GOODS:
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", _style(BAR, 8, 10))
		list.add_child(card)
		var row := HBoxContainer.new()
		card.add_child(row)
		var words := Label.new()
		words.text = "%s\n%s" % [entry.name, entry.about]
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(words)
		var buy := Button.new()
		buy.custom_minimum_size = Vector2(150, 44)
		if Game.owned.has(entry.id):
			buy.text = "Bought"
			buy.disabled = true
		else:
			buy.text = "Buy: %d euro" % entry.price
			buy.pressed.connect(func():
				_note = Game.buy_good(entry.id)
				_show("market"))
		row.add_child(buy)


# --- Messages ---

func _people() -> void:
	_text("Messages", 26)
	for person in Game.contacts:
		var button := Button.new()
		var last: String = "" if person.history.is_empty() else person.history[-1].text
		button.text = "  %s    %s" % [person.name, last.left(70)]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size.y = 40
		button.pressed.connect(func():
			_person = person
			_show("chat"))
		_content.add_child(button)


func _chat() -> void:
	_text(_person.name, 26)
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
	_message_box.placeholder_text = "Message" if Game.llm_ready else "No connection yet…"
	_message_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_message_box.text_submitted.connect(_send)
	row.add_child(_message_box)
	var send := Button.new()
	send.text = "  Send  "
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
	var bubble := PanelContainer.new()
	bubble.add_theme_stylebox_override("panel", _style(MINE if mine else THEIRS, 12, 8))
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = minf(520.0, 14.0 + text.length() * 8.5)
	bubble.add_child(label)
	row.add_child(bubble)
	_chat_box.add_child(row)
	_scroll_down()
	return row


func _scroll_down() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if is_instance_valid(_chat_scroll):
		_chat_scroll.scroll_vertical = int(_chat_scroll.get_v_scroll_bar().max_value)


func _text(text: String, size: int = 16) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size)
	_content.add_child(label)
	return label


func _style(color: Color, radius: int, padding: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(padding)
	return style
