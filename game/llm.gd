class_name LLM
extends RefCounted
## The only place that talks to the language models, so they can be swapped.
## Three jobs, each done the most reliable way:
##  - what the player asked for: keyword rules
##  - the tone of the player's message: compared by meaning against examples
##  - the person's reply: the game writes the decisive words, the chat model adds personality

## Example messages for each tone. Add more to make tone sorting more accurate.
const TONE_EXAMPLES := {
	"nice": [
		"hey! really nice meeting you tonight, hope you got home ok",
		"thanks so much for the help earlier, i appreciate it",
		"hi, how are you doing today?",
		"could you help me with something when you have a minute? thanks",
		"good luck with your exam tomorrow",
		"excuse me, do you know how to get to the station?",
		"would it be ok if i stayed at your place tonight? no worries if not",
		"hey, any chance you could lend me a bit of money? i'll pay it back friday",
		"that was a fun night, we should do it again",
		"hope you're feeling better",
	],
	"banter": [
		"lol you dance like a broken fridge, but ok respect",
		"you absolute clown, save me a seat tomorrow",
		"nice haircut, did you lose a bet? jk it looks fine",
		"oi loser, you coming out tonight or what",
		"you're the worst cook i know and i love you for it",
		"bro you talk so much shit, come get a beer with me",
		"haha you idiot, that was hilarious last night",
		"lend me a tenner you cheapskate, i'll buy you a drink later lol",
		"you still alive after last night you animal?",
		"move over fatass, i'm crashing on your couch tonight haha",
	],
	"too_nice": [
		"you are the most amazing wonderful person ever, i would do anything for you, please please",
		"omg you're so perfect and smart and beautiful, i'm so sorry to bother you, sorry sorry",
		"i'm so so sorry to ask, you're such an incredible generous soul, please forgive me",
		"you are my hero, my idol, i worship you, thank you thank you thank you",
		"i would be eternally grateful forever, you are the kindest person in the whole world",
		"please please please, i'm begging you, you're the best most beautiful person alive",
		"i love you so much, you're an angel sent from heaven, i don't deserve you",
		"sorry sorry sorry for existing, you're so wonderful, may i please humbly ask a tiny favour",
		"you are perfection itself, everything you do is amazing, i adore you",
		"i'm so unworthy of your time, thank you endlessly, you're a saint",
	],
	"mean": [
		"shut up, nobody likes you",
		"you're a useless idiot, give me what i want",
		"fuck you, you piece of garbage",
		"i hate you, you're pathetic",
		"give me your money now, loser",
		"you're ugly and stupid and everyone laughs at you",
		"get lost, i don't want to talk to trash like you",
		"answer me you dumb bitch",
		"you're worthless, do what i say",
		"go to hell you fake asshole",
	],
}
## Requests are spotted by keywords: plain rules are more reliable here than a tiny model.
const REQUEST_WORDS := {
	"shelter": ["couch", "sleep", "crash", "stay at", "stay with", "stay over", "place to stay", "spare room", "sofa", "your place", "at yours"],
	"loan": ["lend", "borrow", "loan", "money", "euro", "cash", "spot me", "pay you back"],
	"info": ["where", "how do", "how can", "do you know", "what time", "which", "bank account", "directions"],
}
## [name, vibe, player text, the person's first line (written by the game), the line the model adds]
const FLAVOUR_EXAMPLES := [
	["Dario", "loud football fan", "can i crash at yours tonight?", "yeah sure, couch is yours.", "bring beer, the match is on at 9"],
	["Elena", "sarcastic med student", "could you lend me 30 euro?", "nah, can't right now.", "i have like 4 euro and an anatomy exam"],
	["Nico", "sleepy barista", "shut up you loser", "wow ok. lose my number.", "i've been up since 5 making coffee for people nicer than you"],
	["Marta", "party girl", "do you know where the bank is?", "yeah, it's right by the station.", "next to that bar with the 3 euro spritz"],
]
## [name, vibe, player text, instruction from the rules, reply]
const CHAT_EXAMPLES := [
	["Dario", "loud football fan", "hey, good to meet you last night", "They are being friendly. Reply in a friendly, casual way.", "yeah you too man! you watching the game sunday?"],
	["Marta", "party girl", "your dancing was tragic last night lol", "They teased you in a friendly way. Tease them back, like a friend would.", "says the one who fell off the table lmaooo"],
	["Elena", "sarcastic med student", "you are so perfect and amazing, i adore you", "They are being overly sweet and a bit clingy. Be polite but slightly put off.", "uh... thanks? bit much but ok"],
]

