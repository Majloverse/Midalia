class_name BankScreen
extends CanvasLayer
## The bank counter. Open an account (it takes hours), then deposit or withdraw cash.

signal closed

## Set by the world: shows the hours of waiting going by. Takes in-game minutes.
var pass_time: Callable

var _panel: PanelContainer
var _column: VBoxContainer
var _amount: LineEdit


func _ready() -> void:
	layer = 6
	_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.13, 0.2, 0.96)
	style.set_corner_radius_all(16)
	style.set_content_margin_all(24)
	_panel.add_theme_stylebox_override("panel", style)
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 0.5
	_panel.anchor_bottom = 0.5
	_panel.offset_left = -260
	_panel.offset_right = 260
	_panel.offset_top = -230
	_panel.offset_bottom = 230
	add_child(_panel)
	_column = VBoxContainer.new()
	_column.add_theme_constant_override("separation", 12)
	_panel.add_child(_column)
	_panel.visible = false


func is_open() -> bool:
	return _panel.visible


func open() -> void:
	_panel.visible = true
	Game.modal_open = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_show()


func close() -> void:
	if not _panel.visible:
		return
	_panel.visible = false
	Game.modal_open = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	get_viewport().gui_release_focus()
	closed.emit()


func _input(event: InputEvent) -> void:
	if _panel.visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func _show(message: String = "") -> void:
	for child in _column.get_children():
		_column.remove_child(child)
		child.queue_free()
	_text("BANCA", 30)
	if not Game.bank_account:
		_text("\"Buongiorno. You want an account? Passport, please. And this form. And this one. And this one.\"")
		_text("Opening an account takes %d hours." % Settings.BANK_ACCOUNT_HOURS, 16)
		_button("Open an account", _open_account)
	else:
		_text("In your account: %d euro\nIn your pocket: %d euro" % [Game.bank_balance, Game.cash], 20)
		_button("Deposit all my cash", func(): _move(Game.cash))
		_amount = LineEdit.new()
		_amount.placeholder_text = "Amount in euro"
		_amount.custom_minimum_size.y = 40
		_column.add_child(_amount)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		_column.add_child(row)
		_button("Deposit amount", func(): _move(_typed()), row)
		_button("Withdraw amount", func(): _move(-_typed()), row)
	if message != "":
		_text(message, 16).modulate = Color(1.0, 0.85, 0.5)
	_button("Leave (Esc)", close)


func _open_account() -> void:
	_panel.visible = false
	if pass_time.is_valid():
		await pass_time.call(Settings.BANK_ACCOUNT_HOURS * 60)
	else:
		Game.advance(Settings.BANK_ACCOUNT_HOURS * 60)
	_panel.visible = true
	Game.bank_account = true
	Game.add_note("I have an Italian bank account. Family can send money now, and I can pay tuition in the University app.")
	_show("%d hours later, at %s, you have an account. Money in it can't be stolen." % [Settings.BANK_ACCOUNT_HOURS, Game.clock_text()])


## Moves money from pocket to account (positive) or back (negative).
func _move(amount: int) -> void:
	if amount == 0:
		_show("Type an amount first.")
	elif amount > Game.cash:
		_show("You only have %d euro on you." % Game.cash)
	elif -amount > Game.bank_balance:
		_show("You only have %d euro in the account." % Game.bank_balance)
	else:
		Game.cash -= amount
		Game.bank_balance += amount
		_show(("Deposited %d euro." % amount) if amount > 0 else ("Withdrew %d euro." % -amount))


func _typed() -> int:
	return maxi(0, _amount.text.strip_edges().to_int())


func _text(text: String, size: int = 18) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size)
	_column.add_child(label)
	return label


func _button(text: String, action: Callable, parent: Control = null) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 44
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(action)
	(parent if parent != null else _column).add_child(button)
