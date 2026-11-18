extends Node
## Autoload "Game": the player's numbers, the clock, the contacts and the controls.

signal minute_passed
signal models_ready
signal night_ended          # the clock reached 5:00
signal notice(text: String)  # something the player should see on screen
signal shelter_changed

const FLATS := ["VIA VERDI 3", "VIA DANTE 7", "VIA MILANO 21"]
const SAVE_PATH := "user://midalia_save.json"

var wellbeing: int
var cash: int
var street_cred: int
var day: int
## Minutes since midnight, as a decimal so the clock runs smoothly.
var minutes: float
var clock_running := true

var bank_account: bool
var bank_balance: int
var tuition_owed: int
var contacts: Array[Person]
var partygoers: Array[Person]
var notebook: Array[String]
var mean_to: Array  # names of people you've been mean to
## Whoever has offered you their couch for tonight, or null.
var shelter_host: Person
## True once you have got through a night, by sleeping somewhere or passing out.
var night_survived: bool
## True once the "you survived" screen has been shown.
var survived_shown: bool

var phone_open := false
## True while a full-screen moment (talking, a wheel, game over) has the player's attention.
var modal_open := false
var rng := RandomNumberGenerator.new()
var llm := LLM.new()
var llm_ready := false

## Set when this run began from a save: where the player was when it was made.
var loaded_from_save := false
var saved_inside := ""
var saved_position := Vector3.ZERO

var _last_minute := -1


func _ready() -> void:
	rng.randomize()
	_add_key("move_forward", KEY_W)
	_add_key("move_back", KEY_S)
	_add_key("move_left", KEY_A)
	_add_key("move_right", KEY_D)
	_add_key("jump", KEY_SPACE)
	_add_key("interact", KEY_E)
	_add_key("phone", KEY_TAB)
	_add_key("run", KEY_SHIFT)
	if not load_game():
		reset()
	_load_models()


## Starts a new game.
func reset() -> void:
	loaded_from_save = false
	wellbeing = Settings.START_WELLBEING
	cash = Settings.START_CASH
	street_cred = Settings.START_STREET_CRED
	day = 1
	minutes = Settings.START_HOUR * 60.0
	bank_account = false
	bank_balance = 0
	tuition_owed = Settings.TUITION
	contacts = Person.family()
	notebook = []
	mean_to = []
	shelter_host = null
	night_survived = false
	survived_shown = false
	phone_open = false
	modal_open = false
	clock_running = true
	_last_minute = -1
	_invite_partygoers()


## The students at the first night's party. One true friend and one ok person
## are guaranteed; the rest are rolled, so nearly all of them are two-faced.
func _invite_partygoers() -> void:
	partygoers = []
	var names: Array = Person.FIRST_NAMES.duplicate()
	var vibes: Array = Person.VIBES.duplicate()
	for i in Settings.PARTY_SIZE:
		var forced := "true_friend" if i == 0 else ("ok" if i == 1 else "")
		var p := Person.random(rng, forced)
		p.name = names.pop_at(rng.randi() % names.size())
		p.vibe = vibes.pop_at(rng.randi() % vibes.size())
		p.home = FLATS[i % FLATS.size()]
		partygoers.append(p)
	# Shuffle so the true friend isn't always the first person in the room.
	for i in range(partygoers.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap := partygoers[i]
		partygoers[i] = partygoers[j]
		partygoers[j] = swap


func _load_models() -> void:
	llm_ready = await llm.load_models(Settings.MODELS.values()[0], Settings.TONE_MODEL)
	if llm_ready:
		models_ready.emit()
	else:
		push_error("Could not load the language models. Texting will not work.")


func _process(delta: float) -> void:
	if not clock_running:
		return
	# A full day (1440 game minutes) takes DAY_REAL_MINUTES real minutes.
	var before := minutes
	minutes += delta * 1440.0 / (Settings.DAY_REAL_MINUTES * 60.0)
	if minutes >= 1440.0:
		minutes -= 1440.0
		day += 1
	if int(minutes) != _last_minute:
		_last_minute = int(minutes)
		minute_passed.emit()
		_check_cancelled_couch()
	if before < Settings.PASS_OUT_HOUR * 60.0 and minutes >= Settings.PASS_OUT_HOUR * 60.0:
		night_ended.emit()


func hour() -> float:
	return minutes / 60.0


func clock_text() -> String:
	return "%02d:%02d" % [int(minutes) / 60, int(minutes) % 60]


## Minutes since the start of day 1's midnight; lets us schedule things across midnight.
func total_minutes() -> int:
	return day * 1440 + int(minutes)


func bank_is_open() -> bool:
	return hour() >= Settings.BANK_OPENS_HOUR and hour() < Settings.BANK_CLOSES_HOUR


func is_night() -> bool:
	return hour() >= Settings.PARTY_START_HOUR or hour() < Settings.PASS_OUT_HOUR


## Moves the clock forward by some in-game minutes.
func advance(game_minutes: int) -> void:
	minutes += game_minutes
	while minutes >= 1440.0:
		minutes -= 1440.0
		day += 1
	_last_minute = -1


## Jumps the clock to the next 9:00. Every night ends here, however it went.
func skip_to_morning() -> void:
	night_survived = true
	if hour() >= Settings.WAKE_HOUR:
		day += 1
	minutes = Settings.WAKE_HOUR * 60.0
	_last_minute = -1


## The one save slot. Written each time the player wakes up; there is no manual saving.
func save_game(inside: String, position: Vector3) -> void:
	var people: Array[Person] = []
	people.append_array(contacts.filter(func(p): return p.kind == "family"))
	people.append_array(partygoers)
	var data := {
		"wellbeing": wellbeing, "cash": cash, "street_cred": street_cred, "day": day, "minutes": minutes,
		"bank_account": bank_account, "bank_balance": bank_balance, "tuition_owed": tuition_owed,
		"notebook": notebook, "mean_to": mean_to, "night_survived": night_survived, "survived_shown": survived_shown,
		"people": people.map(func(p): return p.to_data()),
		"contacts": contacts.map(func(p): return people.find(p)),
		"partygoers": partygoers.map(func(p): return people.find(p)),
		"inside": inside, "position": [position.x, position.y, position.z],
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data))


