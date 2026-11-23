extends Node
## Autoload "Game": the player's numbers, the clock, the contacts and the controls.

signal minute_passed
signal models_ready
signal night_ended          # the clock reached 5:00
signal notice(text: String)  # something the player should see on screen
signal shelter_changed
signal home_lost(sign: String)  # you no longer live in the flat with this sign
signal food_changed
signal goods_changed

const FLATS := ["VIA VERDI 3", "VIA DANTE 7", "VIA MILANO 21"]
## What a two-faced flatmate tells people about you.
const SECRETS := [
	"you cry on the phone to your mom every night",
	"you wash your socks in the kitchen sink",
	"you asked how a washing machine works",
	"you count your coins before buying pasta",
	"you practise Italian in the mirror and it's terrible",
	"you eat their leftovers when you think nobody's looking",
]
const SAVE_PATH := "user://midalia_save.json"
## Which street map a save's position belongs to. Change it when the streets move.
const MAP := "milan-1"

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

## The flat you rent a room in (its sign), or "" while you have no home.
var home: String
## Whoever you rent the room from, or null.
var flatmate: Person
## Weekly rent, and the day the next week is due.
var rent: int
var rent_due_day: int
var nights_home: int
var rent_raised: bool
## When a flatmate will throw you out (Game.total_minutes), or -1.
var kick_at: int
## Strangers with a room advertised on the university notice board.
var landlords: Array[Person]
var ate_today: bool
var snacks_today: int
## Food you own (ids from Food.ITEMS). It sits in your kitchen when you have a home, in your bag when you don't.
var food: Array[String]
## What you've picked up in a shop and not paid for yet: [{"item": id, "price": euro}]
var cart: Array
## Marketplace goods you own (ids from Settings.GOODS).
var owned: Array[String]
var study_hours: float
## The sign of the building the player is in, or "" on the street. Kept up to date by the world.
var inside := ""

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
var saved_map := ""

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
	home = ""
	flatmate = null
	rent = 0
	rent_due_day = 0
	nights_home = 0
	rent_raised = false
	kick_at = -1
	ate_today = false
	snacks_today = 0
	food = []
	cart = []
	owned = []
	study_hours = 0.0
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
	# Strangers with a room to let, one per flat. Their adverts hang on the university notice board.
	landlords = []
	var rents: Array = Settings.ROOM_RENTS_BOARD.duplicate()
	for flat in FLATS:
		var p := Person.random(rng)
		p.name = names.pop_at(rng.randi() % names.size())
		p.home = flat
		p.room_rent = rents.pop_at(rng.randi() % rents.size())
		landlords.append(p)
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
		_check_kicked_out()
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
	people.append_array(landlords)
	var data := {
		"home": home, "flatmate": people.find(flatmate), "rent": rent, "rent_due_day": rent_due_day,
		"nights_home": nights_home, "rent_raised": rent_raised, "kick_at": kick_at, "ate_today": ate_today,
		"landlords": landlords.map(func(p): return people.find(p)),
		"food": food, "owned": owned, "study_hours": study_hours, "snacks_today": snacks_today,
		"wellbeing": wellbeing, "cash": cash, "street_cred": street_cred, "day": day, "minutes": minutes,
		"bank_account": bank_account, "bank_balance": bank_balance, "tuition_owed": tuition_owed,
		"notebook": notebook, "mean_to": mean_to, "night_survived": night_survived, "survived_shown": survived_shown,
		"people": people.map(func(p): return p.to_data()),
		"contacts": contacts.map(func(p): return people.find(p)),
		"partygoers": partygoers.map(func(p): return people.find(p)),
		"inside": inside, "position": [position.x, position.y, position.z], "map": MAP,
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
	# Saves from before the second quest have none of these; they keep the fresh values from reset().
	if data.has("landlords"):
		landlords.assign(data.landlords.map(func(i): return people[int(i)]))
		home = data.home
		flatmate = people[int(data.flatmate)] if int(data.flatmate) >= 0 else null
		rent = int(data.rent)
		rent_due_day = int(data.rent_due_day)
		nights_home = int(data.nights_home)
		rent_raised = data.rent_raised
		kick_at = int(data.kick_at)
		ate_today = data.ate_today
	food.assign(data.get("food", []))
	owned.assign(data.get("owned", []))
	study_hours = data.get("study_hours", 0.0)
	snacks_today = int(data.get("snacks_today", 0))
	saved_inside = data.inside
	saved_map = data.get("map", "")
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
		if request == "room" and result.granted:
			result.opener += " i'm at %s, come by and pay the first week." % person.home.capitalize()
			add_note("%s will rent me a room at %s for %d euro a week. I move in by going there and paying the first week." % [person.name, person.home.capitalize(), person.room_rent])
			shelter_changed.emit()
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


# --- Food ---

## Takes money from your pocket first, then from the bank account. Returns false if you can't cover it.
func pay(amount: int) -> bool:
	if cash + (bank_balance if bank_account else 0) < amount:
		return false
	var from_cash := mini(cash, amount)
	cash -= from_cash
	bank_balance -= amount - from_cash
	return true


## One proper meal a day is what counts. Returns what to tell the player.
func eat(price: int, gain: int, what: String) -> String:
	if ate_today:
		return "You've already eaten today. Save your money."
	if not pay(price):
		return "You can't afford it. It costs %d euro." % price
	ate_today = true
	wellbeing = clampi(wellbeing + gain, 0, 100)
	return "%s -%d euro. Wellbeing +%d." % [what, price, gain]


func cart_total() -> int:
	var total := 0
	for line in cart:
		total += line.price
	return total


## Pays for the basket at the till. Returns false if you can't afford it.
func check_out() -> bool:
	if not pay(cart_total()):
		return false
	for line in cart:
		food.append(line.item)
	cart = []
	food_changed.emit()
	return true


## Eats one thing you own. Cooking needs your own kitchen. Returns what to tell the player.
func eat_item(id: String) -> String:
	var item: Dictionary = Food.ITEMS[id]
	if not food.has(id):
		return "You don't have that."
	if item.kind == "cook" and (home == "" or inside != home):
		return "%s needs cooking, and you need your own kitchen for that." % item.name
	if item.kind == "snack":
		if snacks_today >= Settings.SNACKS_PER_DAY:
			return "Enough snacks for one day. You feel a bit sick."
		snacks_today += 1
	else:
		if ate_today:
			return "You've already had a proper meal today. Keep it for tomorrow."
		ate_today = true
	food.erase(id)
	wellbeing = clampi(wellbeing + item.gain, 0, 100)
	food_changed.emit()
	var how := "You cook and eat the %s." if item.kind == "cook" else "You have the %s."
	return (how % item.name.to_lower()) + " Wellbeing +%d." % item.gain


# --- Your room ---

func good(id: String) -> Dictionary:
	for entry in Settings.GOODS:
		if entry.id == id:
			return entry
	return {}


## Buys something from the online marketplace. Returns what to tell the player.
func buy_good(id: String) -> String:
	var entry := good(id)
	if owned.has(id):
		return "You already have that."
	if not bank_account:
		return "Online payments need an Italian bank account."
	if bank_balance < entry.price:
		return "Not enough in your account (%d euro)." % bank_balance
	bank_balance -= entry.price
	owned.append(id)
	var text := "Ordered. A courier with no helmet drops it off within the minute."
	if id == "plant":
		wellbeing = clampi(wellbeing + Settings.PLANT_WELLBEING, 0, 100)
		text += " Wellbeing +%d." % Settings.PLANT_WELLBEING
	elif id == "poster":
		wellbeing = clampi(wellbeing + Settings.POSTER_WELLBEING, 0, 100)
		text += " Wellbeing +%d." % Settings.POSTER_WELLBEING
	goods_changed.emit()
	return text


## Hours with the books. The clock is moved separately. Returns what to tell the player.
func study(hours: int) -> String:
	var counted := hours * (Settings.TEXTBOOK_STUDY_BONUS if owned.has("textbook") else 1.0)
	study_hours += counted
	if owned.has("textbook"):
		return "You studied for %d hours. With the textbook that counts as %.1f. Hours studied: %.1f." % [hours, counted, study_hours]
	return "You studied for %d hours. Hours studied: %.1f." % [hours, study_hours]


# --- A room of your own ---

## Everyone you know of who would rent you a room in this flat.
func rooms_at(sign: String) -> Array[Person]:
	var found: Array[Person] = []
	for p in contacts:
		if p.room_rent > 0 and p.home == sign:
			found.append(p)
	return found


## Reading the adverts on the university notice board puts the landlords in your phone.
func read_board() -> String:
	var text := "Rooms to rent:"
	for p in landlords:
		if p.room_rent <= 0:
			continue
		text += "\n%s, %d euro a week. Ask for %s." % [p.home.capitalize(), p.room_rent, p.name]
		add_note("Room to rent at %s: %d euro a week. Ask for %s." % [p.home.capitalize(), p.room_rent, p.name])
		if not contacts.has(p):
			contacts.append(p)
	shelter_changed.emit()
	return text + "\nTheir numbers are in your phone. Ring the bell at a flat to move in."


## Pays the first week and makes the flat your home. Returns false if you can't pay.
func move_in(person: Person) -> bool:
	if not pay(person.room_rent):
		return false
	home = person.home
	flatmate = person
	rent = person.room_rent
	rent_due_day = day + Settings.RENT_DAYS
	nights_home = 0
	rent_raised = false
	kick_at = -1
	shelter_host = null
	person.remember("They moved into your spare room and pay you %d euro a week." % rent)
	add_note("I live at %s now, with %s. Rent is %d euro a week, next due on day %d." % [home.capitalize(), person.name, rent, rent_due_day])
	shelter_changed.emit()
	return true


## A night in your own bed. The clock is moved separately, by the sleeping animation.
func sleep_in_bed() -> String:
	night_survived = true
	var gain: int = Settings.BED_WELLBEING + (Settings.DUVET_WELLBEING if owned.has("duvet") else 0)
	wellbeing = clampi(wellbeing + gain, 0, 100)
	return "You slept in your own bed. Wellbeing +%d." % gain


## Everything that catches up with you in the morning: hunger, the rent, and
## what your flatmate got up to. Returns what to tell the player.
func wake_up(slept_at_home: bool) -> String:
	var text := ""
	if not ate_today:
		wellbeing = clampi(wellbeing + Settings.HUNGRY_WELLBEING, 0, 100)
		text += " You went a whole day without eating. Wellbeing %d." % Settings.HUNGRY_WELLBEING
	ate_today = false
	snacks_today = 0
	if home == "":
		return text
	if slept_at_home:
		nights_home += 1
		text += _flatmate_night()
	if day >= rent_due_day:
		if pay(rent):
			rent_due_day += Settings.RENT_DAYS
			text += " Rent day: %d euro to %s." % [rent, flatmate.name]
		else:
			wellbeing = clampi(wellbeing + Settings.EVICTED_WELLBEING, 0, 100)
			text += " Rent day, and you can't pay %d euro. %s throws you out. Wellbeing %d." % [rent, flatmate.name, Settings.EVICTED_WELLBEING]
			flatmate.remember("They couldn't pay the rent, so you threw them out.")
			add_note("I couldn't pay the rent. %s threw me out." % flatmate.name)
			_lose_home()
	return text


## What a two-faced flatmate does while you sleep. At most one thing a night.
func _flatmate_night() -> String:
	if flatmate.nature != "two_faced":
		return ""
	var settled := nights_home > Settings.FLATMATE_SAFE_NIGHTS
	var roll := rng.randf()
	roll -= Settings.FLATMATE_STEAL_CHANCE
	if roll < 0.0:
		if cash <= 0 or owned.has("lock"):
			return ""
		var stolen := maxi(1, int(cash * rng.randf_range(Settings.STEAL_SHARE_MIN, Settings.STEAL_SHARE_MAX)))
		cash -= stolen
		flatmate.remember("You took some of their money while they slept. They don't know it was you.")
		add_note("%d euro went missing from my room at %s." % [stolen, home.capitalize()])
		return " %d euro is missing from your room." % stolen
	roll -= Settings.FLATMATE_EAT_CHANCE
	if roll < 0.0:
		if food.is_empty() or owned.has("fridge"):
			return ""
		var eaten: String = food.pop_at(rng.randi() % food.size())
		flatmate.remember("You ate their food from the kitchen and said nothing.")
		add_note("My %s vanished from the kitchen at %s." % [Food.name_of(eaten).to_lower(), home.capitalize()])
		food_changed.emit()
		return " Your %s is gone from the kitchen. Nobody knows anything." % Food.name_of(eaten).to_lower()
	roll -= Settings.FLATMATE_GOSSIP_CHANCE
	if roll < 0.0:
		var secret: String = SECRETS[rng.randi() % SECRETS.size()]
		wellbeing = clampi(wellbeing + Settings.GOSSIP_WELLBEING, 0, 100)
		flatmate.remember("You told people embarrassing things about them behind their back.")
		add_note("%s has been telling people that %s." % [flatmate.name, secret.replace("you ", "I ").replace("your ", "my ")])
		# Someone you know passes it on, if you know anyone.
		var others := contacts.filter(func(p): return p.kind == "met" and p != flatmate)
		if others.is_empty():
			return " You overhear people laughing: %s says %s. Wellbeing %d." % [flatmate.name, secret, Settings.GOSSIP_WELLBEING]
		var teller: Person = others[rng.randi() % others.size()]
		teller.history.append({"from": "person", "text": "hey, thought you should know. %s is telling everyone %s." % [flatmate.name, secret]})
		return " %s texted: %s is telling everyone %s. Wellbeing %d." % [teller.name, flatmate.name, secret, Settings.GOSSIP_WELLBEING]
	roll -= Settings.FLATMATE_RENT_UP_CHANCE
	if roll < 0.0:
		if not settled or rent_raised:
			return ""
		rent_raised = true
		rent = int(rent * (1.0 + Settings.RENT_UP_SHARE) / 5.0) * 5
		flatmate.room_rent = rent
		flatmate.history.append({"from": "person", "text": "hey so the landlord put the rent up. it's %d a week now. nothing i can do." % rent})
		flatmate.remember("You put their rent up to %d euro a week and blamed the landlord." % rent)
		add_note("%s put the rent up to %d euro a week." % [flatmate.name, rent])
		return " %s texted: the rent is now %d euro a week." % [flatmate.name, rent]
	roll -= Settings.FLATMATE_KICK_OUT_CHANCE
	if roll < 0.0 and settled:
		# They'll tell you this evening, when it's too late to find anything else.
		kick_at = day * 1440 + Settings.KICK_OUT_HOUR * 60
	return ""


func _check_kicked_out() -> void:
	if kick_at < 0 or total_minutes() < kick_at:
		return
	kick_at = -1
	flatmate.history.append({"from": "person", "text": "listen, my cousin needs the room. you have to be out tonight. sorry."})
	flatmate.remember("You threw them out of the room with a few hours' notice.")
	add_note("%s threw me out. I need somewhere to sleep tonight." % flatmate.name)
	notice.emit("New message from %s: you have to be out of the room tonight." % flatmate.name)
	_lose_home()


func _lose_home() -> void:
	var old := home
	home = ""
	flatmate.room_rent = 0
	flatmate = null
	rent = 0
	kick_at = -1
	shelter_changed.emit()
	home_lost.emit(old)


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
