extends Node3D
## The neighbourhood and the first build's story: walking, the party, finding a
## couch, sleeping or passing out, and the bank. Everything is built from simple
## blocks here; proper models replace them later.
##
## The streets are the real centre of Milan (see Milan). The game's doors sit on
## real walls within a few minutes' walk of the university; world/milan/places.json
## says where.

## Interiors are separate rooms built far from the city.
const INTERIORS_AT := Vector3(3000, 0, 0)

const PLACES := [
	{"sign": "STAZIONE CENTRALE", "prompt": "Enter the station", "action": "enter"},
	{"sign": "BANCA", "prompt": "Enter the bank", "action": "bank"},
	{"sign": "UNIVERSITÀ", "prompt": "Enter the university", "action": "enter", "hours": [8, 20]},
	{"sign": "VIA ROMA 12", "prompt": "Go up to the party", "action": "party"},
	{"sign": "VIA VERDI 3", "prompt": "Ring the bell", "action": "flat"},
	{"sign": "VIA DANTE 7", "prompt": "Ring the bell", "action": "flat"},
	{"sign": "VIA MILANO 21", "prompt": "Ring the bell", "action": "flat"},
	{"sign": "SUPERMERCATO", "prompt": "Enter the supermarket", "action": "enter", "hours": Settings.SUPERMARKET_HOURS},
	{"sign": "ALIMENTARI", "prompt": "Enter the shop", "action": "enter", "hours": Settings.CORNER_SHOP_HOURS},
	{"sign": "MINIMARKET", "prompt": "Enter the shop", "action": "enter", "hours": Settings.CORNER_SHOP_HOURS},
	{"sign": "BENZINA", "prompt": "Enter the petrol station shop", "action": "enter"},
]
## Each student flat's walls and furniture colour.
const FLAT_LOOKS := {
	"VIA VERDI 3": [Color(0.85, 0.78, 0.68), Color(0.65, 0.25, 0.25)],
	"VIA DANTE 7": [Color(0.75, 0.82, 0.76), Color(0.25, 0.45, 0.4)],
	"VIA MILANO 21": [Color(0.78, 0.78, 0.86), Color(0.35, 0.35, 0.6)],
}

var _sun: DirectionalLight3D
var _environment: Environment
var _lamps: Array[OmniLight3D] = []
var _walls: Array = []  # the city's wall materials; their windows light up at night
var _hud: Hud
var _phone: Phone
var _talk: Talk
var _wheel: WheelScreen
var _bank: BankScreen
var _computer: Computer
var _taken: Array[Area3D] = []  # things off the shop shelves: in your basket, or bought
var _my_food: Node3D            # your food, standing on the lodger's shelf at home
var _transition: Transition
var _player: Player
var _flat_doors := {}   # sign -> the Area3D at that flat's street door
var _street_doors := {}  # sign -> [where you stand outside, which way you face]
var _interiors := {}    # sign -> what Interiors built for it
var _npcs := {}         # Person -> their body in the world
var _inside := ""       # the sign of the building the player is in, or "" on the street
var _game_over := false

signal _chosen(index: int)


