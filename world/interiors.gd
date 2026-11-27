class_name Interiors
## The insides of buildings. Each is its own closed room, built far from the
## streets; doors move the player between the street and the room.
## In every room the way out is in the middle of the +Z wall.

const WOOD := Color(0.45, 0.32, 0.2)
const DARK_WOOD := Color(0.28, 0.2, 0.14)
const METAL := Color(0.55, 0.57, 0.6)
const DOOR := Color(0.25, 0.15, 0.1)


## Floor, ceiling, four walls and the door out. Returns the room node.
static func shell(parent: Node3D, origin: Vector3, width: float, height: float, depth: float, wall: Color, floor: Color, leave_prompt: String, leave_action: String = "leave") -> Node3D:
	var room := Node3D.new()
	room.position = origin
	parent.add_child(room)
	Build.box(room, Vector3(0, -0.25, 0), Vector3(width, 0.5, depth), floor, true)
	Build.box(room, Vector3(0, height + 0.25, 0), Vector3(width, 0.5, depth), Color(0.85, 0.85, 0.82), true)
	Build.box(room, Vector3(0, height / 2, -depth / 2 - 0.25), Vector3(width + 1, height + 0.5, 0.5), wall, true)
	Build.box(room, Vector3(0, height / 2, depth / 2 + 0.25), Vector3(width + 1, height + 0.5, 0.5), wall, true)
	Build.box(room, Vector3(-width / 2 - 0.25, height / 2, 0), Vector3(0.5, height + 0.5, depth), wall, true)
	Build.box(room, Vector3(width / 2 + 0.25, height / 2, 0), Vector3(0.5, height + 0.5, depth), wall, true)
	Build.box(room, Vector3(0, 1.1, depth / 2 - 0.04), Vector3(1.3, 2.2, 0.08), DOOR)
	Build.box(room, Vector3(0.45, 1.05, depth / 2 - 0.1), Vector3(0.08, 0.08, 0.08), Color(0.8, 0.7, 0.3))  # handle
	# A lit green sign over the way out, so it can be found from across the room.
	Build.glow(Build.box(room, Vector3(0, 2.5, depth / 2 - 0.05), Vector3(1.5, 0.4, 0.1), Color(0.05, 0.45, 0.2)), Color(0.2, 1.0, 0.45), 1.5)
	Build.sign(room, Vector3(0, 2.5, depth / 2 - 0.11), "USCITA", 56, PI)
	Build.trigger(room, Vector3(0, 1.2, depth / 2 - 0.8), Vector3(2.4, 2.4, 1.4), leave_prompt, leave_action)
	return room