var _reply_chat
var _encoder
var _tone_vectors := {}  # tone -> Array of example vectors


## Loads the chat model and the tone model. Returns false if either could not be loaded.
func load_models(chat_path: String, tone_path: String) -> bool:
	var model = await NobodyWhoModel.create(chat_path, {})
	if model == null:
		return false
	_reply_chat = await NobodyWhoChat.create(model, {
		"n_ctx": 2048,
		"template_variables": {"enable_thinking": false},
		"sampler": NobodyWhoSamplerPresets.temperature(Settings.REPLY_TEMPERATURE),
	})
	_encoder = await NobodyWhoEncoder.create(tone_path, {})
	if _reply_chat == null or _encoder == null:
		return false
	for tone in TONE_EXAMPLES:
		_tone_vectors[tone] = await _encoder.encode_batch(TONE_EXAMPLES[tone])
	return true


## Sorts a player message into one of Rules.REQUESTS.
static func request_of(text: String) -> String:
	var lower := text.to_lower()
	for request in REQUEST_WORDS:
		for word in REQUEST_WORDS[request]:
			if lower.contains(word):
				return request
	return "none"


## Sorts a player message into one of Rules.TONES by finding the tone whose
## examples are closest in meaning (average of the closest few).
func tone_of(text: String) -> String:
	var vector = await _encoder.encode(text)
	var best_tone := "nice"
	var best_score := -2.0
	for tone in _tone_vectors:
		var scores: Array = []
		for example in _tone_vectors[tone]:
			scores.append(NobodyWhoEncoder.cosine_similarity(vector, example))
		scores.sort()
		var top: Array = scores.slice(-Settings.TONE_CLOSEST_EXAMPLES)
		var score: float = top.reduce(func(a, b): return a + b, 0.0) / top.size()
		if score > best_score:
			best_score = score
			best_tone = tone
	return best_tone


## Writes the person's reply. `history` is the recent conversation as
## [{"from": "player" or "person", "text": ...}], ending with the player's message.
## `result` comes from Rules.resolve. When it has an opener, the game has already
## written the decisive words and the model only adds a line of personality.
func reply(person: Person, history: Array, result: Dictionary) -> String:
	var text: String = history[-1].text
	var messages: Array = []
	if result.opener != "":
		for e in FLAVOUR_EXAMPLES:
			messages.append({"role": "user", "content": _flavour_prompt(e[0], e[1], e[2], e[3])})
			messages.append({"role": "assistant", "content": e[4]})
		messages.append({"role": "user", "content": _flavour_prompt(person.name, person.vibe, text, result.opener)})
	else:
		for e in CHAT_EXAMPLES:
			messages.append({"role": "user", "content": _chat_prompt(e[0], e[1], e[2], e[3])})
			messages.append({"role": "assistant", "content": e[4]})
		messages.append({"role": "user", "content": _chat_prompt(person.name, person.vibe, text, result.instruction)})
	var stream = await _reply_chat.complete(messages, {})
	var written: String = "" if stream == null else _tidy(await stream.completed())
	if result.opener == "":
		return written if written != "" else "lol"
	return (result.opener + " " + written).strip_edges()


func _flavour_prompt(who: String, vibe: String, text: String, opener: String) -> String:
	return "%s is a %s.\nFriend texts: \"%s\"\n%s texts back: \"%s\"\n%s adds one more short line that fits their personality:" % [who, vibe, text, who, opener, who]


func _chat_prompt(who: String, vibe: String, text: String, instruction: String) -> String:
	return "%s is a %s.\nFriend texts: \"%s\"\n%s\n%s texts back:" % [who, vibe, text, instruction, who]


func _tidy(text: String) -> String:
	text = text.strip_edges()
	# Small models sometimes add a second speaker or stage directions; keep the first line only.
	for cut in ["\n", "Friend texts", "Friend:"]:
		var at := text.find(cut)
		if at > 0:
			text = text.substr(0, at)
	if text.length() > Settings.REPLY_MAX_CHARS:
		text = text.substr(0, Settings.REPLY_MAX_CHARS).rstrip(" ,") + "…"
	return text.strip_edges().trim_prefix("\"").trim_suffix("\"")
