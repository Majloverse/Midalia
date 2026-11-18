class_name Interiors
## The insides of buildings. Each is its own closed room, built far from the
## streets; doors move the player between the street and the room.
## In every room the way out is in the middle of the +Z wall.

const WOOD := Color(0.45, 0.32, 0.2)
const DARK_WOOD := Color(0.28, 0.2, 0.14)
const METAL := Color(0.55, 0.57, 0.6)
const DOOR := Color(0.25, 0.15, 0.1)


## Floor, ceiling, four walls and the door out. Returns the room node.
static func shell(parent: Node3D, origin: Vector3, width: float, height: float, depth: float, wall: Color, floor: Color, leave_prompt: String) -> Node3D:
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
	Build.trigger(room, Vector3(0, 1.2, depth / 2 - 0.8), Vector3(2.4, 2.4, 1.4), leave_prompt, "leave")
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
	couch.set_meta("lie_at", origin + Vector3(-4.2, 0.7, -0.05))
	couch.set_meta("lie_yaw", 0.0)
	return {"room": room, "entry": origin + Vector3(0, 0.1, 1.4), "host_spot": Vector3(0.8, 0, -0.6)}


## The bank: a real counter behind glass, a queue, and far too much waiting.
static func bank(parent: Node3D, origin: Vector3) -> Dictionary:
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
	var teller := Build.person(room, Vector3(0, 0, -3.1), PI, Color(0.15, 0.2, 0.35), Color(0.9, 0.75, 0.62))
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
	Build.person(room, Vector3(-5.6, 0, 3.4), -PI / 2, Color(0.5, 0.45, 0.4), Color(0.85, 0.7, 0.6))
	Build.person(room, Vector3(5.2, 0, 2.2), PI * 0.8, Color(0.4, 0.2, 0.3), Color(0.6, 0.45, 0.35))
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