## A messy student flat: couch and TV, a bed, a kitchen, a table, shelves.
## Returns the room plus the spots the game needs.
static func flat(parent: Node3D, origin: Vector3, wall: Color, accent: Color) -> Dictionary:
	var room := shell(parent, origin, 10, 3.2, 8, wall, Color(0.5, 0.38, 0.26), "Leave the flat")
	Build.light(room, Vector3(0, 2.8, 0), Color(1.0, 0.88, 0.7), 2.2, 10.0)
	Build.glow(Build.box(room, Vector3(0, 3.1, 0), Vector3(0.5, 0.15, 0.5), Color(1, 0.95, 0.8)), Color(1.0, 0.9, 0.7), 2.0)

	# Living corner: couch against the left wall, facing a TV.
	Build.box(room, Vector3(-4.2, 0.225, -1), Vector3(1.0, 0.45, 2.3), accent, true)                  # seat
	Build.box(room, Vector3(-4.78, 0.65, -1), Vector3(0.25, 0.9, 2.3), accent.darkened(0.15))         # back
	Build.box(room, Vector3(-4.2, 0.4, -2.25), Vector3(1.0, 0.7, 0.22), accent.darkened(0.15))        # arm
	Build.box(room, Vector3(-4.2, 0.4, 0.25), Vector3(1.0, 0.7, 0.22), accent.darkened(0.15))         # arm
	Build.box(room, Vector3(-4.35, 0.55, -1.9), Vector3(0.45, 0.14, 0.4), Color(0.9, 0.85, 0.7))      # cushion
	Build.box(room, Vector3(-2.6, 0.01, -1), Vector3(2.4, 0.02, 3.0), accent.lerp(Color.WHITE, 0.5))  # rug
	Build.box(room, Vector3(-2.9, 0.2, -1), Vector3(0.6, 0.4, 1.2), WOOD, true)                       # coffee table
	Build.box(room, Vector3(-2.9, 0.43, -0.7), Vector3(0.4, 0.05, 0.4), Color(0.85, 0.8, 0.7))        # pizza box
	Build.box(room, Vector3(-2.8, 0.52, -1.35), Vector3(0.07, 0.24, 0.07), Color(0.2, 0.5, 0.25))     # bottle
	Build.box(room, Vector3(-3.0, 0.52, -1.2), Vector3(0.07, 0.24, 0.07), Color(0.45, 0.3, 0.1))      # bottle
	Build.box(room, Vector3(-1.2, 0.25, -1), Vector3(0.4, 0.5, 1.5), DARK_WOOD, true)                 # TV stand
	Build.glow(Build.box(room, Vector3(-1.2, 0.95, -1), Vector3(0.06, 0.7, 1.2), Color(0.1, 0.15, 0.3)), Color(0.3, 0.5, 0.9), 0.8)  # TV
	Build.box(room, Vector3(-4.6, 0.75, 1.2), Vector3(0.08, 1.5, 0.08), METAL)                        # floor lamp
	Build.glow(Build.box(room, Vector3(-4.6, 1.6, 1.2), Vector3(0.35, 0.3, 0.35), Color(1, 0.9, 0.7)), Color(1.0, 0.85, 0.6), 1.5)
	Build.light(room, Vector3(-4.3, 1.6, 1.2), Color(1.0, 0.8, 0.55), 1.0, 4.0)

	# Bed in the back right corner.
	Build.box(room, Vector3(3.9, 0.2, -2.9), Vector3(1.6, 0.4, 2.1), DARK_WOOD, true)                 # frame
	Build.box(room, Vector3(3.9, 0.47, -2.9), Vector3(1.5, 0.16, 2.0), Color(0.92, 0.92, 0.88))       # mattress
	Build.box(room, Vector3(3.9, 0.57, -2.5), Vector3(1.52, 0.1, 1.25), accent.lerp(Color(0.2, 0.2, 0.4), 0.5))  # blanket
	Build.box(room, Vector3(3.9, 0.6, -3.65), Vector3(0.9, 0.14, 0.4), Color.WHITE)                   # pillow
	Build.box(room, Vector3(3.9, 0.6, -3.95), Vector3(1.6, 1.2, 0.1), DARK_WOOD)                      # headboard
	Build.box(room, Vector3(2.75, 0.25, -3.6), Vector3(0.45, 0.5, 0.45), WOOD, true)                  # bedside table
	Build.box(room, Vector3(3.2, 0.03, -1.5), Vector3(0.5, 0.06, 0.35), Color(0.3, 0.3, 0.35))        # clothes on the floor
	Build.box(room, Vector3(2.6, 0.03, -2.0), Vector3(0.3, 0.06, 0.4), accent)

	# Kitchen along the back wall.
	Build.box(room, Vector3(-0.6, 0.45, -3.65), Vector3(3.2, 0.9, 0.65), Color(0.9, 0.88, 0.82), true)  # counter
	Build.box(room, Vector3(-0.6, 0.92, -3.65), Vector3(3.25, 0.05, 0.7), Color(0.3, 0.3, 0.32))      # worktop
	Build.box(room, Vector3(-1.4, 0.96, -3.65), Vector3(0.6, 0.03, 0.5), Color(0.08, 0.08, 0.08))     # hob
	Build.box(room, Vector3(0.1, 0.94, -3.65), Vector3(0.6, 0.02, 0.45), METAL)                       # sink
	Build.box(room, Vector3(-0.6, 2.2, -3.8), Vector3(3.2, 0.7, 0.35), Color(0.9, 0.88, 0.82))        # wall cupboards
	Build.box(room, Vector3(1.45, 0.9, -3.6), Vector3(0.7, 1.8, 0.7), Color(0.93, 0.93, 0.95), true)  # fridge
	Build.box(room, Vector3(-0.3, 1.05, -3.5), Vector3(0.22, 0.2, 0.22), Color(0.7, 0.15, 0.15))      # pot
	Build.box(room, Vector3(0.6, 1.0, -3.6), Vector3(0.3, 0.1, 0.25), Color(0.9, 0.9, 0.9))           # dirty dishes

	# Table and chairs.
	Build.box(room, Vector3(2.6, 0.72, 1.6), Vector3(1.3, 0.06, 0.85), WOOD, true)
	for leg in [Vector3(2.05, 0.35, 1.25), Vector3(3.15, 0.35, 1.25), Vector3(2.05, 0.35, 1.95), Vector3(3.15, 0.35, 1.95)]:
		Build.box(room, leg, Vector3(0.07, 0.7, 0.07), DARK_WOOD)
	for chair_z in [0.85, 2.35]:
		Build.box(room, Vector3(2.6, 0.42, chair_z), Vector3(0.45, 0.06, 0.45), WOOD)
		Build.box(room, Vector3(2.6, 0.75, chair_z + (0.2 if chair_z > 1.6 else -0.2)), Vector3(0.45, 0.6, 0.05), WOOD)
		Build.box(room, Vector3(2.6, 0.2, chair_z), Vector3(0.38, 0.4, 0.38), DARK_WOOD)
	Build.box(room, Vector3(2.4, 0.78, 1.6), Vector3(0.34, 0.03, 0.24), Color(0.3, 0.3, 0.32))        # laptop
	Build.glow(Build.box(room, Vector3(2.4, 0.9, 1.45), Vector3(0.34, 0.22, 0.02), Color(0.2, 0.25, 0.4)), Color(0.5, 0.7, 1.0), 0.6)
	Build.box(room, Vector3(2.95, 0.8, 1.8), Vector3(0.2, 0.08, 0.28), Color(0.85, 0.3, 0.3))         # textbook

	# Shelves, a plant, posters.
	Build.box(room, Vector3(4.8, 0.95, 1.6), Vector3(0.35, 1.9, 1.3), DARK_WOOD, true)
	var book_colors := [Color(0.7, 0.2, 0.2), Color(0.2, 0.4, 0.7), Color(0.8, 0.7, 0.2), Color(0.2, 0.6, 0.4), Color(0.6, 0.3, 0.6)]
	for shelf in 3:
		for i in 5:
			Build.box(room, Vector3(4.6, 0.45 + shelf * 0.55, 1.15 + i * 0.22), Vector3(0.2, 0.3, 0.12), book_colors[(i + shelf) % 5])
	Build.box(room, Vector3(-4.4, 0.2, 3.2), Vector3(0.4, 0.4, 0.4), Color(0.6, 0.35, 0.25))          # plant pot
	Build.box(room, Vector3(-4.4, 0.8, 3.2), Vector3(0.6, 0.8, 0.6), Color(0.2, 0.5, 0.25))
	Build.box(room, Vector3(-4.97, 1.8, -1), Vector3(0.03, 0.9, 0.7), accent.lerp(Color.BLACK, 0.3))  # poster over the couch
	Build.box(room, Vector3(2.0, 1.8, -3.97), Vector3(0.6, 0.8, 0.03), Color(0.85, 0.75, 0.3))        # poster
	Build.glow(Build.box(room, Vector3(-2.5, 1.9, 3.96), Vector3(1.4, 1.2, 0.04), Color(0.15, 0.2, 0.4)), Color(0.25, 0.35, 0.7), 0.5)  # window, night outside

	var couch := Build.trigger(room, Vector3(-3.6, 1.0, -1), Vector3(1.6, 2.0, 2.6), "Sleep on the couch", "sleep")
	# Where the sleeper's feet go and which way their head points.
	couch.set_meta("lie_at", origin + Vector3(-4.2, 0.6, -0.1))
	couch.set_meta("lie_yaw", PI)
	Build.trigger(room, Vector3(-0.6, 1.0, -2.8), Vector3(3.2, 2.0, 1.0), "Cook or eat something", "cook")

	# Their food, lying around the way food does in a student flat.
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(accent)
	var theirs: Array = Food.ITEMS.keys()
	for spot in [Vector3(-1.9, 0.945, -3.6), Vector3(-0.85, 0.945, -3.55), Vector3(0.7, 0.945, -3.75), Vector3(1.45, 1.8, -3.6),
			Vector3(1.25, 1.8, -3.5), Vector3(2.9, 0.75, 1.4), Vector3(2.2, 0.75, 1.85), Vector3(-2.9, 0.4, -1.05)]:
		var theirs_item := Food.model(theirs[rng.randi() % theirs.size()])
		theirs_item.position = spot
		theirs_item.rotation.y = rng.randf_range(-0.6, 0.6)
		room.add_child(theirs_item)
	Build.box(room, Vector3(3.0, 0.78, 1.6), Vector3(0.3, 0.06, 0.3), Color(0.85, 0.85, 0.8))         # fruit bowl
	for fruit in [["apple", Vector3(2.95, 0.81, 1.55)], ["orange", Vector3(3.06, 0.81, 1.62)], ["banana", Vector3(3.0, 0.87, 1.6)]]:
		var piece := Food.model(fruit[0])
		piece.position = fruit[1]
		room.add_child(piece)
	# A shelf over the worktop for the lodger's food. The game puts what you own on it.
	Build.box(room, Vector3(-0.6, 1.42, -3.8), Vector3(3.2, 0.04, 0.32), WOOD)
	Build.sign(room, Vector3(-0.6, 1.36, -3.63), "LODGER", 22, 0.0, Color(0.95, 0.9, 0.8))

	# The door to the spare room, in the right-hand wall.
	Build.box(room, Vector3(4.96, 1.1, -0.3), Vector3(0.08, 2.2, 1.0), DOOR)
	Build.box(room, Vector3(4.9, 1.05, 0.05), Vector3(0.08, 0.08, 0.08), Color(0.8, 0.7, 0.3))
	Build.trigger(room, Vector3(4.2, 1.2, -0.3), Vector3(1.4, 2.4, 1.4), "The spare room", "room_door")
	var spare := _spare_room(parent, origin + Vector3(30, 0, 0), wall, accent)
	spare.merge({"room": room, "entry": origin + Vector3(0, 0.1, 1.4), "host_spot": Vector3(0.8, 0, -0.6),
		"food_shelf": Vector3(-2.0, 1.44, -3.8), "room_door": origin + Vector3(3.9, 0.1, -0.3)})
	return spare