func _ready() -> void:
	_build_sky()
	var city := Milan.build(self)
	_walls = city.walls
	for place in PLACES:
		_build_door(place, city.places[place.sign])
	for lamp in city.lamps:
		_build_lamp(Vector3(lamp[0], 0, lamp[1]))
	_build_interiors()

	_hud = Hud.new()
	add_child(_hud)
	_phone = Phone.new()
	add_child(_phone)
	_talk = Talk.new()
	add_child(_talk)
	_wheel = WheelScreen.new()
	add_child(_wheel)
	_transition = Transition.new()
	add_child(_transition)
	_bank = BankScreen.new()
	add_child(_bank)
	_bank.closed.connect(_on_bank_closed)
	_bank.pass_time = _wait_at_bank
	_computer = Computer.new()
	add_child(_computer)
	Game.food_changed.connect(_show_my_food)
	Game.shelter_changed.connect(_show_my_food)
	Game.goods_changed.connect(_show_goods)
	_player = Player.new()
	add_child(_player)
	_player.prompt_changed.connect(_hud.set_prompt)
	_player.interacted.connect(_on_interact)
	Game.notice.connect(_hud.show_message)
	Game.shelter_changed.connect(_refresh_flat_doors)
	Game.night_ended.connect(_on_night_ended)
	Game.home_lost.connect(_on_home_lost)
	if Game.flatmate != null:
		_bring_home(Game.flatmate)
	_refresh_flat_doors()
	_show_my_food()
	_show_goods()
	Game.inside = _inside
	_show_rooms()
	if Game.loaded_from_save:
		# Carry on from where you last woke up.
		_inside = Game.saved_inside
		if Game.saved_map == Game.MAP:
			_player.teleport(Game.saved_position, 0.0)
		elif _inside != "":
			# A save from an older map: you are still in the same building, by its door.
			_player.teleport(_interiors[_inside].entry, 0.0)
		else:
			_player.teleport(_street_doors["STAZIONE CENTRALE"][0], _street_doors["STAZIONE CENTRALE"][1])
		_player.set_camera_distance(Settings.CAMERA_DISTANCE_INDOORS if _inside != "" else Settings.CAMERA_DISTANCE)
		_ask_continue()
	else:
		# A new game starts as you step off the train.
		_inside = "STAZIONE CENTRALE"
		_player.teleport(_interiors[_inside].arrival, -PI / 2)
		_player.set_camera_distance(Settings.CAMERA_DISTANCE_INDOORS)
		_hud.show_message("You just got off the train in Milan. The party at Via Roma 12 starts at 21:00.\nEat at the bar before you go: a day without food hurts. Tab for your phone.")


func _process(_delta: float) -> void:
	# Sun rises at 6:00, is highest at 12:00 and sets at 18:00... roughly; dusk lingers a little.
	if Game.inside != _inside:
		Game.inside = _inside
		_show_rooms()
	var hour := Game.hour()
	var angle := (hour - 6.0) / 24.0 * TAU
	var height := sin(angle)  # 1 at noon, -1 at midnight
	_sun.rotation = Vector3(-angle, 0.6, 0)
	var daylight := clampf(height * 3.0 + 0.4, 0.0, 1.0)
	_sun.light_energy = daylight * 1.2
	_sun.light_color = Color(1.0, 0.75, 0.55).lerp(Color.WHITE, clampf(height * 2.5, 0.0, 1.0))
	_environment.background_energy_multiplier = lerpf(0.06, 1.0, daylight)
	# Rooms have their own lamps, so the sky shouldn't flood them.
	_environment.ambient_light_energy = lerpf(0.35, 1.0, daylight) * (0.45 if _inside != "" else 1.0)
	for lamp in _lamps:
		lamp.visible = daylight < 0.6
	Milan.set_night(_walls, 1.0 - daylight)
	if Game.wellbeing <= 0 and not _game_over and not Game.modal_open:
		_show_game_over()


# --- Things the player can do ---

