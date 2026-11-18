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

var name: String
var vibe: String
var nature: String  # "two_faced", "ok" or "true_friend"
var opinion: int = 0  # what they privately think of you, -100..100
var is_friend: bool = false
var memory: Array[String] = []  # short facts about past conversations


static func random(rng: RandomNumberGenerator, forced_nature: String = "") -> Person:
	var p := Person.new()
	p.name = FIRST_NAMES[rng.randi() % FIRST_NAMES.size()]
	p.vibe = VIBES[rng.randi() % VIBES.size()]
	p.nature = forced_nature if forced_nature != "" else _roll_nature(rng)
	return p


static func _roll_nature(rng: RandomNumberGenerator) -> String:
	var roll := rng.randi_range(1, 100)
	var total := 0
	for nature in Settings.NATURE_ODDS:
		total += Settings.NATURE_ODDS[nature]
		if roll <= total:
			return nature
	return "two_faced"


func remember(fact: String) -> void:
	memory.append(fact)
	if memory.size() > 6:
		memory.pop_front()
