class_name Body
## What people look like. A "look" is a Dictionary of colours and proportions
## that Figure turns into a body.

const SKINS := [Color(0.96, 0.82, 0.72), Color(0.9, 0.72, 0.58), Color(0.78, 0.58, 0.44), Color(0.6, 0.42, 0.3), Color(0.42, 0.28, 0.2)]
const HAIRS := [Color(0.1, 0.08, 0.07), Color(0.25, 0.15, 0.08), Color(0.45, 0.28, 0.12), Color(0.8, 0.65, 0.3), Color(0.55, 0.2, 0.12), Color(0.75, 0.75, 0.75), Color(0.3, 0.5, 0.8)]
const SHIRTS := [Color(0.7, 0.2, 0.25), Color(0.2, 0.55, 0.4), Color(0.85, 0.7, 0.2), Color(0.45, 0.25, 0.6), Color(0.15, 0.5, 0.65), Color(0.85, 0.45, 0.15), Color(0.9, 0.9, 0.88), Color(0.12, 0.12, 0.14), Color(0.9, 0.55, 0.65)]
const TROUSERS := [Color(0.15, 0.2, 0.35), Color(0.1, 0.1, 0.12), Color(0.5, 0.45, 0.35), Color(0.3, 0.3, 0.32), Color(0.35, 0.25, 0.18)]
const SHOES := [Color(0.9, 0.9, 0.9), Color(0.1, 0.1, 0.1), Color(0.5, 0.3, 0.15), Color(0.7, 0.15, 0.15)]


static func random_look(rng: RandomNumberGenerator) -> Dictionary:
	return {
		"skin": SKINS[rng.randi() % SKINS.size()],
		"hair": HAIRS[rng.randi() % HAIRS.size()],
		"hair_style": rng.randi() % 5,
		"shirt": SHIRTS[rng.randi() % SHIRTS.size()],
		"trousers": TROUSERS[rng.randi() % TROUSERS.size()],
		"shoes": SHOES[rng.randi() % SHOES.size()],
		"height": rng.randf_range(0.93, 1.08),
		"build": rng.randf_range(0.92, 1.18),
		"brows": rng.randf_range(-0.35, 0.35),  # tilted one way they look angry, the other way worried
		"smile": rng.randf_range(-1.0, 1.0),
		"offset": rng.randf_range(0.0, TAU),
	}


## The wanderer always looks the same.
static func player_look() -> Dictionary:
	return {
		"skin": SKINS[1], "hair": HAIRS[1], "hair_style": 4,
		"shirt": Color(0.25, 0.35, 0.6), "trousers": TROUSERS[0], "shoes": SHOES[0],
		"height": 1.0, "build": 1.0, "brows": -0.2, "smile": -0.5, "offset": 0.0,
	}


static func build(look: Dictionary) -> Figure:
	var figure := Figure.new()
	figure.setup(look)
	return figure


## Looks are saved as plain text, so colours become hex codes and back.
static func look_to_data(look: Dictionary) -> Dictionary:
	var data := {}
	for key in look:
		data[key] = look[key].to_html() if look[key] is Color else look[key]
	return data


static func look_from_data(data: Dictionary) -> Dictionary:
	var look := {}
	for key in data:
		look[key] = Color.html(data[key]) if data[key] is String else data[key]
	if look.has("hair_style"):
		look.hair_style = int(look.hair_style)
	return look