func _on_interact(area: Area3D) -> void:
	match area.get_meta("action", "message"):
		"message":
			_hud.show_message(area.get_meta("message"))
		"enter":
			var hours: Array = area.get_meta("hours")
			if hours.is_empty() or (Game.hour() >= hours[0] and Game.hour() < hours[1]):
				await _enter(area.get_meta("sign"))
			else:
				_hud.show_message("Closed. It is open %d:00 to %d:00." % hours)
		"notices":
			var tuition := "Your tuition is paid." if Game.tuition_owed <= 0 else "You still owe %d euro in tuition. No payment, no exams." % Game.tuition_owed
			_hud.show_message("Exams are on days 10, 20 and 30. Today is day %d. %s\n%s" % [Game.day, tuition, Game.read_board()])
		"bank":
			if Game.bank_is_open():
				await _enter("BANCA")
			else:
				_hud.show_message("The bank is closed. It is open %d:00 to %d:00." % [Settings.BANK_OPENS_HOUR, Settings.BANK_CLOSES_HOUR])
		"teller":
			if Game.bank_is_open():
				_bank.open()
			else:
				_hud.show_message("\"We are closed. Come back tomorrow.\"")
		"party":
			if Game.is_night():
				await _enter("VIA ROMA 12")
				_hud.show_message("The party. Walk up to people and press E to talk.")
			else:
				_hud.show_message("Nobody answers. The party starts at 21:00.")
		"flat":
			await _ring_bell(area.get_meta("sign"))
		"leave":
			_leave()
		"talk":
			_talk.open(area.get_meta("person"))
		"eat":
			_hud.show_message(Game.eat(Settings.MEAL_PRICE, Settings.MEAL_WELLBEING, "A panino and a coffee, standing at the bar."))
		"cook":
			if Game.home != _inside:
				_hud.show_message("Not your kitchen. Hands off the pasta.")
			else:
				_phone.open_at("food")
		"take":
			Game.cart.append({"item": area.get_meta("item"), "price": area.get_meta("price")})
			area.get_parent().visible = false
			area.collision_layer = 0
			_taken.append(area)
			_hud.show_message("%s in your basket. Pay at the till." % Food.name_of(area.get_meta("item")))
		"fridge_door":
			_swing(area)
		"checkout":
			await _check_out()
		"study":
			await _study()
		"computer":
			_computer.open()
		"room_door":
			if Game.home == "" or Game.home != _inside:
				_hud.show_message("The spare room. It's locked: you don't live here.")
			else:
				await _through_door(_interiors[_inside].spare_entry, 0.0, Settings.CAMERA_DISTANCE_INDOORS)
		"room_exit":
			await _through_door(_interiors[_inside].room_door, PI / 2, Settings.CAMERA_DISTANCE_INDOORS)
		"bed":
			if Game.home != _inside:
				_hud.show_message("That's not your bed.")
			elif Game.hour() < Settings.BED_FROM_HOUR and Game.hour() >= Settings.PASS_OUT_HOUR:
				_hud.show_message("You're not tired yet. Bed is for after %d:00." % Settings.BED_FROM_HOUR)
			else:
				_sleep(area.get_meta("lie_at"), area.get_meta("lie_yaw"))
		"sleep":
			if Game.home == _inside:
				_hud.show_message("You have a bed now. Use that.")
			elif Game.shelter_host == null or Game.shelter_host.home != _inside:
				_hud.show_message("You weren't invited to stay.")
			else:
				_sleep(area.get_meta("lie_at"), area.get_meta("lie_yaw"))


## Walks through a door into a building, with a short fade.
func _enter(sign: String) -> void:
	_restock()
	_inside = sign
	await _through_door(_interiors[sign].entry, 0.0, Settings.CAMERA_DISTANCE_INDOORS)


func _leave() -> void:
	if not Game.cart.is_empty():
		Game.cart = []
		_hud.show_message("You put everything in your basket back on the shelves.")
	var door: Array = _street_doors[_inside]
	_inside = ""
	await _through_door(door[0], door[1], Settings.CAMERA_DISTANCE)


## Only the building you're in is drawn; the rest would cost time for nothing.
func _show_rooms() -> void:
	for sign in _interiors:
		_interiors[sign].room.visible = sign == _inside
		if _interiors[sign].has("spare"):
			_interiors[sign].spare.visible = sign == _inside


## Everything taken off a shelf goes back: when you put your basket back, and each time a shop is entered.
func _restock() -> void:
	for area in _taken:
		area.get_parent().visible = true
		area.collision_layer = 2
	_taken.clear()


## Fridge and freezer doors swing open and shut.
func _swing(door: Area3D) -> void:
	var open: bool = not door.get_meta("open", false)
	door.set_meta("open", open)
	var what := "freezer" if door.get_meta("freezer") else "fridge"
	door.set_meta("prompt", ("Close the %s" if open else "Open the %s") % what)
	var hinge: Node3D = door.get_meta("hinge")
	create_tween().tween_property(hinge, "rotation:y", -1.9 if open else 0.0, 0.35).set_trans(Tween.TRANS_SINE)
	_player.refresh_prompt()


