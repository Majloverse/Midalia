class_name Rules
## The game's rules decide what happens. The language model never does.

const TONES := ["nice", "banter", "too_nice", "mean"]
const REQUESTS := ["none", "room", "shelter", "loan", "info"]

## The decisive words of a reply are written here, never by the language model,
## so the player always knows what happened. One is picked at random.
const OPENERS := {
	"mean": ["wow ok. not helping you.", "nah. don't text me like that.", "lol no. bye."],
	"shelter_yes": ["yeah sure, you can crash on my couch tonight.", "ok fine, the couch is yours tonight.", "sure, come over, you can sleep here."],
	"shelter_no": ["nah sorry, can't have you over tonight.", "not tonight, sorry.", "sorry, no space at mine."],
	"room_yes": ["ok, you can have the spare room. %d euro a week.", "yeah alright, the spare room is yours for %d euro a week.", "fine, we need a flatmate anyway. %d euro a week."],
	"room_no": ["nah sorry, the room's not free.", "sorry, we're not looking for a flatmate.", "no can do, the room's taken."],
	"loan_yes": ["ok, i can lend you %d euro.", "fine, i'll give you %d euro.", "alright, %d euro, but i want it back."],
	"loan_no": ["sorry, can't lend you anything right now.", "nah, no money to spare.", "can't, i'm broke too."],
	"info_yes": ["yeah i know, i'll tell you.", "sure, i can help with that."],
	"info_no": ["no idea, sorry.", "dunno, google it."],
	# Family
	"family_mean": ["Excuse me? Do not speak to me like that.", "Watch your mouth. We'll talk when you calm down."],
	"family_no_account": ["We can only send money by bank transfer. Open an Italian account first.", "I can't send cash abroad. Get a bank account there and send me the details."],
	"family_shelter": ["Sweetheart, we're in another country. You need to find somewhere there.", "I wish I could help, but we're a plane ride away. Ask the people you meet."],
	"parent_yes": ["Fine. I've sent you %d euro.", "Ok, %d euro is on its way. Make it last."],
	"parent_mad": ["Again?! Do you think we are made of money? No. Not this time.", "No. You keep asking and asking. Learn to manage what you have."],
	"grandpa_yes": ["Of course, my dear. I sent you %d euro. Don't tell your parents.", "Here is %d euro from your old grandpa. Eat something warm."],
	"grandpa_wait": ["I sent you money not long ago, my dear. My pension only comes so often.", "Not yet, little one. Ask me again in a while."],
	"sister_nice": ["aww hey you! miss you already.", "hey baby sibling! how's italy treating you?"],
	"sister_nasty": ["ugh. what do you want now.", "oh great, it's you. make it quick."],
	"sister_no_money": ["lol i'm broke too. ask mom.", "money? from me? ask dad, good luck."],
}


## Works out the result of one message from the player to a person.
## `state` holds the player's numbers (wellbeing, cash, street_cred, mean_to...):
## either the Game autoload or, in the texting test, a plain Dictionary.
## Returns what changed plus the words that tell the model how to reply.
static func resolve(person: Person, tone: String, request: String, in_person: bool,
		state, rng: RandomNumberGenerator) -> Dictionary:
	var result := {
		"granted": false, "became_friend": false, "strangers_mad": false,
		"chance": 0.0, "wellbeing": 0, "cash": 0, "bank": 0, "street_cred": 0,
		"instruction": "", "opener": "", "summary": "",
	}
	person.opinion = clampi(person.opinion + Settings.OPINION_CHANGE[tone], -100, 100)
	if person.kind == "family":
		return _apply(_family(person, tone, request, state, rng, result), state)

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
	if request == "room":
		chance -= Settings.ROOM_ASK_PENALTY
		if person.is_friend:
			chance += Settings.ROOM_FRIEND_BONUS
	chance = clampf(chance, 0.0, 0.95)
	result.chance = chance
	# Someone who has already offered you a room doesn't take it back for asking again.
	result.granted = rng.randf() < chance or (request == "room" and person.room_rent > 0)

	var ask: String = {"room": "to rent a room in your flat", "shelter": "a place to sleep tonight", "loan": "to borrow some money", "info": "for information"}[request]
	var amount: int = Settings.LOAN_AMOUNT
	if result.granted:
		match request:
			"room":
				if person.room_rent <= 0:
					person.room_rent = Settings.ROOM_RENT_FRIEND
				amount = person.room_rent
				person.remember("You said they can rent the spare room in your flat for %d euro a week." % amount)
			"shelter": person.remember("You offered them your couch for tonight.")
			"loan":
				result.cash += Settings.LOAN_AMOUNT
				person.remember("You lent them %d euro and they owe you." % Settings.LOAN_AMOUNT)
			"info": person.remember("You gave them some useful info.")
		result.opener = _pick(request + "_yes", rng, amount)
		result.summary = "Asked for %s: yes" % request
	else:
		result.wellbeing += Settings.REJECTED_WELLBEING
		person.remember("They asked you %s and you said no." % ask)
		result.opener = _pick(request + "_no", rng)
		result.summary = "Asked for %s: no" % request
	return _apply(result, state)


