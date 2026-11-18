class_name Rules
## The game's rules decide what happens. The language model never does.

const TONES := ["nice", "banter", "too_nice", "mean"]
const REQUESTS := ["none", "shelter", "loan", "info"]

## The decisive words of a reply are written here, never by the language model,
## so the player always knows what happened. One is picked at random.
const OPENERS := {
	"mean": ["wow ok. not helping you.", "nah. don't text me like that.", "lol no. bye."],
	"shelter_yes": ["yeah sure, you can crash on my couch tonight.", "ok fine, the couch is yours tonight.", "sure, come over, you can sleep here."],
	"shelter_no": ["nah sorry, can't have you over tonight.", "not tonight, sorry.", "sorry, no space at mine."],
	"loan_yes": ["ok, i can lend you %d euro.", "fine, i'll give you %d euro.", "alright, %d euro, but i want it back."],
	"loan_no": ["sorry, can't lend you anything right now.", "nah, no money to spare.", "can't, i'm broke too."],
	"info_yes": ["yeah i know, i'll tell you.", "sure, i can help with that."],
	"info_no": ["no idea, sorry.", "dunno, google it."],
}


## Works out the result of one message from the player to a person.
## `state` holds the player's numbers: wellbeing, cash, street_cred, mean_to (names).
## Returns what changed plus an instruction telling the model how to reply.
static func resolve(person: Person, tone: String, request: String, in_person: bool,
		state: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var result := {
		"granted": false, "became_friend": false, "strangers_mad": false,
		"chance": 0.0, "wellbeing": 0, "cash": 0, "street_cred": 0,
		"instruction": "", "opener": "", "summary": "",
	}

	person.opinion = clampi(person.opinion + Settings.OPINION_CHANGE[tone], -100, 100)

	if tone == "mean":
		result.wellbeing += Settings.REJECTED_WELLBEING
		if not state.mean_to.has(person.name):
			state.mean_to.append(person.name)
			if state.mean_to.size() >= Settings.MEAN_PEOPLE_LIMIT:
				result.strangers_mad = true
				result.street_cred += Settings.STRANGERS_MAD_CRED
				result.wellbeing += Settings.STRANGERS_MAD_WELLBEING
		person.remember("They were rude to you.")
		result.opener = _pick("mean", rng)
		result.instruction = "They were rude to you. Refuse to help and tell them off in one short text."
		result.summary = "Rejected for being mean"
		return _apply(result, state)

	if tone == "banter" and not person.is_friend and person.opinion >= Settings.FRIEND_OPINION:
		person.is_friend = true
		result.became_friend = true
		result.wellbeing += Settings.NEW_FRIEND_WELLBEING
		result.street_cred += Settings.NEW_FRIEND_CRED
		person.remember("You two joke around and became friends.")

	if request == "none":
		match tone:
			"banter": result.instruction = "They teased you in a friendly way. Tease them back, like a friend would."
			"too_nice": result.instruction = "They are being overly sweet and a bit clingy. Be polite but slightly put off."
			_: result.instruction = "They are being friendly. Reply in a friendly, casual way."
		result.summary = "Just chatting" + (", new friend" if result.became_friend else "")
		return _apply(result, state)

	var chance: float = Settings.GRANT_CHANCE[tone]
	chance += person.opinion * Settings.GRANT_PER_OPINION
	chance += state.street_cred * Settings.GRANT_PER_CRED
	if in_person:
		chance += Settings.GRANT_IN_PERSON_BONUS
	chance = clampf(chance, 0.0, 0.95)
	result.chance = chance
	result.granted = rng.randf() < chance

	var ask: String = {"shelter": "a place to sleep tonight", "loan": "to borrow some money", "info": "for information"}[request]
	if result.granted:
		match request:
			"shelter": person.remember("You offered them your couch for tonight.")
			"loan":
				result.cash += Settings.LOAN_AMOUNT
				person.remember("You lent them %d euro and they owe you." % Settings.LOAN_AMOUNT)
			"info": person.remember("You gave them some useful info.")
		result.opener = _pick(request + "_yes", rng)
		result.instruction = "They asked you %s. Say yes in one short, casual text." % ask
		result.summary = "Asked for %s: yes" % request
	else:
		result.wellbeing += Settings.REJECTED_WELLBEING
		person.remember("They asked you %s and you said no." % ask)
		result.opener = _pick(request + "_no", rng)
		result.instruction = "They asked you %s. Say no with a lame excuse, in one short text." % ask
		result.summary = "Asked for %s: no" % request
	return _apply(result, state)


static func _pick(key: String, rng: RandomNumberGenerator) -> String:
	var line: String = OPENERS[key][rng.randi() % OPENERS[key].size()]
	return line % Settings.LOAN_AMOUNT if line.contains("%d") else line


static func _apply(result: Dictionary, state: Dictionary) -> Dictionary:
	state.wellbeing = clampi(state.wellbeing + result.wellbeing, 0, 100)
	state.cash += result.cash
	state.street_cred = clampi(state.street_cred + result.street_cred, -100, 100)
	return result
