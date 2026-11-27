class_name Quests
## What the player should be doing right now, worked out from the game's numbers.
## The map marks the places and the tracker under it shows the words.

const EXAM_DAYS := [10, 20, 30]


## Returns:
##   title: the quest's name
##   goal: the one thing to do next
##   note: a line of small print (opening hours, prices), or ""
##   places: the signs of the doors where it can be done; empty if it isn't done at a door
static func now() -> Dictionary:
	if Game.home == "" and not Game.night_survived:
		return _first_night()
	if not Game.bank_account:
		var shut := "" if Game.bank_is_open() else " It is closed now."
		return _quest("Landing in Milan", "Open an Italian bank account", ["BANCA"],
			"Open %d:00 to %d:00.%s" % [Settings.BANK_OPENS_HOUR, Settings.BANK_CLOSES_HOUR, shut])
	if Game.home == "":
		return _room()
	if Game.tuition_owed > 0:
		return _quest("The school year", "Pay the tuition in the university app", [],
			"%d euro, from your bank account. Tab for the phone." % Game.tuition_owed)
	for exam in EXAM_DAYS:
		if Game.day <= exam:
			return _quest("The school year", "Study for the exam on day %d" % exam, [Game.home, "UNIVERSITÀ"],
				"Hours studied: %.1f. At your desk or at the university." % Game.study_hours)
	return _quest("The school year", "You got through the year", [], "")


static func _first_night() -> Dictionary:
	var title := "Landing in Milan"
	var host := Game.shelter_host
	if host != null:
		return _quest(title, "Sleep on %s's couch" % host.name, [host.home],
			"Before 5:00." if Game.is_night() else "%s is home from %d:00." % [host.name, Settings.PARTY_START_HOUR])
	if not Game.is_night():
		return _quest(title, "Go to the party at Via Roma 12", ["VIA ROMA 12"], "It starts at %d:00." % Settings.PARTY_START_HOUR)
	return _quest(title, "Find someone at the party with a couch", ["VIA ROMA 12"], "Before 5:00, or you sleep on the street.")


static func _room() -> Dictionary:
	var title := "A room of your own"
	var flats: Array = []
	var cheapest := 0
	for flat in Game.FLATS:
		for person in Game.rooms_at(flat):
			if not flats.has(flat):
				flats.append(flat)
			if cheapest == 0 or person.room_rent < cheapest:
				cheapest = person.room_rent
	if flats.is_empty():
		return _quest(title, "Read the notice board at the university", ["UNIVERSITÀ"], "Open 8:00 to 20:00. Or ask someone you met.")
	return _quest(title, "Ring the bell at a flat with a room", flats, "From %d euro a week, first week paid at the door." % cheapest)


static func _quest(title: String, goal: String, places: Array, note: String) -> Dictionary:
	return {"title": title, "goal": goal, "places": places, "note": note}