## The till: see what's in the basket, then pay, put it back, or carry on shopping.
func _check_out() -> void:
	if Game.cart.is_empty():
		_hud.show_message("\"Buongiorno.\" Your basket is empty.\nLook at something on a shelf and click to take it.")
		return
	var counts := {}
	for line in Game.cart:
		counts[line.item] = counts.get(line.item, 0) + 1
	var text := "Your basket\n"
	var n := 0
	for id in counts:
		text += ("\n" if n % 3 == 0 else ",   ") + "%d x %s" % [counts[id], Food.name_of(id)]
		n += 1
	var total := Game.cart_total()
	var options: Array[String] = ["Pay %d euro" % total, "Put everything back", "Keep shopping"]
	var pick: int = await _choose(text + "\n\nTotal: %d euro" % total, options)
	if pick == 0:
		if Game.check_out():
			_hud.show_message("Paid %d euro. %s" % [total, "It goes on your shelf at home." if Game.home != "" else "It goes in your bag. Tab, then Food, to eat."])
		else:
			_hud.show_message("\"%d euro.\" You don't have it. The queue behind you sighs." % total)
	elif pick == 1:
		Game.cart = []
		_restock()
		_hud.show_message("You put everything back.")


## Hours with the books, at the university or at your own desk.
func _study() -> void:
	var options: Array[String] = ["Study for 1 hour", "Study for 2 hours", "Study for 3 hours", "Not now"]
	var pick: int = await _choose("Exams are on days 10, 20 and 30.\nHours studied so far: %.1f" % Game.study_hours, options)
	if pick > 2:
		return
	var hours := pick + 1
	if Game.minutes_until(Settings.PASS_OUT_HOUR) <= hours * 60:
		_hud.show_message("It's far too late for that. Your eyes are closing.")
		return
	Game.modal_open = true
	Game.clock_running = false
	await _transition.fade(1.0, 0.6)
	await _transition.roll_clock(hours * 60, 2.5, "Reading. Highlighting. Reading the same line again.")
	await _transition.fade(0.0, 0.6)
	Game.modal_open = false
	Game.clock_running = true
	_hud.show_message(Game.study(hours))


## What you own to eat, lined up on the lodger's shelf in the kitchen at home.
func _show_my_food() -> void:
	if _my_food != null:
		_my_food.queue_free()
		_my_food = null
	if Game.home == "":
		return
	_my_food = Node3D.new()
	_interiors[Game.home].room.add_child(_my_food)
	var shelf: Vector3 = _interiors[Game.home].food_shelf
	for i in mini(Game.food.size(), 14):
		var piece := Food.model(Game.food[i])
		piece.position = shelf + Vector3(i * 0.2, 0, 0)
		_my_food.add_child(piece)


## Things bought online turn up in your room.
func _show_goods() -> void:
	for sign in FLAT_LOOKS:
		var goods: Dictionary = _interiors[sign].goods
		for id in goods:
			goods[id].visible = Game.owned.has(id)


func _through_door(to: Vector3, yaw: float, camera_distance: float) -> void:
	Game.modal_open = true
	await _transition.fade(1.0, 0.25)
	_player.teleport(to, yaw)
	_player.set_camera_distance(camera_distance)
	await get_tree().create_timer(0.1).timeout
	await _transition.fade(0.0, 0.3)
	Game.modal_open = false