## The room you rent: your bed, a desk to study at, a computer. Small, and yours.
## Things bought online appear here; they are built hidden and shown once owned.
static func _spare_room(parent: Node3D, origin: Vector3, wall: Color, accent: Color) -> Dictionary:
	var room := shell(parent, origin, 6, 3.0, 5, wall.lerp(Color.WHITE, 0.3), Color(0.55, 0.45, 0.34), "Back to the flat", "room_exit")
	Build.light(room, Vector3(0, 2.6, 0), Color(1.0, 0.9, 0.75), 2.0, 8.0)
	Build.glow(Build.box(room, Vector3(0, 2.92, 0), Vector3(0.4, 0.12, 0.4), Color(1, 0.95, 0.8)), Color(1.0, 0.9, 0.7), 2.0)

	# Your bed, along the left wall.
	Build.box(room, Vector3(-2.2, 0.2, -1.2), Vector3(1.4, 0.4, 2.1), DARK_WOOD, true)
	Build.box(room, Vector3(-2.2, 0.47, -1.2), Vector3(1.3, 0.16, 2.0), Color(0.92, 0.92, 0.88))
	Build.box(room, Vector3(-2.2, 0.57, -0.8), Vector3(1.32, 0.08, 1.25), Color(0.6, 0.62, 0.66))        # thin grey blanket
	Build.box(room, Vector3(-2.2, 0.6, -1.95), Vector3(0.8, 0.14, 0.4), Color.WHITE)
	Build.box(room, Vector3(-2.2, 0.6, -2.25), Vector3(1.4, 1.2, 0.1), DARK_WOOD)
	var bed := Build.trigger(room, Vector3(-1.8, 1.0, -1.0), Vector3(2.2, 2.0, 2.6), "Go to bed", "bed")
	bed.set_meta("lie_at", origin + Vector3(-2.2, 0.77, -0.3))
	bed.set_meta("lie_yaw", PI)

	# A long desk on the back wall: books on the left, the computer on the right.
	Build.box(room, Vector3(1.3, 0.72, -2.1), Vector3(2.8, 0.06, 0.7), WOOD, true)
	for leg in [Vector3(0.0, 0.35, -2.35), Vector3(2.6, 0.35, -2.35), Vector3(0.0, 0.35, -1.85), Vector3(2.6, 0.35, -1.85)]:
		Build.box(room, leg, Vector3(0.07, 0.7, 0.07), DARK_WOOD)
	Build.box(room, Vector3(0.5, 0.78, -2.1), Vector3(0.4, 0.04, 0.3), Color.WHITE)                         # notes
	Build.box(room, Vector3(0.15, 0.8, -2.25), Vector3(0.22, 0.1, 0.3), Color(0.25, 0.4, 0.65))             # a library book
	Build.box(room, Vector3(2.0, 0.85, -2.35), Vector3(0.08, 0.2, 0.08), Color(0.15, 0.15, 0.17))           # monitor stand
	Build.box(room, Vector3(2.0, 1.15, -2.35), Vector3(0.75, 0.46, 0.05), Color(0.1, 0.1, 0.12))
	Build.glow(Build.box(room, Vector3(2.0, 1.15, -2.32), Vector3(0.69, 0.4, 0.01), Color(0.2, 0.3, 0.5)), Color(0.45, 0.65, 1.0), 0.9)
	Build.box(room, Vector3(2.0, 0.765, -2.0), Vector3(0.5, 0.03, 0.16), Color(0.2, 0.2, 0.22))             # keyboard
	Build.box(room, Vector3(2.4, 0.765, -2.0), Vector3(0.07, 0.03, 0.11), Color(0.2, 0.2, 0.22))            # mouse
	Build.box(room, Vector3(2.55, 0.25, -2.2), Vector3(0.2, 0.5, 0.45), Color(0.12, 0.12, 0.14))            # tower
	for chair_x in [0.5, 2.0]:
		Build.box(room, Vector3(chair_x, 0.42, -1.45), Vector3(0.45, 0.06, 0.45), accent)
		Build.box(room, Vector3(chair_x, 0.75, -1.24), Vector3(0.45, 0.6, 0.05), accent)
		Build.box(room, Vector3(chair_x, 0.2, -1.45), Vector3(0.08, 0.4, 0.08), METAL)
	Build.trigger(room, Vector3(0.5, 1.0, -1.3), Vector3(1.2, 2.0, 1.2), "Sit down and study", "study")
	Build.trigger(room, Vector3(2.0, 1.0, -1.3), Vector3(1.2, 2.0, 1.2), "Use the computer", "computer")

	# Wardrobe, a rug, your suitcase, a window onto a wall.
	Build.box(room, Vector3(2.7, 1.0, 1.3), Vector3(0.5, 2.0, 1.4), WOOD, true)
	Build.box(room, Vector3(-0.3, 0.01, 0.2), Vector3(2.2, 0.02, 1.5), accent.lerp(Color.WHITE, 0.45))
	Build.box(room, Vector3(-2.4, 0.3, 1.6), Vector3(0.75, 0.6, 0.35), Color(0.55, 0.15, 0.15), true)
	Build.glow(Build.box(room, Vector3(-2.97, 1.7, 0.6), Vector3(0.04, 1.0, 1.1), Color(0.15, 0.2, 0.4)), Color(0.25, 0.35, 0.7), 0.5)

	# Things from the online marketplace.
	var goods := {}
	for id in ["lock", "fridge", "duvet", "textbook", "plant", "poster"]:
		var node := Node3D.new()
		node.visible = false
		room.add_child(node)
		goods[id] = node
	Build.box(goods.lock, Vector3(0.5, 1.3, 2.42), Vector3(0.12, 0.16, 0.06), Color(0.8, 0.7, 0.3))
	Build.box(goods.lock, Vector3(0.5, 1.42, 2.42), Vector3(0.08, 0.1, 0.03), METAL)
	Build.box(goods.fridge, Vector3(1.2, 0.35, 2.1), Vector3(0.55, 0.7, 0.55), Color(0.93, 0.93, 0.95))
	Build.box(goods.fridge, Vector3(1.2, 0.4, 1.81), Vector3(0.08, 0.1, 0.04), Color(0.8, 0.7, 0.3))        # padlock
	Build.box(goods.duvet, Vector3(-2.2, 0.62, -0.85), Vector3(1.4, 0.18, 1.4), accent.lerp(Color(0.9, 0.85, 0.7), 0.4))
	Build.box(goods.textbook, Vector3(0.85, 0.81, -2.2), Vector3(0.24, 0.12, 0.32), Color(0.75, 0.2, 0.2))
	Build.box(goods.plant, Vector3(-0.6, 0.2, -2.2), Vector3(0.36, 0.4, 0.36), Color(0.6, 0.35, 0.25))
	Build.box(goods.plant, Vector3(-0.6, 0.8, -2.2), Vector3(0.5, 0.8, 0.5), Color(0.2, 0.5, 0.25))
	Build.box(goods.poster, Vector3(-2.97, 1.7, -1.2), Vector3(0.03, 0.9, 0.65), accent)
	Build.box(goods.poster, Vector3(-2.95, 1.75, -1.2), Vector3(0.03, 0.4, 0.4), Color(0.95, 0.85, 0.3))
	return {"spare": room, "bed": bed, "spare_entry": origin + Vector3(0, 0.1, 1.3), "goods": goods}


