class_name Person
extends RefCounted
## Someone you can talk to. Their nature is hidden from the player.

const FIRST_NAMES := ["Luca", "Giulia", "Marco", "Sofia", "Tommaso", "Chiara", "Kenji", "Priya", "Mateus", "Ines", "Felix", "Yara"]
const VIBES := [
	"loud finance bro who talks about crypto",
	"tired design student who chain-smokes",
	"overly friendly exchange student who loves parties",
	"sarcastic law student who judges everyone",
	"gym-obsessed guy who calls everyone bro",
	"rich kid who complains about their allowance",
	"gossip who knows everything about everyone",
	"chill stoner who is always hungry",
]
## The family is the same every game: [role, name, vibe]
const FAMILY := [
	["mom", "Mom", "loving but anxious mother back home who worries about her child abroad"],
	["dad", "Dad", "gruff father back home who thinks kids today are soft and money doesn't grow on trees"],
	["sister", "Sister", "moody older sister back home who is either sweet or savage"],
	["grandpa", "Grandpa", "sweet old grandfather back home who types slowly and mentions the old days"],
]

var name: String
var vibe: String
var kind: String = "met"  # "met" for people you meet, "family" for the fixed contacts
var role: String = ""     # family only: mom, dad, sister or grandpa
var nature: String = "ok"  # "two_faced", "ok" or "true_friend"
var opinion: int = 0  # what they privately think of you, -100..100
var is_friend: bool = false
var memory: Array[String] = []  # short facts about past conversations
var history: Array = []  # the conversation so far: [{"from": "player" or "person", "text": ...}]
var look: Dictionary = {}  # what they look like; see Body

# People you meet only.
var home: String = ""        # the flat they live in, as written on its sign
var betrayal: String = ""    # what a two-faced host has planned: "", "cancel" or "steal"
var cancel_at: int = -1      # when they'll cancel a couch offer (Game.total_minutes), or -1
var room_rent: int = 0       # weekly rent of the room they'd let you have; 0 if they haven't offered one

# Family only.
var asks: int = 0            # money asks since they last got mad (mom, dad)
var last_gift_day: int = -100  # day grandpa last sent money
var mood_day: int = 0        # day the sister's mood was last rolled
var nasty: bool = false      # the sister's mood for that day


static func random(rng: RandomNumberGenerator, forced_nature: String = "") -> Person:
	var p := Person.new()
	p.name = FIRST_NAMES[rng.randi() % FIRST_NAMES.size()]
	p.vibe = VIBES[rng.randi() % VIBES.size()]
	p.nature = forced_nature if forced_nature != "" else _roll_nature(rng)
	p.look = Body.random_look(rng)
	return p


static func family() -> Array[Person]:
	var people: Array[Person] = []
	for entry in FAMILY:
		var p := Person.new()
		p.kind = "family"
		p.role = entry[0]
		p.name = entry[1]
		p.vibe = entry[2]
		people.append(p)
	return people


static func _roll_nature(rng: RandomNumberGenerator) -> String:
	var roll := rng.randi_range(1, 100)
	var total := 0
	for nature in Settings.NATURE_ODDS:
		total += Settings.NATURE_ODDS[nature]
		if roll <= total:
			return nature
	return "two_faced"


## Everything about this person as plain data, for the save file.
func to_data() -> Dictionary:
	return {
		"name": name, "vibe": vibe, "kind": kind, "role": role, "nature": nature, "opinion": opinion,
		"is_friend": is_friend, "memory": memory, "history": history, "look": Body.look_to_data(look),
		"home": home, "room_rent": room_rent, "asks": asks, "last_gift_day": last_gift_day, "mood_day": mood_day, "nasty": nasty,
	}


static func from_data(data: Dictionary) -> Person:
	var p := Person.new()
	p.name = data.name
	p.vibe = data.vibe
	p.kind = data.kind
	p.role = data.role
	p.nature = data.nature
	p.opinion = int(data.opinion)
	p.is_friend = data.is_friend
	p.memory.assign(data.memory)
	p.history = data.history
	p.look = Body.look_from_data(data.look)
	p.home = data.home
	p.room_rent = int(data.get("room_rent", 0))
	p.asks = int(data.asks)
	p.last_gift_day = int(data.last_gift_day)
	p.mood_day = int(data.mood_day)
	p.nasty = data.nasty
	return p


func remember(fact: String) -> void:
	if memory.has(fact):
		return
	memory.append(fact)
	if memory.size() > 6:
		memory.pop_front()