## The street door of a student flat: your home, tonight's couch, or a room you could rent.
func _ring_bell(sign: String) -> void:
	if Game.home == sign:
		_bring_home(Game.flatmate)
		await _enter(sign)
		return
	var host := Game.shelter_host
	var couch := host != null and host.home == sign
	var rooms: Array[Person] = []
	if Game.home == "":
		rooms = Game.rooms_at(sign)
	if rooms.is_empty():
		if not couch:
			_hud.show_message("A student flat. Nobody here has invited you.")
		elif not Game.is_night():
			_hud.show_message("%s isn't home. Come back tonight." % host.name)
		else:
			await _go_to_couch(host)
		return
	var options: Array[String] = []
	for person in rooms:
		options.append("Move in with %s: %d euro a week" % [person.name, person.room_rent])
	if couch and Game.is_night():
		options.append("Just the couch tonight")
	options.append("Not now")
	var pick: int = await _choose("%s\n\nThe first week is paid on the spot, from your pocket first.\nAfter that the rent is due every %d days." % [sign.capitalize(), Settings.RENT_DAYS], options)
	if pick >= rooms.size():
		if options[pick] != "Not now":
			await _go_to_couch(host)
		return
	var flatmate := rooms[pick]
	if not Game.move_in(flatmate):
		_hud.show_message("You can't pay the first week: %d euro." % flatmate.room_rent)
		return
	_bring_home(flatmate)
	await _enter(sign)
	_hud.show_message("You live here now, with %s. Your room is through the door on the right.\nNext rent: %d euro on day %d." % [flatmate.name, Game.rent, Game.rent_due_day])


func _go_to_couch(host: Person) -> void:
	_bring_home(host)
	await _enter(host.home)
	_hud.show_message("%s's place. The couch is yours." % host.name)


## Puts someone in their own flat: a host when you go up to their couch, or your flatmate.
func _bring_home(person: Person) -> void:
	var room: Node3D = _interiors[person.home].room
	if _npcs.has(person) and _npcs[person].get_parent() == room:
		return
	# Stand a little apart from anyone already there.
	var others := _npcs.values().filter(func(n): return n.get_parent() == room).size()
	var spot: Vector3 = _interiors[person.home].host_spot + Vector3(-1.1 * others, 0, 0)
	if _npcs.has(person):
		var npc: Node3D = _npcs[person]
		npc.reparent(room)
		npc.position = spot
		npc.rotation = Vector3.ZERO
		npc.get_meta("figure").mood = "idle"
	else:
		_add_npc(person, room, spot, 0.0)


## A few big buttons in the middle of the screen. Returns the number of the one pressed.
func _choose(text: String, options: Array[String]) -> int:
	Game.modal_open = true
	Game.clock_running = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.8)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 14)
	dim.add_child(column)
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 24)
	column.add_child(label)
	for i in options.size():
		var button := Button.new()
		button.text = options[i]
		button.custom_minimum_size = Vector2(420, 52)
		button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		button.pressed.connect(func(): _chosen.emit(i))
		column.add_child(button)
	var pick: int = await _chosen
	layer.queue_free()
	Game.modal_open = false
	Game.clock_running = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	return pick


## Thrown out while you're in the flat: you find yourself on the doorstep.
func _on_home_lost(sign: String) -> void:
	if _inside == sign and not Game.modal_open:
		await _leave()


func _refresh_flat_doors() -> void:
	for sign in _flat_doors:
		var host := Game.shelter_host
		var prompt := "Ring the bell"
		if Game.home == sign:
			prompt = "Go home"
		elif Game.home == "" and not Game.rooms_at(sign).is_empty():
			prompt = "Ring the bell about the room"
		elif host != null and host.home == sign:
			prompt = "Go up to %s's flat" % host.name
		_flat_doors[sign].set_meta("prompt", prompt)
	_player.refresh_prompt()


## Lie down, fade out, watch the night roll by, wake up.
func _sleep(lie_at: Vector3, lie_yaw: float) -> void:
	var at_home := Game.home != "" and _inside == Game.home
	Game.modal_open = true
	Game.clock_running = false
	_hud.set_prompt("")
	await _player.lie_down(lie_at, lie_yaw)
	await get_tree().create_timer(0.5).timeout
	await _transition.fade(1.0, 1.5)
	await _transition.roll_clock(Game.minutes_until(Settings.WAKE_HOUR), 4.0, "z z z")
	var text := Game.sleep_in_bed() if at_home else Game.sleep_on_couch()
	text += Game.wake_up(at_home)
	await _transition.fade(0.0, 1.5)
	await _player.stand_up()
	if at_home and Game.home == "":
		# Couldn't pay the rent: you wake up to your bag by the door.
		await _leave()
	Game.modal_open = false
	Game.clock_running = true
	_player.refresh_prompt()
	_autosave()
	_hud.show_message(text + " Game saved.")