## The bank: a real counter behind glass, a queue, and far too much waiting.
static func bank(parent: Node3D, origin: Vector3) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var room := shell(parent, origin, 14, 4, 10, Color(0.86, 0.86, 0.82), Color(0.6, 0.6, 0.62), "Leave the bank")
	Build.light(room, Vector3(-3.5, 3.6, 0.5), Color(0.92, 0.96, 1.0), 2.4, 12.0)
	Build.light(room, Vector3(3.5, 3.6, 0.5), Color(0.92, 0.96, 1.0), 2.4, 12.0)
	Build.light(room, Vector3(0, 3.4, -3.8), Color(0.92, 0.96, 1.0), 1.6, 8.0)
	for x in [-3.5, 3.5]:
		Build.glow(Build.box(room, Vector3(x, 3.95, 0.5), Vector3(2.4, 0.08, 0.5), Color.WHITE), Color.WHITE, 2.0)

	# The counter runs across the room, with glass above it and tellers' desks behind.
	Build.box(room, Vector3(0, 0.55, -2), Vector3(11, 1.1, 0.8), Color(0.2, 0.3, 0.45), true)
	Build.box(room, Vector3(0, 1.12, -2), Vector3(11.1, 0.06, 0.95), Color(0.75, 0.72, 0.66))          # counter top
	Build.box(room, Vector3(0, 1.85, -2), Vector3(11, 1.4, 0.05), Color(0.7, 0.85, 0.95, 0.22))        # glass
	for x in [-5.5, -1.85, 1.85, 5.5]:
		Build.box(room, Vector3(x, 1.85, -2), Vector3(0.1, 1.45, 0.1), METAL)                           # glass posts
	Build.box(room, Vector3(0, 2.6, -2), Vector3(11.1, 0.12, 0.14), METAL)
	Build.box(room, Vector3(-6.25, 2, -2), Vector3(1.5, 4, 0.3), Color(0.86, 0.86, 0.82), true)        # wall beside the counter
	Build.box(room, Vector3(6.25, 2, -2), Vector3(1.5, 4, 0.3), Color(0.86, 0.86, 0.82), true)
	Build.sign(room, Vector3(0, 3.1, -1.9), "SPORTELLO 2", 64)
	Build.sign(room, Vector3(-3.7, 3.1, -1.9), "SPORTELLO 1", 64)
	Build.sign(room, Vector3(3.7, 3.1, -1.9), "SPORTELLO 3", 64)
	Build.box(room, Vector3(-3.7, 1.35, -1.75), Vector3(0.6, 0.3, 0.04), Color(0.7, 0.15, 0.15))       # "closed" plates
	Build.sign(room, Vector3(-3.7, 1.35, -1.72), "CHIUSO", 40)
	Build.box(room, Vector3(3.7, 1.35, -1.75), Vector3(0.6, 0.3, 0.04), Color(0.7, 0.15, 0.15))
	Build.sign(room, Vector3(3.7, 1.35, -1.72), "CHIUSO", 40)
	Build.box(room, Vector3(0.6, 1.22, -2.1), Vector3(0.3, 0.14, 0.3), Color(0.15, 0.15, 0.18))        # card reader
	Build.box(room, Vector3(-0.5, 1.17, -2.1), Vector3(0.35, 0.03, 0.45), Color.WHITE)                 # forms
	Build.box(room, Vector3(-0.9, 1.17, -2.05), Vector3(0.35, 0.03, 0.45), Color(0.95, 0.95, 0.85))

	# Behind the counter: the teller, a monitor, filing cabinets, the vault door.
	var teller := Build.person(room, Vector3(0, 0, -3.1), PI, Body.random_look(rng))
	Build.box(room, Vector3(0.9, 1.4, -2.6), Vector3(0.5, 0.4, 0.05), Color(0.1, 0.1, 0.12))           # monitor
	for x in [-5.6, -4.8, 4.8, 5.6]:
		Build.box(room, Vector3(x, 0.7, -4.6), Vector3(0.7, 1.4, 0.6), METAL, true)                     # filing cabinets
	Build.box(room, Vector3(0, 1.4, -4.9), Vector3(2.2, 2.6, 0.2), Color(0.35, 0.37, 0.4))             # vault door
	Build.box(room, Vector3(0, 1.4, -4.78), Vector3(0.7, 0.7, 0.08), Color(0.7, 0.7, 0.72))            # vault wheel
	Build.sign(room, Vector3(0, 3.4, -4.95), "BANCA", 160, 0.0, Color(0.2, 0.3, 0.5))

	# The queue: rope posts making a lane to the counter.
	for z in [-0.6, 1.0, 2.6]:
		for x in [-1.3, 1.3]:
			Build.box(room, Vector3(x, 0.5, z), Vector3(0.1, 1.0, 0.1), Color(0.75, 0.65, 0.3), true)
			Build.box(room, Vector3(x, 0.03, z), Vector3(0.35, 0.06, 0.35), Color(0.75, 0.65, 0.3))
	for x in [-1.3, 1.3]:
		Build.box(room, Vector3(x, 0.9, 1.0), Vector3(0.05, 0.05, 3.2), Color(0.6, 0.1, 0.15))          # ropes
	Build.box(room, Vector3(0, 0.01, 1.0), Vector3(2.2, 0.02, 4.0), Color(0.55, 0.15, 0.2))            # carpet

	# The number board, the ticket machine, the waiting chairs with people who gave up hope.
	Build.box(room, Vector3(5.0, 2.9, -1.8), Vector3(1.8, 0.8, 0.1), Color(0.05, 0.05, 0.05))
	Build.sign(room, Vector3(5.0, 3.05, -1.74), "SERVIAMO  A 046", 44, 0.0, Color(1.0, 0.3, 0.2))
	Build.sign(room, Vector3(5.0, 2.75, -1.74), "IL TUO NUMERO  A 112", 36, 0.0, Color(1.0, 0.8, 0.2))
	Build.box(room, Vector3(2.4, 0.6, 4.3), Vector3(0.45, 1.2, 0.4), Color(0.2, 0.3, 0.45), true)      # ticket machine
	Build.glow(Build.box(room, Vector3(2.4, 0.95, 4.09), Vector3(0.3, 0.2, 0.02), Color(0.2, 0.6, 0.3)), Color(0.3, 0.9, 0.4), 1.0)
	for z in [-0.5, 0.4, 1.3, 2.2]:
		Build.box(room, Vector3(-6.4, 0.45, z), Vector3(0.6, 0.08, 0.6), Color(0.2, 0.3, 0.45), true)
		Build.box(room, Vector3(-6.75, 0.8, z), Vector3(0.08, 0.7, 0.6), Color(0.2, 0.3, 0.45))
		Build.box(room, Vector3(-6.4, 0.2, z), Vector3(0.08, 0.4, 0.5), METAL)
	Build.person(room, Vector3(-5.6, 0, 3.4), -PI / 2, Body.random_look(rng))
	Build.person(room, Vector3(5.2, 0, 2.2), PI * 0.8, Body.random_look(rng))
	Build.box(room, Vector3(5.6, 0.4, 3.8), Vector3(1.6, 0.8, 0.8), WOOD, true)                        # writing desk
	Build.box(room, Vector3(5.4, 0.83, 3.8), Vector3(0.3, 0.02, 0.4), Color.WHITE)
	Build.box(room, Vector3(5.9, 0.9, 3.75), Vector3(0.05, 0.16, 0.05), Color(0.1, 0.1, 0.4))          # the pen on a chain
	for corner in [Vector3(-6.4, 0, 4.3), Vector3(6.4, 0, -0.9)]:
		Build.box(room, corner + Vector3(0, 0.25, 0), Vector3(0.5, 0.5, 0.5), Color(0.6, 0.35, 0.25))
		Build.box(room, corner + Vector3(0, 1.1, 0), Vector3(0.7, 1.2, 0.7), Color(0.2, 0.5, 0.25))
	Build.box(room, Vector3(-3.5, 2.2, 4.97), Vector3(1.6, 1.0, 0.04), Color(0.2, 0.3, 0.5))           # poster
	Build.sign(room, Vector3(-3.5, 2.2, 4.94), "MUTUI AL 9%", 48, PI)

	Build.trigger(room, Vector3(0, 1.0, -0.9), Vector3(2.4, 2.0, 1.4), "Talk to the teller", "teller")
	return {"room": room, "entry": origin + Vector3(0, 0.1, 2.4), "teller": teller}


