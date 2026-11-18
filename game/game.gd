extends Node
## Autoload "Game": the player's numbers, the clock and the controls.

signal minute_passed

var wellbeing: int = Settings.START_WELLBEING
var cash: int = Settings.START_CASH
var street_cred: int = Settings.START_STREET_CRED
var day: int = 1
## Minutes since midnight, as a decimal so the clock runs smoothly.
var minutes: float = Settings.START_HOUR * 60.0
var clock_running := true

var _last_minute := -1


func _ready() -> void:
	_add_key("move_forward", KEY_W)
	_add_key("move_back", KEY_S)
	_add_key("move_left", KEY_A)
	_add_key("move_right", KEY_D)
	_add_key("jump", KEY_SPACE)
	_add_key("interact", KEY_E)
	_add_key("phone", KEY_TAB)
	_add_key("run", KEY_SHIFT)


func _process(delta: float) -> void:
	if not clock_running:
		return
	# A full day (1440 game minutes) takes DAY_REAL_MINUTES real minutes.
	minutes += delta * 1440.0 / (Settings.DAY_REAL_MINUTES * 60.0)
	if minutes >= 1440.0:
		minutes -= 1440.0
		day += 1
	if int(minutes) != _last_minute:
		_last_minute = int(minutes)
		minute_passed.emit()


func hour() -> float:
	return minutes / 60.0


func clock_text() -> String:
	return "%02d:%02d" % [int(minutes) / 60, int(minutes) % 60]


func _add_key(action: String, key: Key) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	var event := InputEventKey.new()
	event.physical_keycode = key
	InputMap.action_add_event(action, event)