func _on_night_ended() -> void:
	if _game_over:
		return
	if _talk.is_open():
		_talk.close()
	if _bank.is_open():
		_bank.close()
	if _computer.is_open():
		_computer.close()
	if Game.phone_open:
		_phone.toggle()
	# Awake at 5:00 at home, or in a flat you were invited to: you drop onto the bed or the couch.
	var onto := ""
	if Game.home != "" and Game.home == _inside:
		var bed: Area3D = _interiors[_inside].bed
		_player.teleport(_interiors[_inside].spare_entry, 0.0)
		_sleep(bed.get_meta("lie_at"), bed.get_meta("lie_yaw"))
		return
	elif Game.shelter_host != null and Game.shelter_host.home == _inside:
		onto = "sleep"
	if onto != "":
		for area in _interiors[_inside].room.get_children():
			if area is Area3D and area.get_meta("action", "") == onto:
				_sleep(area.get_meta("lie_at"), area.get_meta("lie_yaw"))
				return
	_pass_out()


## 5:00 and nowhere to sleep: you pass out on the street. Two wheels decide the cost.
func _pass_out() -> void:
	Game.modal_open = true
	Game.clock_running = false
	_hud.set_prompt("")
	if _inside != "":
		# Wherever you were, they throw you out.
		await _leave()
		Game.modal_open = true
	await _player.lie_down(_player.global_position + Vector3(0, 0.14, 0), _player.facing(), false)
	await get_tree().create_timer(0.6).timeout

	var damages: Array = Settings.STREET_DAMAGE
	var hit := Game.rng.randi() % damages.size()
	var labels: Array = damages.map(func(d): return "-%d" % d)
	await _wheel.spin("5:00. You pass out on the street.\nSpin to see what the night does to you.",
		labels, [Color(0.25, 0.3, 0.45), Color(0.4, 0.3, 0.5), Color(0.55, 0.3, 0.4), Color(0.7, 0.25, 0.25)],
		hit, "Wellbeing -%d" % damages[hit])
	Game.wellbeing = clampi(Game.wellbeing - damages[hit], 0, 100)

	if Game.cash > 0:
		# Looks like an even chance. It isn't.
		var robbed := Game.rng.randf() < Settings.ROBBED_CHANCE
		var slots := [0, 2, 4] if robbed else [1, 3, 5]
		var lost := Game.cash
		await _wheel.spin("You have %d euro in your pockets.\nSpin to see if it's still there in the morning." % Game.cash,
			["ROBBED", "SAFE", "ROBBED", "SAFE", "ROBBED", "SAFE"], [Color(0.6, 0.08, 0.08), Color(0.08, 0.08, 0.08)],
			slots[Game.rng.randi() % 3], ("ROBBED. All %d euro is gone." % lost) if robbed else "SAFE. Your money is still there.")
		if robbed:
			Game.cash = 0
			Game.add_note("I passed out on the street and woke up with empty pockets. %d euro, gone." % lost)

	await _transition.fade(1.0, 1.0)
	await _transition.roll_clock(Game.minutes_until(Settings.WAKE_HOUR), 3.0, "…")
	Game.shelter_host = null
	Game.night_survived = true
	Game.shelter_changed.emit()
	await _transition.fade(0.0, 1.5)
	await _player.stand_up()
	Game.modal_open = false
	Game.clock_running = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var morning := Game.wake_up(false)
	_autosave()
	_hud.show_message("You wake up on the pavement. It's 9:00.%s Game saved." % morning)


## The game saves itself each time you wake up. There is one save and no manual saving.
func _autosave() -> void:
	if Game.wellbeing > 0:
		Game.save_game(_inside, _player.global_position)


## Starting the game with a save: carry on, or throw it away and start over.
func _ask_continue() -> void:
	_show_end("Midalia\n\nYou have a saved game.\nDay %d, %s. Wellbeing %d%%." % [Game.day, Game.clock_text(), Game.wellbeing], "Continue", false, "New game")