## The fixed family contacts follow their own rules.
static func _family(person: Person, tone: String, request: String, state, rng: RandomNumberGenerator, result: Dictionary) -> Dictionary:
	if tone == "mean":
		result.wellbeing += Settings.REJECTED_WELLBEING
		person.remember("They were rude to you.")
		result.opener = _pick("family_mean", rng)
		result.summary = "Family told you off"
		return result

	if person.role == "sister":
		# Her mood is rolled once a day, so texting her is a gamble you take once a day.
		if person.mood_day != state.day:
			person.mood_day = state.day
			var period: bool = state.day >= Settings.SISTER_PERIOD_FIRST_DAY and state.day <= Settings.SISTER_PERIOD_LAST_DAY
			person.nasty = rng.randf() < (Settings.SISTER_NASTY_CHANCE_PERIOD if period else Settings.SISTER_NASTY_CHANCE)
			if person.nasty:
				result.wellbeing += Settings.SISTER_NASTY_WELLBEING_PERIOD if period else Settings.SISTER_NASTY_WELLBEING
			else:
				result.wellbeing += Settings.SISTER_NICE_WELLBEING
		if request == "loan" and not person.nasty:
			result.opener = _pick("sister_no_money", rng)
		else:
			result.opener = _pick("sister_nasty" if person.nasty else "sister_nice", rng)
		result.summary = "Sister is %s today" % ("nasty" if person.nasty else "nice")
		return result

	if request == "shelter" or request == "room":
		result.opener = _pick("family_shelter", rng)
		result.summary = "Family can't house you"
	elif request == "loan":
		if not state.bank_account:
			result.opener = _pick("family_no_account", rng)
			result.summary = "No bank account, no transfer"
			if state is Node:
				state.add_note("Family can only send money by bank transfer. I need an Italian bank account.")
		elif person.role == "grandpa":
			if state.day - person.last_gift_day >= Settings.GRANDPA_DAYS_BETWEEN_GIFTS:
				person.last_gift_day = state.day
				result.granted = true
				result.bank += Settings.GRANDPA_AMOUNT
				result.opener = _pick("grandpa_yes", rng, Settings.GRANDPA_AMOUNT)
				result.summary = "Grandpa sent money"
			else:
				result.opener = _pick("grandpa_wait", rng)
				result.summary = "Grandpa says wait"
		else:
			# Each ask doubles the chance they get mad; it resets once they blow up.
			result.chance = 1.0 - minf(1.0, Settings.PARENT_MAD_CHANCE * pow(2.0, person.asks))
			if rng.randf() < result.chance:
				person.asks += 1
				result.granted = true
				result.bank += Settings.PARENT_AMOUNT
				result.opener = _pick("parent_yes", rng, Settings.PARENT_AMOUNT)
				result.summary = "Parent sent money"
			else:
				person.asks = 0
				result.wellbeing += Settings.PARENT_MAD_WELLBEING
				result.opener = _pick("parent_mad", rng)
				result.summary = "Parent got mad"
	else:
		result.instruction = "Your child just moved to Italy to study and texted you. Reply the way you would, in one or two short texts."
		result.summary = "Chatting with family"
	return result


static func _pick(key: String, rng: RandomNumberGenerator, amount: int = 0) -> String:
	var line: String = OPENERS[key][rng.randi() % OPENERS[key].size()]
	return line % amount if line.contains("%d") else line


static func _apply(result: Dictionary, state) -> Dictionary:
	state.wellbeing = clampi(state.wellbeing + result.wellbeing, 0, 100)
	state.cash += result.cash
	state.street_cred = clampi(state.street_cred + result.street_cred, -100, 100)
	if result.bank != 0:
		state.bank_balance += result.bank
	return result