## The party flat: a bigger room cleared for dancing, with drinks and coloured lights.
static func party(parent: Node3D, origin: Vector3) -> Dictionary:
	var room := shell(parent, origin, 16, 4, 12, Color(0.3, 0.22, 0.3), Color(0.35, 0.25, 0.18), "Leave the party")
	for lamp in [[Vector3(-5, 3.5, -2), Color(1.0, 0.3, 0.6)], [Vector3(5, 3.5, -2), Color(0.3, 0.6, 1.0)], [Vector3(0, 3.5, 3), Color(1.0, 0.8, 0.4)]]:
		Build.light(room, lamp[0], lamp[1], 3.0, 11.0)
	Build.box(room, Vector3(-6, 0.25, -5.2), Vector3(3, 0.5, 1.1), Color(0.5, 0.2, 0.2), true)         # sofa pushed to the wall
	Build.box(room, Vector3(-6, 0.7, -5.75), Vector3(3, 0.9, 0.25), Color(0.42, 0.16, 0.16))
	Build.box(room, Vector3(5.5, 0.45, -5.2), Vector3(3.5, 0.9, 1), DARK_WOOD, true)                   # drinks table
	var bottle_colors := [Color(0.2, 0.5, 0.25), Color(0.45, 0.3, 0.1), Color(0.8, 0.8, 0.85), Color(0.7, 0.2, 0.2)]
	for i in 9:
		Build.box(room, Vector3(4.1 + i * 0.33, 1.05, -5.2 + (i % 3) * 0.2 - 0.2), Vector3(0.08, 0.28, 0.08), bottle_colors[i % 4])
	Build.box(room, Vector3(6.6, 0.98, -4.95), Vector3(0.5, 0.14, 0.4), Color(0.9, 0.2, 0.2))          # stack of cups
	for x in [-7.4, 7.4]:
		Build.box(room, Vector3(x, 0.7, -5.4), Vector3(0.6, 1.4, 0.6), Color(0.08, 0.08, 0.08), true)  # speakers
		Build.box(room, Vector3(x, 0.9, -5.08), Vector3(0.4, 0.4, 0.04), Color(0.2, 0.2, 0.22))
	Build.box(room, Vector3(0, 0.45, -5.3), Vector3(2.0, 0.9, 0.8), Color(0.12, 0.12, 0.14), true)     # DJ desk
	Build.glow(Build.box(room, Vector3(0, 0.95, -5.3), Vector3(0.9, 0.05, 0.5), Color(0.2, 0.2, 0.3)), Color(0.6, 0.3, 1.0), 1.2)
	Build.box(room, Vector3(0, 0.01, -1), Vector3(7, 0.02, 6), Color(0.2, 0.15, 0.25))                 # dance floor
	for i in 6:
		Build.glow(Build.box(room, Vector3(-6.5 + i * 2.6, 3.4, -5.95), Vector3(0.18, 0.18, 0.05), Color.WHITE),
			[Color(1, 0.3, 0.3), Color(0.3, 1, 0.4), Color(0.3, 0.5, 1), Color(1, 0.9, 0.3)][i % 4], 2.5)  # fairy lights
	Build.box(room, Vector3(7.2, 0.03, 3.5), Vector3(0.5, 0.06, 0.4), Color(0.85, 0.8, 0.7))           # pizza boxes
	Build.box(room, Vector3(7.3, 0.09, 3.55), Vector3(0.5, 0.06, 0.4), Color(0.85, 0.8, 0.7))
	Build.box(room, Vector3(-7.4, 0.5, 4), Vector3(0.9, 1.0, 2.2), Color(0.25, 0.25, 0.3), true)       # coats piled on a chest
	Build.box(room, Vector3(-7.4, 1.1, 4), Vector3(0.8, 0.25, 1.8), Color(0.4, 0.3, 0.2))
	return {"room": room, "entry": origin + Vector3(0, 0.1, 2.6)}