## The three hours of forms at the bank, shown as time rolling by.
func _wait_at_bank(game_minutes: int) -> void:
	Game.clock_running = false
	await _transition.fade(1.0, 0.8)
	await _transition.roll_clock(game_minutes, 3.0, "Forms. A stamp. More forms. Another stamp.")
	await _transition.fade(0.0, 0.8)
	Game.clock_running = true


## The first build's finish line: you got through a night and have a bank account.
func _on_bank_closed() -> void:
	if not Game.bank_account or not Game.night_survived or Game.survived_shown:
		return
	Game.survived_shown = true
	var friends := Game.contacts.filter(func(p): return p.is_friend).size()
	var text := "You survived.\n\nOne night in Milan and one Italian bank account.\n\n"
	text += "Wellbeing %d%%\nIn your pocket: %d euro\nIn the bank: %d euro\n" % [Game.wellbeing, Game.cash, Game.bank_balance]
	text += "Numbers in your phone: %d\nFriends: %d\n" % [Game.contacts.size() - 4, friends]
	text += "Tuition: %s" % ("paid" if Game.tuition_owed <= 0 else "%d euro still owed" % Game.tuition_owed)
	_show_end(text, "Keep playing", false)


func _show_game_over() -> void:
	_game_over = true
	Game.delete_save()
	_show_end("Your wellbeing hit zero.\nMilan won. You go home on day %d." % Game.day, "", true)


## A full-screen ending. A non-empty keep_playing adds a button that closes it and carries on.
func _show_end(text: String, keep_playing: String, final: bool, restart: String = "Start again") -> void:
	Game.modal_open = true
	Game.clock_running = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var layer := CanvasLayer.new()
	layer.layer = 30
	add_child(layer)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.9)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 20)
	dim.add_child(column)
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 32 if final else 26)
	column.add_child(label)
	if keep_playing != "":
		var carry_on := Button.new()
		carry_on.text = keep_playing
		carry_on.custom_minimum_size = Vector2(220, 56)
		carry_on.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		carry_on.pressed.connect(func():
			layer.queue_free()
			Game.modal_open = false
			Game.clock_running = true
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED)
		column.add_child(carry_on)
	var again := Button.new()
	again.text = restart
	again.custom_minimum_size = Vector2(220, 56)
	again.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	again.pressed.connect(func():
		Game.delete_save()
		Game.reset()
		get_tree().reload_current_scene())
	column.add_child(again)


# --- Building the world ---

func _build_sky() -> void:
	_sun = DirectionalLight3D.new()
	_sun.shadow_enabled = true
	add_child(_sun)
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.25, 0.45, 0.8)
	sky_material.sky_horizon_color = Color(0.7, 0.78, 0.9)
	sky_material.ground_horizon_color = Color(0.7, 0.78, 0.9)
	var sky := Sky.new()
	sky.sky_material = sky_material
	_environment = Environment.new()
	_environment.background_mode = Environment.BG_SKY
	_environment.sky = sky
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_environment.ambient_light_color = Color(0.55, 0.6, 0.75)
	_environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_environment := WorldEnvironment.new()
	world_environment.environment = _environment
	add_child(world_environment)


