extends Control
## Step 1 of the build order: a bare texting test, no 3D.
## Type to a random person. The right-hand panel shows what the game decided,
## including things the real game will hide (their nature, the odds).

var llm := LLM.new()
var rng := RandomNumberGenerator.new()
var person: Person
var history: Array = []
var state := {}
var busy := false

var chat_log: RichTextLabel
var input: LineEdit
var send_button: Button
var info: RichTextLabel
var in_person: CheckBox


func _ready() -> void:
	rng.randomize()
	_build_ui()
	_new_game()
	_set_busy(true)
	_say_system("Loading the models…")
	var model_path: String = Settings.MODELS.values()[0]
	if await llm.load_models(model_path, Settings.TONE_MODEL):
		_say_system("Ready. Say something to %s." % person.name)
		_set_busy(false)
		input.grab_focus()
	else:
		_say_system("Could not load the model at %s" % model_path)


func _new_game() -> void:
	state = {
		"wellbeing": Settings.START_WELLBEING, "cash": Settings.START_CASH,
		"street_cred": Settings.START_STREET_CRED, "mean_to": [],
	}
	_new_person()


func _new_person() -> void:
	person = Person.random(rng)
	history.clear()
	chat_log.clear()
	_say_system("You are now texting %s." % person.name)
	_show_info({})


func _on_send(_text: String = "") -> void:
	var text := input.text.strip_edges()
	if busy or text.is_empty():
		return
	input.clear()
	_set_busy(true)
	history.append({"from": "player", "text": text})
	chat_log.append_text("[right][color=#8fd18f]%s[/color][/right]\n" % text.replace("[", "[lb]"))

	var tone: String = await llm.tone_of(text)
	var request := LLM.request_of(text)
	var result := Rules.resolve(person, tone, request, in_person.button_pressed, state, rng)
	result["tone"] = tone
	result["request"] = request
	_show_info(result)

	var reply: String = await llm.reply(person, history, result)
	history.append({"from": "person", "text": reply})
	chat_log.append_text("[b]%s:[/b] %s\n" % [person.name, reply.replace("[", "[lb]")])
	if result.strangers_mad:
		_say_system("Word got around that you're rude. Strangers are mad at you.")
	if state.wellbeing <= 0:
		_say_system("Your wellbeing hit zero. Game over. Starting again.")
		_new_game()
	_set_busy(false)
	input.grab_focus()


func _show_info(result: Dictionary) -> void:
	var text := "[b]You[/b]\nWellbeing: %d\nCash: %d euro\nStreet cred: %d\n\n" % [state.wellbeing, state.cash, state.street_cred]
	text += "[b]%s[/b]\n%s\n" % [person.name, person.vibe]
	text += "Opinion of you: %d\nFriend: %s\n" % [person.opinion, "yes" if person.is_friend else "no"]
	text += "[color=#d18f8f]Hidden nature: %s[/color]\n\n" % person.nature.replace("_", " ")
	if not result.is_empty():
		text += "[b]Your last message[/b]\nTone: %s\nAsked for: %s\n" % [result.tone.replace("_", " "), result.request]
		if result.request != "none" and result.tone != "mean":
			text += "Chance of yes: %d%%\n" % roundi(result.chance * 100)
		text += "Result: %s\n" % result.summary
		text += "Wellbeing %+d, cash %+d, cred %+d\n\n" % [result.wellbeing, result.cash, result.street_cred]
	if not person.memory.is_empty():
		text += "[b]What they remember[/b]\n" + "\n".join(person.memory)
	info.text = text


func _say_system(text: String) -> void:
	chat_log.append_text("[center][color=#888888][i]%s[/i][/color][/center]\n" % text)


func _set_busy(value: bool) -> void:
	busy = value
	send_button.disabled = value
	input.editable = not value


func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 16)
	margin.add_child(columns)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 2.0
	columns.add_child(left)
	chat_log = RichTextLabel.new()
	chat_log.bbcode_enabled = true
	chat_log.scroll_following = true
	chat_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(chat_log)
	var row := HBoxContainer.new()
	left.add_child(row)
	input = LineEdit.new()
	input.placeholder_text = "Type a message…"
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input.text_submitted.connect(_on_send)
	row.add_child(input)
	send_button = Button.new()
	send_button.text = "Send"
	send_button.pressed.connect(_on_send)
	row.add_child(send_button)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(right)
	info = RichTextLabel.new()
	info.bbcode_enabled = true
	info.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(info)
	in_person = CheckBox.new()
	in_person.text = "Talking face to face"
	right.add_child(in_person)
	var next := Button.new()
	next.text = "Text someone new"
	next.pressed.connect(func(): if not busy: _new_person())
	right.add_child(next)