## The station concourse: where you arrive. Departure board, shut ticket office, a bar.
static func station(parent: Node3D, origin: Vector3) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var room := shell(parent, origin, 22, 6.5, 14, Color(0.82, 0.78, 0.7), Color(0.72, 0.7, 0.66), "Leave the station")
	for x in [-6.0, 0.0, 6.0]:
		Build.light(room, Vector3(x, 5.6, 0), Color(1.0, 0.95, 0.85), 2.6, 14.0)
		Build.glow(Build.box(room, Vector3(x, 6.4, 0), Vector3(1.2, 0.1, 1.2), Color.WHITE), Color(1.0, 0.95, 0.85), 2.0)
	for x in [-7.0, 7.0]:
		for z in [-3.0, 3.0]:
			Build.box(room, Vector3(x, 3.25, z), Vector3(0.7, 6.5, 0.7), Color(0.75, 0.7, 0.62), true)   # pillars
			Build.box(room, Vector3(x, 0.3, z), Vector3(0.95, 0.6, 0.95), Color(0.55, 0.5, 0.45))

	# The departure board on the back wall. Nothing leaves on time.
	Build.box(room, Vector3(0, 4.3, -6.85), Vector3(9, 2.6, 0.2), Color(0.04, 0.04, 0.05))
	Build.sign(room, Vector3(0, 5.3, -6.72), "PARTENZE  /  DEPARTURES", 56, 0.0, Color(1.0, 0.8, 0.2))
	var trains := ["18:15   ROMA TERMINI          RITARDO 95'", "18:40   VENEZIA S. LUCIA      CANCELLATO",
		"19:05   TORINO PORTA NUOVA    RITARDO 40'", "19:30   NAPOLI CENTRALE       RITARDO 120'", "20:00   CASA TUA              NON DISPONIBILE"]
	for i in trains.size():
		Build.sign(room, Vector3(0, 4.85 - i * 0.38, -6.72), trains[i], 40, 0.0, Color(1.0, 0.6, 0.15) if i < 4 else Color(1.0, 0.25, 0.2))
	Build.trigger(room, Vector3(0, 1.2, -5.4), Vector3(8, 2.4, 2.0), "Read the departure board", "message").set_meta("message",
		"Every train is late or cancelled. The one going home says \"not available\".")
	# Platform gates either side of the board.
	for x in [-8.3, 8.3]:
		Build.box(room, Vector3(x, 1.6, -6.9), Vector3(3.2, 3.2, 0.15), Color(0.1, 0.11, 0.14))
		Build.sign(room, Vector3(x, 3.5, -6.8), "BINARI 1-6" if x < 0 else "BINARI 7-12", 52)
		Build.box(room, Vector3(x, 0.55, -6.3), Vector3(3.0, 1.1, 0.12), METAL, true)             # barrier

	# Ticket office (shut) on the left, ticket machines on the right.
	Build.box(room, Vector3(-10.4, 0.55, 2.5), Vector3(0.9, 1.1, 5), Color(0.5, 0.2, 0.18), true)
	Build.box(room, Vector3(-10.4, 1.9, 2.5), Vector3(0.06, 1.6, 5), Color(0.7, 0.85, 0.95, 0.25))
	Build.box(room, Vector3(-9.93, 2.0, 2.5), Vector3(0.04, 0.5, 2.2), Color(0.7, 0.15, 0.15))
	Build.sign(room, Vector3(-9.9, 2.0, 2.5), "BIGLIETTERIA CHIUSA", 44, PI / 2)
	for z in [0.0, 1.2, 2.4]:
		Build.box(room, Vector3(10.5, 0.9, z), Vector3(0.6, 1.8, 0.8), Color(0.75, 0.15, 0.15), true)
		Build.glow(Build.box(room, Vector3(10.18, 1.25, z), Vector3(0.03, 0.4, 0.5), Color(0.2, 0.3, 0.5)), Color(0.4, 0.7, 1.0), 1.0)
	Build.sign(room, Vector3(10.15, 2.1, 1.2), "FUORI SERVIZIO", 36, -PI / 2, Color(1.0, 0.8, 0.2))

	# The bar: counter, coffee machine, stools, pastries under glass.
	Build.box(room, Vector3(7.5, 0.55, 5.4), Vector3(4.5, 1.1, 0.8), DARK_WOOD, true)
	Build.box(room, Vector3(7.5, 1.12, 5.4), Vector3(4.6, 0.05, 0.9), Color(0.85, 0.82, 0.76))
	Build.box(room, Vector3(8.9, 1.4, 5.5), Vector3(0.7, 0.5, 0.5), METAL)                       # coffee machine
	Build.box(room, Vector3(6.6, 1.3, 5.4), Vector3(1.2, 0.3, 0.5), Color(0.8, 0.9, 0.95, 0.3))          # pastry case
	for i in 4:
		Build.box(room, Vector3(6.25 + i * 0.24, 1.2, 5.4), Vector3(0.16, 0.08, 0.2), Color(0.8, 0.6, 0.3))
	Build.box(room, Vector3(7.5, 2.6, 6.85), Vector3(4.5, 1.6, 0.2), DARK_WOOD)                          # shelves of bottles
	for i in 12:
		Build.box(room, Vector3(5.6 + i * 0.34, 2.5 + (i % 2) * 0.5, 6.7), Vector3(0.09, 0.3, 0.09), [Color(0.2, 0.5, 0.25), Color(0.5, 0.3, 0.1), Color(0.7, 0.15, 0.15)][i % 3])
	Build.sign(room, Vector3(7.5, 3.8, 6.7), "BAR", 120, PI, Color(1.0, 0.85, 0.5))
	for x in [6.2, 7.5, 8.8]:
		Build.box(room, Vector3(x, 0.38, 4.5), Vector3(0.35, 0.06, 0.35), Color(0.6, 0.1, 0.12))
		Build.box(room, Vector3(x, 0.18, 4.5), Vector3(0.07, 0.36, 0.07), METAL)
	Build.person(room, Vector3(7.5, 0, 6.2), 0.0, Body.random_look(rng))                                 # barista
	Build.trigger(room, Vector3(7.5, 1.0, 4.3), Vector3(4, 2, 1.4), "Eat at the bar (%d euro)" % Settings.MEAL_PRICE, "eat")

	# Benches, luggage, a newsstand, a clock, people waiting.
	for z in [-1.5, 1.0]:
		for x in [-3.2, 3.2]:
			Build.box(room, Vector3(x, 0.42, z), Vector3(3.6, 0.08, 0.5), WOOD, true)
			Build.box(room, Vector3(x, 0.75, z + 0.24), Vector3(3.6, 0.5, 0.06), WOOD)
			for leg in [-1.6, 1.6]:
				Build.box(room, Vector3(x + leg, 0.2, z), Vector3(0.08, 0.4, 0.45), METAL)
	for bag in [[Vector3(-4.5, 0.35, 0.3), Color(0.2, 0.3, 0.6)], [Vector3(-1.9, 0.3, -2.2), Color(0.6, 0.2, 0.2)], [Vector3(2.4, 0.35, 0.3), Color(0.15, 0.15, 0.15)], [Vector3(4.6, 0.25, -2.2), Color(0.3, 0.5, 0.3)]]:
		Build.box(room, bag[0], Vector3(0.45, bag[0].y * 2, 0.28), bag[1], true)
		Build.box(room, bag[0] + Vector3(0, bag[0].y + 0.15, 0), Vector3(0.25, 0.3, 0.03), METAL)
	Build.box(room, Vector3(-7.5, 1.1, 5.9), Vector3(3.2, 2.2, 1.4), Color(0.2, 0.4, 0.3), true)         # newsstand
	for i in 8:
		Build.box(room, Vector3(-8.8 + i * 0.38, 1.0 + (i % 2) * 0.5, 5.15), Vector3(0.28, 0.38, 0.04), [Color.WHITE, Color(0.9, 0.3, 0.3), Color(0.3, 0.5, 0.9), Color(0.95, 0.85, 0.3)][i % 4])
	Build.sign(room, Vector3(-7.5, 2.45, 5.18), "EDICOLA", 56, PI)
	Build.box(room, Vector3(0, 5.6, 6.9), Vector3(1.3, 1.3, 0.12), Color.WHITE)                          # clock over the exit
	Build.box(room, Vector3(0, 5.75, 6.82), Vector3(0.05, 0.5, 0.03), Color.BLACK)
	Build.box(room, Vector3(0.18, 5.6, 6.82), Vector3(0.36, 0.05, 0.03), Color.BLACK)
	Build.sign(room, Vector3(0, 3.2, 6.7), "USCITA  /  EXIT", 72, PI, Color(0.3, 0.9, 0.4))
	Build.person(room, Vector3(-3.6, 0, -0.9), PI, Body.random_look(rng))
	Build.person(room, Vector3(2.9, 0, 1.6), PI * 0.9, Body.random_look(rng))
	Build.person(room, Vector3(-9.0, 0, -2.5), -PI / 2, Body.random_look(rng))
	Build.person(room, Vector3(5.0, 0, -4.5), 0.2, Body.random_look(rng))
	return {"room": room, "entry": origin + Vector3(0, 0.1, 4.0), "arrival": origin + Vector3(-8.3, 0.1, -5.2)}