## One of the game's doors, on a real wall. A "lot" node sits at the door, turned
## so that its own -Z points into the building; everything else is placed relative to it.
func _build_door(place: Dictionary, at: Dictionary) -> void:
	var lot := Node3D.new()
	lot.position = Vector3(at.x, 0, at.z)
	lot.rotation.y = at.yaw
	add_child(lot)
	Build.box(lot, Vector3(0, 1.2, 0.05), Vector3(1.6, 2.4, 0.1), Color(0.25, 0.15, 0.1))  # door
	var sign := Label3D.new()
	sign.text = place.sign
	sign.font_size = 96
	sign.pixel_size = 0.012
	sign.outline_size = 24
	sign.position = Vector3(0, 3.3, 0.15)
	lot.add_child(sign)
	# A second sign sticks out from the wall, to be read from down the street, with a lamp over the door.
	Build.box(lot, Vector3(0, 5.0, 1.0), Vector3(0.12, 0.9, 2.0), Color(0.12, 0.12, 0.14))
	for side in [-1, 1]:
		Build.sign(lot, Vector3(side * 0.07, 5.0, 1.0), place.sign, 44, side * PI / 2)
	_lamps.append(Build.light(lot, Vector3(0, 3.6, 1.2), Color(1.0, 0.85, 0.6), 2.0, 9.0))
	var doorstep := Build.trigger(lot, Vector3(0, 1.5, 2), Vector3(4, 3, 4), place.prompt, place.action)
	doorstep.set_meta("sign", place.sign)
	doorstep.set_meta("message", place.get("message", ""))
	doorstep.set_meta("hours", place.get("hours", []))
	if place.action == "flat":
		_flat_doors[place.sign] = doorstep
	# Coming back out, you stand on the doorstep with your back to the building.
	_street_doors[place.sign] = [lot.to_global(Vector3(0, 0.1, 2.5)), lot.rotation.y + PI]


func _build_interiors() -> void:
	_interiors["SUPERMERCATO"] = Shops.supermarket(self, INTERIORS_AT + Vector3(220, 0, 0))
	_interiors["ALIMENTARI"] = Shops.corner(self, INTERIORS_AT + Vector3(220, 0, 60), Color(0.9, 0.85, 0.7), "ALIMENTARI", 3)
	_interiors["MINIMARKET"] = Shops.corner(self, INTERIORS_AT + Vector3(220, 0, 120), Color(0.8, 0.88, 0.85), "MINIMARKET", 8)
	_interiors["BENZINA"] = Shops.gas(self, INTERIORS_AT + Vector3(220, 0, 180))
	_interiors["VIA ROMA 12"] = Interiors.party(self, INTERIORS_AT)
	_interiors["BANCA"] = Interiors.bank(self, INTERIORS_AT + Vector3(0, 0, 60))
	_interiors["STAZIONE CENTRALE"] = Interiors.station(self, INTERIORS_AT + Vector3(100, 0, 0))
	_interiors["UNIVERSITÀ"] = Interiors.university(self, INTERIORS_AT + Vector3(100, 0, 60))
	var i := 0
	for sign in FLAT_LOOKS:
		i += 1
		_interiors[sign] = Interiors.flat(self, INTERIORS_AT + Vector3(0, 0, 60 + i * 60), FLAT_LOOKS[sign][0], FLAT_LOOKS[sign][1])

	# The six students at the party.
	var party_room: Node3D = _interiors["VIA ROMA 12"].room
	var spots := [Vector3(-5.5, 0, -1.5), Vector3(-2.5, 0, -3.3), Vector3(2.2, 0, -3), Vector3(5, 0, -1.5), Vector3(-4, 0, 2), Vector3(4.5, 0, 2.5)]
	for n in Game.partygoers.size():
		var person := Game.partygoers[n]
		var spot: Vector3 = spots[n % spots.size()]
		# Facing the middle of the room.
		_add_npc(person, party_room, spot, atan2(spot.x, spot.z)).get_meta("figure").mood = "dance"


## Someone you can walk up to and talk to, with their name over their head.
func _add_npc(person: Person, room: Node3D, spot: Vector3, yaw: float) -> Node3D:
	var npc := Build.person(room, spot, yaw, person.look)
	var tag := Label3D.new()
	tag.text = person.name
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.font_size = 48
	tag.pixel_size = 0.006
	tag.outline_size = 12
	tag.position.y = 2.15
	npc.add_child(tag)
	var reach := Build.trigger(npc, Vector3(0, 1, 0), Vector3(2.6, 2, 2.6), "Talk to %s" % person.name, "talk")
	reach.set_meta("person", person)
	_npcs[person] = npc
	return npc


func _build_lamp(at: Vector3) -> void:
	Build.box(self, at + Vector3(0, 2.5, 0), Vector3(0.15, 5, 0.15), Color(0.15, 0.15, 0.15))
	_lamps.append(Build.light(self, at + Vector3(0, 5.2, 0), Color(1.0, 0.8, 0.55), 2.5, 16.0))