## Loads the save if there is one. Returns false if there isn't or it can't be read.
func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if not data is Dictionary or not data.has("people"):
		return false
	reset()
	wellbeing = int(data.wellbeing)
	cash = int(data.cash)
	street_cred = int(data.street_cred)
	day = int(data.day)
	minutes = data.minutes
	bank_account = data.bank_account
	bank_balance = int(data.bank_balance)
	tuition_owed = int(data.tuition_owed)
	notebook.assign(data.notebook)
	mean_to = data.mean_to
	night_survived = data.night_survived
	survived_shown = data.survived_shown
	var people: Array = data.people.map(func(d): return Person.from_data(d))
	contacts.assign(data.contacts.map(func(i): return people[int(i)]))
	partygoers.assign(data.partygoers.map(func(i): return people[int(i)]))
	saved_inside = data.inside
	saved_position = Vector3(data.position[0], data.position[1], data.position[2])
	loaded_from_save = true
	return true


func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


func add_note(text: String) -> void:
	if not notebook.has(text):
		notebook.append(text)


## Pays the tuition from the bank account. Returns false if that isn't possible.
func pay_tuition() -> bool:
	if not bank_account or tuition_owed <= 0 or bank_balance < tuition_owed:
		return false
	bank_balance -= tuition_owed
	tuition_owed = 0
	return true


## Sends the player's message to a person, by text or face to face, and returns
## their reply. This is the one path every conversation goes through.
func send(person: Person, text: String, in_person: bool) -> String:
	person.history.append({"from": "player", "text": text})
	var tone: String = await llm.tone_of(text)
	var request := LLM.request_of(text)
	var result := Rules.resolve(person, tone, request, in_person, self, rng)
	if person.kind == "met":
		if tone != "mean" and not contacts.has(person):
			contacts.append(person)
			notice.emit("%s gave you their number." % person.name)
		if request == "shelter" and result.granted:
			_offer_couch(person, result)
	if result.strangers_mad:
		notice.emit("Word got around that you're rude. People are talking.")
	var reply: String = await llm.reply(person, person.history, result)
	person.history.append({"from": "person", "text": reply})
	return reply


func _offer_couch(person: Person, result: Dictionary) -> void:
	shelter_host = person
	result.opener += " i'm at %s." % person.home.capitalize()
	add_note("%s said I can sleep on their couch tonight, at %s." % [person.name, person.home.capitalize()])
	person.betrayal = ""
	person.cancel_at = -1
	if person.nature == "two_faced":
		var roll := rng.randf()
		if roll < Settings.BETRAY_CANCEL_CHANCE:
			# They'll back out later tonight, but never so late that there's no time left at all.
			person.betrayal = "cancel"
			var latest := total_minutes() + minutes_until(Settings.PASS_OUT_HOUR) - 30
			person.cancel_at = mini(total_minutes() + rng.randi_range(60, 180), latest)
		elif roll < Settings.BETRAY_CANCEL_CHANCE + Settings.BETRAY_STEAL_CHANCE:
			person.betrayal = "steal"
	shelter_changed.emit()


func _check_cancelled_couch() -> void:
	var host := shelter_host
	if host == null or host.cancel_at < 0 or total_minutes() < host.cancel_at:
		return
	host.cancel_at = -1
	shelter_host = null
	host.history.append({"from": "person", "text": "hey sorry, something came up. you can't stay at mine tonight."})
	host.remember("You offered them your couch and then cancelled on them.")
	add_note("%s cancelled. I can't sleep at their place." % host.name)
	notice.emit("New message from %s." % host.name)
	shelter_changed.emit()


## What a night on the host's couch does to you. The clock is moved separately,
## by the sleeping animation. Returns what the player wakes up to.
func sleep_on_couch() -> String:
	var host := shelter_host
	shelter_host = null
	night_survived = true
	wellbeing = clampi(wellbeing + Settings.COUCH_WELLBEING, 0, 100)
	host.remember("They slept on your couch.")
	var text := "You slept on %s's couch. Wellbeing +%d." % [host.name, Settings.COUCH_WELLBEING]
	if host.betrayal == "steal" and cash > 0:
		var stolen := int(cash * rng.randf_range(Settings.STEAL_SHARE_MIN, Settings.STEAL_SHARE_MAX))
		cash -= stolen
		host.remember("You took some of their money while they slept. They don't know it was you.")
		add_note("%d euro went missing from my bag while I slept at %s's." % [stolen, host.name])
		text += " Something feels off. %d euro is missing from your bag." % stolen
	host.betrayal = ""
	shelter_changed.emit()
	return text


func minutes_until(hour_of_day: int) -> int:
	var target := hour_of_day * 60
	var now := int(minutes)
	return target - now if target > now else target + 1440 - now


func _add_key(action: String, key: Key) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	var event := InputEventKey.new()
	event.physical_keycode = key
	InputMap.action_add_event(action, event)