## The university hall: the secretary's desk, the notice board, a lecture corner, study tables.
static func university(parent: Node3D, origin: Vector3) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 23
	var room := shell(parent, origin, 24, 5, 14, Color(0.88, 0.84, 0.76), Color(0.5, 0.36, 0.26), "Leave the university")
	for x in [-7.0, 0.0, 7.0]:
		Build.light(room, Vector3(x, 4.4, 0.5), Color(1.0, 0.96, 0.88), 2.4, 13.0)
		Build.glow(Build.box(room, Vector3(x, 4.95, 0.5), Vector3(2.0, 0.08, 0.5), Color.WHITE), Color.WHITE, 2.0)
	Build.sign(room, Vector3(0, 4.2, 6.7), "UNIVERSITÀ", 110, PI, Color(0.5, 0.15, 0.15))

	# Segreteria: the office that is never open.
	Build.box(room, Vector3(-8.5, 0.55, 3.5), Vector3(5, 1.1, 0.8), DARK_WOOD, true)
	Build.box(room, Vector3(-8.5, 1.12, 3.5), Vector3(5.1, 0.05, 0.9), Color(0.8, 0.76, 0.7))
	Build.box(room, Vector3(-9.3, 1.4, 3.7), Vector3(0.5, 0.4, 0.05), Color(0.1, 0.1, 0.12))            # monitor
	Build.box(room, Vector3(-7.4, 1.2, 3.5), Vector3(0.35, 0.12, 0.45), Color.WHITE)                    # a tower of forms
	Build.box(room, Vector3(-7.4, 1.3, 3.5), Vector3(0.33, 0.1, 0.43), Color(0.95, 0.95, 0.85))
	Build.sign(room, Vector3(-8.5, 3.0, 6.7), "SEGRETERIA STUDENTI", 60, PI)
	Build.sign(room, Vector3(-8.5, 2.5, 6.7), "martedì 10:00 - 10:15", 36, PI, Color(0.8, 0.8, 0.8))
	for x in [-10.6, -9.6, -6.4]:
		Build.box(room, Vector3(x, 0.8, 6.3), Vector3(0.8, 1.6, 0.6), METAL, true)               # filing cabinets
	Build.person(room, Vector3(-8.5, 0, 4.6), PI, Body.random_look(rng))
	Build.trigger(room, Vector3(-8.5, 1.0, 2.5), Vector3(4, 2, 1.4), "Talk to the secretary", "message").set_meta("message",
		"\"The office is open Tuesdays, 10:00 to 10:15. Use the app.\" She goes back to her crossword.")

	# The notice board.
	Build.box(room, Vector3(11.85, 1.9, 2.5), Vector3(0.1, 1.8, 3.4), Color(0.55, 0.4, 0.25))
	for i in 9:
		Build.box(room, Vector3(11.78, 1.4 + (i % 3) * 0.5, 1.3 + (i / 3) * 1.1 + (i % 2) * 0.15), Vector3(0.02, 0.38, 0.3),
			[Color.WHITE, Color(1.0, 0.95, 0.6), Color(0.8, 0.9, 1.0), Color(1.0, 0.8, 0.8)][i % 4])
	Build.sign(room, Vector3(11.75, 3.05, 2.5), "AVVISI", 60, -PI / 2)
	Build.trigger(room, Vector3(10.6, 1.0, 2.5), Vector3(2.0, 2, 3.4), "Read the notice board", "notices")

	# Lecture corner at the back: blackboard, lectern, rows of desks.
	Build.box(room, Vector3(3.5, 2.4, -6.9), Vector3(7, 2.2, 0.1), Color(0.12, 0.25, 0.18))
	Build.box(room, Vector3(3.5, 1.25, -6.85), Vector3(7.1, 0.08, 0.16), WOOD)                           # chalk tray
	Build.sign(room, Vector3(2.2, 2.9, -6.82), "MICROECONOMIA I", 52, 0.0, Color(0.95, 0.95, 0.9))
	Build.sign(room, Vector3(4.6, 2.2, -6.82), "domanda = offerta ?", 40, 0.0, Color(0.95, 0.95, 0.9))
	Build.sign(room, Vector3(2.0, 1.75, -6.82), "esame: giorno 10", 36, 0.0, Color(1.0, 0.9, 0.5))
	Build.box(room, Vector3(0.2, 0.6, -5.4), Vector3(0.7, 1.2, 0.5), DARK_WOOD, true)                    # lectern
	for row in 3:
		var z := -3.4 + row * 1.5
		Build.box(room, Vector3(3.8, 0.72, z), Vector3(6.4, 0.06, 0.5), WOOD, true)                      # long desk
		Build.box(room, Vector3(3.8, 0.36, z - 0.22), Vector3(6.4, 0.72, 0.05), DARK_WOOD)
		Build.box(room, Vector3(3.8, 0.42, z + 0.6), Vector3(6.4, 0.06, 0.4), WOOD)                      # bench
		for leg in [-3.0, 0.0, 3.0]:
			Build.box(room, Vector3(3.8 + leg, 0.2, z + 0.6), Vector3(0.08, 0.4, 0.35), METAL)
		for seat in 3:
			Build.box(room, Vector3(1.6 + seat * 2.1 + row * 0.3, 0.77, z), Vector3(0.3, 0.03, 0.22), [Color.WHITE, Color(0.2, 0.2, 0.25), Color(0.9, 0.85, 0.5)][(seat + row) % 3])

	# Study tables on the left, with someone who has been there since September.
	for z in [-4.5, -1.5]:
		Build.box(room, Vector3(-7.5, 0.72, z), Vector3(3.0, 0.06, 1.2), WOOD, true)
		for leg in [Vector3(-8.85, 0.35, z - 0.5), Vector3(-6.15, 0.35, z - 0.5), Vector3(-8.85, 0.35, z + 0.5), Vector3(-6.15, 0.35, z + 0.5)]:
			Build.box(room, leg, Vector3(0.07, 0.7, 0.07), DARK_WOOD)
		for x in [-8.3, -6.7]:
			Build.box(room, Vector3(x, 0.42, z + 0.95), Vector3(0.45, 0.06, 0.45), Color(0.2, 0.3, 0.45))
			Build.box(room, Vector3(x, 0.75, z + 1.16), Vector3(0.45, 0.6, 0.05), Color(0.2, 0.3, 0.45))
			Build.box(room, Vector3(x, 0.2, z + 0.95), Vector3(0.38, 0.4, 0.38), METAL)
		Build.box(room, Vector3(-8.0, 0.78, z), Vector3(0.34, 0.03, 0.24), Color(0.3, 0.3, 0.32))        # laptop
		Build.glow(Build.box(room, Vector3(-8.0, 0.9, z - 0.13), Vector3(0.34, 0.22, 0.02), Color(0.2, 0.25, 0.4)), Color(0.5, 0.7, 1.0), 0.6)
		Build.box(room, Vector3(-6.9, 0.82, z + 0.1), Vector3(0.22, 0.14, 0.3), Color(0.7, 0.2, 0.2))    # stacked textbooks
	Build.person(room, Vector3(-6.7, 0, -3.3), 0.0, Body.random_look(rng))
	Build.trigger(room, Vector3(-7.5, 1.0, -0.3), Vector3(3.4, 2, 1.2), "Sit down and study", "study")

	# Bookshelves, lockers, a vending machine, a trophy case, plants.
	for x in [-11.0, -9.6, -8.2]:
		Build.box(room, Vector3(x, 1.1, -6.7), Vector3(1.3, 2.2, 0.4), DARK_WOOD, true)
		for shelf in 4:
			for i in 5:
				Build.box(room, Vector3(x - 0.48 + i * 0.24, 0.35 + shelf * 0.5, -6.52), Vector3(0.14, 0.34, 0.1),
					[Color(0.7, 0.2, 0.2), Color(0.2, 0.4, 0.7), Color(0.8, 0.7, 0.2), Color(0.2, 0.6, 0.4), Color(0.6, 0.3, 0.6)][(i + shelf) % 5])
	for i in 6:
		Build.box(room, Vector3(11.7, 1.0, -5.6 + i * 0.62), Vector3(0.5, 2.0, 0.58), [Color(0.2, 0.35, 0.55), Color(0.25, 0.4, 0.6)][i % 2], true)  # lockers
	Build.box(room, Vector3(11.55, 1.0, -1.2), Vector3(0.8, 2.0, 1.0), Color(0.75, 0.15, 0.15), true)    # vending machine
	Build.glow(Build.box(room, Vector3(11.13, 1.3, -1.2), Vector3(0.03, 1.0, 0.7), Color(0.9, 0.9, 0.8)), Color(1.0, 1.0, 0.9), 0.8)
	Build.box(room, Vector3(6.5, 1.0, 6.6), Vector3(3.0, 2.0, 0.5), DARK_WOOD, true)                     # trophy case
	Build.box(room, Vector3(6.5, 1.2, 6.33), Vector3(2.7, 1.4, 0.04), Color(0.8, 0.9, 0.95, 0.25))
	for i in 4:
		Build.box(room, Vector3(5.5 + i * 0.66, 1.1, 6.5), Vector3(0.16, 0.34, 0.16), Color(0.85, 0.7, 0.25))
	for corner in [Vector3(-11.3, 0, 0.8), Vector3(2.6, 0, 6.3), Vector3(-3.0, 0, -6.3)]:
		Build.box(room, corner + Vector3(0, 0.25, 0), Vector3(0.5, 0.5, 0.5), Color(0.6, 0.35, 0.25))
		Build.box(room, corner + Vector3(0, 1.1, 0), Vector3(0.7, 1.2, 0.7), Color(0.2, 0.5, 0.25))
	Build.person(room, Vector3(8.5, 0, 0.5), -PI * 0.6, Body.random_look(rng))
	Build.person(room, Vector3(9.3, 0, 1.3), PI * 0.4, Body.random_look(rng))
	Build.person(room, Vector3(1.0, 0, 3.0), PI, Body.random_look(rng))
	return {"room": room, "entry": origin + Vector3(0, 0.1, 4.2)}

