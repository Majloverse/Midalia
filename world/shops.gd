class_name Shops
## Shops you can walk around. Food sits on shelves as real objects: look at
## something and click to put it in your basket. Fridges have glass doors you
## open first. You pay at the till.
##
## Every piece of shop furniture is built on its own node with its front facing
## that node's +Z, then turned to face the aisle.

const WHITE := Color(0.92, 0.92, 0.9)
const STEEL := Color(0.6, 0.62, 0.65)
const GLASS := Color(0.7, 0.85, 0.95, 0.22)


## The petrol station kiosk: snacks, cold drinks, sandwiches, open all night, and expensive.
static func gas(parent: Node3D, origin: Vector3) -> Dictionary:
	var markup: float = Settings.SHOP_PRICES.gas
	var room := Interiors.shell(parent, origin, 9, 3.2, 7, Color(0.9, 0.88, 0.8), Color(0.55, 0.55, 0.58), "Leave the shop")
	_lights(room, [Vector3(-2, 2.9, 0), Vector3(2, 2.9, 0)], 9.0)
	rack(room, Vector3(0.8, 0, -3.25), 0.0, 5.0, ["crisps", "chocolate", "biscuits", "noodles"], markup)
	fridge(room, Vector3(-4.18, 0, -1.7), PI / 2, ["cola", "energy", "water", "beer"], markup)
	fridge(room, Vector3(-4.18, 0, -0.45), PI / 2, ["panino", "tramezzino", "juice", "water"], markup)
	Build.sign(room, Vector3(-4.2, 2.5, -1.1), "FRESCO", 48, PI / 2, Color(0.4, 0.75, 1.0))
	till(room, Vector3(3.3, 0, 1.3), -PI / 2, 31)
	# Things for cars, which you don't have.
	Build.box(room, Vector3(4.3, 0.95, -1.6), Vector3(0.35, 1.9, 2.4), STEEL, true)
	for i in 12:
		Build.box(room, Vector3(4.05, 0.45 + (i / 4) * 0.55, -2.5 + (i % 4) * 0.6), Vector3(0.16, 0.3, 0.2),
			[Color(0.1, 0.1, 0.12), Color(0.85, 0.7, 0.1), Color(0.15, 0.35, 0.7)][i % 3])
	Build.sign(room, Vector3(4.1, 2.5, -1.6), "OLIO MOTORE", 40, -PI / 2, Color(1.0, 0.8, 0.2))
	Build.box(room, Vector3(-3.6, 0.5, 2.9), Vector3(1.2, 1.0, 0.6), Color(0.2, 0.2, 0.22), true)             # coffee machine
	Build.glow(Build.box(room, Vector3(-3.6, 1.25, 2.9), Vector3(0.9, 0.5, 0.5), Color(0.5, 0.1, 0.1)), Color(1.0, 0.3, 0.2), 0.5)
	Build.sign(room, Vector3(0, 2.75, -3.45), "SNACK  ·  24 ORE", 60, 0.0, Color(1.0, 0.8, 0.2))
	return {"room": room, "entry": origin + Vector3(0, 0.1, 2.0)}


## A corner shop: a bit of everything, squeezed into one room.
static func corner(parent: Node3D, origin: Vector3, wall: Color, name: String, look_seed: int) -> Dictionary:
	var markup: float = Settings.SHOP_PRICES.corner
	var room := Interiors.shell(parent, origin, 10, 3.2, 8, wall, Color(0.6, 0.52, 0.42), "Leave the shop")
	_lights(room, [Vector3(-2.5, 2.9, -1), Vector3(2.5, 2.9, -1), Vector3(0, 2.9, 2.2)], 9.0)
	rack(room, Vector3(0.5, 0, -3.75), 0.0, 8.0, _turned(["pasta", "rice", "soup", "beans", "noodles", "crisps", "chocolate", "biscuits"], look_seed), markup)
	fridge(room, Vector3(-4.68, 0, -2.2), PI / 2, ["milk", "eggs", "yogurt", "cheese"], markup)
	fridge(room, Vector3(-4.68, 0, -0.95), PI / 2, ["panino", "tramezzino", "salad", "juice"], markup)
	fridge(room, Vector3(-4.68, 0, 0.3), PI / 2, ["cola", "beer", "water", "energy"], markup, true)
	# One island of shelves in the middle: bread on the door side, drinks behind.
	rack(room, Vector3(0.6, 0, -0.42), 0.0, 3.4, ["bread", "focaccia", "cornetto", "biscuits"], markup)
	rack(room, Vector3(0.6, 0, -0.88), PI, 3.4, _turned(["water", "cola", "juice", "beer"], look_seed), markup)
	crate(room, Vector3(4.5, 0, -2.0), -PI / 2, "banana", markup)
	crate(room, Vector3(4.5, 0, -0.9), -PI / 2, "apple" if look_seed % 2 == 0 else "orange", markup)
	till(room, Vector3(3.7, 0, 2.0), -PI / 2, look_seed)
	Build.sign(room, Vector3(0.5, 2.7, -3.95), name, 64, 0.0, Color(0.9, 0.3, 0.2))
	# Clutter: crates of water by the door, a mop nobody uses.
	for i in 3:
		Build.box(room, Vector3(-3.6, 0.15 + i * 0.3, 3.3), Vector3(0.6, 0.28, 0.4), Color(0.55, 0.75, 0.9), i == 0)
	Build.box(room, Vector3(-4.6, 0.8, 2.4), Vector3(0.05, 1.6, 0.05), Color(0.6, 0.45, 0.25))
	return {"room": room, "entry": origin + Vector3(0, 0.1, 2.6)}


## The supermarket: aisles of shelves, a wall of fridges and freezers, fruit, bread, three tills.
static func supermarket(parent: Node3D, origin: Vector3) -> Dictionary:
	var markup: float = Settings.SHOP_PRICES.supermarket
	var room := Interiors.shell(parent, origin, 26, 4.5, 18, Color(0.93, 0.93, 0.9), Color(0.8, 0.8, 0.78), "Leave the supermarket")
	var lamps: Array = []
	for x in [-8.0, 0.0, 8.0]:
		for z in [-4.5, 4.0]:
			lamps.append(Vector3(x, 4.2, z))
	_lights(room, lamps, 13.0)
	Build.box(room, Vector3(0, 3.6, -8.9), Vector3(26, 0.9, 0.1), Color(0.8, 0.12, 0.12))                     # red band round the back wall
	Build.sign(room, Vector3(0, 3.6, 8.7), "SUPERMERCATO", 110, PI, Color(0.8, 0.12, 0.12))

	# The cold wall: eight fridges, then four freezers.
	var chilled := Food.in_section("fridge")
	var frozen := Food.in_section("freezer")
	for i in 12:
		var x := -11.2 + i * 1.24
		if i < 8:
			fridge(room, Vector3(x, 0, -8.68), 0.0, _turned(chilled, i * 2).slice(0, 4), markup)
		else:
			fridge(room, Vector3(x, 0, -8.68), 0.0, _turned(frozen, i).slice(0, 4) + [frozen[i % frozen.size()]], markup, true)
	Build.sign(room, Vector3(-6.8, 2.5, -8.8), "LATTICINI  ·  FRESCHI", 56, 0.0, Color(0.5, 0.8, 1.0))
	Build.sign(room, Vector3(0.6, 2.5, -8.8), "SURGELATI", 56, 0.0, Color(0.7, 0.9, 1.0))

	# Three aisles of shelves running from the fridges towards the tills.
	var aisles := [
		[-6.5, "PASTA  ·  RISO", Food.in_section("dry"), Food.in_section("dry")],
		[-1.5, "SNACK", Food.in_section("snacks"), Food.in_section("snacks") + ["noodles"]],
		[3.5, "BIBITE", Food.in_section("drinks"), _turned(Food.in_section("drinks"), 2)],
	]
	for aisle in aisles:
		var x: float = aisle[0]
		Build.box(room, Vector3(x, 0.95, -2.0), Vector3(0.1, 1.9, 6.4), WHITE)                               # the spine both sides hang off
		rack(room, Vector3(x + 0.25, 0, -2.0), PI / 2, 6.4, aisle[2], markup)
		rack(room, Vector3(x - 0.25, 0, -2.0), -PI / 2, 6.4, _turned(aisle[3], 1), markup)
		Build.box(room, Vector3(x, 3.4, 1.6), Vector3(1.8, 0.5, 0.06), Color(0.8, 0.12, 0.12))              # hanging sign
		Build.sign(room, Vector3(x, 3.4, 1.64), aisle[1], 44)
		Build.box(room, Vector3(x, 4.1, 1.6), Vector3(0.03, 0.9, 0.03), STEEL)

	# Fruit along the left wall, bread along the right.
	var fruit := Food.in_section("produce")
	for i in 6:
		crate(room, Vector3(-12.5, 0, -5.0 + i * 1.15), PI / 2, fruit[i % fruit.size()], markup)
	Build.sign(room, Vector3(-12.9, 2.6, -2.1), "FRUTTA", 64, PI / 2, Color(0.4, 0.75, 0.3))
	rack(room, Vector3(12.75, 0, -4.0), -PI / 2, 5.0, Food.in_section("bakery"), markup)
	Build.sign(room, Vector3(12.9, 2.6, -4.0), "PANE", 64, -PI / 2, Color(0.85, 0.6, 0.3))

	# Tills by the way out, and a row of trolleys.
	for i in 3:
		till(room, Vector3(5.0 + i * 3.0, 0, 5.6), PI, 40 + i)
		Build.glow(Build.box(room, Vector3(5.0 + i * 3.0, 2.6, 5.6), Vector3(0.5, 0.35, 0.06), Color(0.1, 0.5, 0.2)), Color(0.3, 1.0, 0.4), 0.8)
		Build.sign(room, Vector3(5.0 + i * 3.0, 2.6, 5.56), str(i + 1), 40, PI)
	for i in 5:
		var z := 7.8 - i * 0.45
		Build.box(room, Vector3(-10.5, 0.6, z), Vector3(0.6, 0.5, 0.4), Color(0.7, 0.72, 0.75, 0.5), i == 0)
		Build.box(room, Vector3(-10.5, 0.98, z + 0.2), Vector3(0.6, 0.04, 0.04), Color(0.8, 0.12, 0.12))
		Build.box(room, Vector3(-10.5, 0.2, z), Vector3(0.5, 0.3, 0.3), STEEL)
	# Special offers stacked on a pallet near the door.
	Build.box(room, Vector3(-4.5, 0.08, 5.5), Vector3(1.4, 0.16, 1.2), Color(0.6, 0.45, 0.28), true)
	for i in 9:
		Food.unit(room, "water" if i % 2 == 0 else "pasta", Vector3(-5.0 + (i % 3) * 0.5, 0.16, 5.1 + (i / 3) * 0.4), Food.price("water" if i % 2 == 0 else "pasta", markup))
	Build.sign(room, Vector3(-4.5, 1.5, 5.5), "OFFERTA!", 72, 0.0, Color(1.0, 0.85, 0.1))
	return {"room": room, "entry": origin + Vector3(0, 0.1, 7.2)}


## A one-sided rack of shelves, `length` wide. Each stretch of shelf shows one product.
static func rack(room: Node3D, at: Vector3, yaw: float, length: float, items: Array, markup: float) -> void:
	var f := _fixture(room, at, yaw)
	Build.box(f, Vector3(0, 0.95, -0.2), Vector3(length, 1.9, 0.05), WHITE)
	Build.blocker(f, Vector3(0, 0.95, 0), Vector3(length, 1.9, 0.44))
	var slots := int(length / 0.29)
	var stretches := ceili(slots / 4.0)
	for row in 4:
		var y := 0.18 + row * 0.44
		Build.box(f, Vector3(0, y - 0.015, 0), Vector3(length, 0.03, 0.42), WHITE)
		Build.box(f, Vector3(0, y - 0.03, 0.215), Vector3(length, 0.05, 0.01), Color(0.95, 0.85, 0.2))   # price strip
		for slot in slots:
			var id: String = items[(row * stretches + slot / 4) % items.size()]
			var x := (slot - (slots - 1) / 2.0) * 0.29
			Food.unit(f, id, Vector3(x, y, 0.04), Food.price(id, markup), Vector2(0.28, 0.4))


## A fridge with a glass door. The door has to be opened before anything inside can be taken.
## One product per shelf. A freezer is the same thing, colder and bluer.
static func fridge(room: Node3D, at: Vector3, yaw: float, items: Array, markup: float, freezer: bool = false) -> void:
	var f := _fixture(room, at, yaw)
	var body := Color(0.75, 0.8, 0.86) if freezer else WHITE
	Build.box(f, Vector3(0, 1.0, -0.28), Vector3(1.2, 2.0, 0.04), body)
	Build.box(f, Vector3(-0.58, 1.0, 0), Vector3(0.04, 2.0, 0.6), body)
	Build.box(f, Vector3(0.58, 1.0, 0), Vector3(0.04, 2.0, 0.6), body)
	Build.box(f, Vector3(0, 1.98, 0), Vector3(1.2, 0.04, 0.6), body)
	Build.box(f, Vector3(0, 0.09, 0), Vector3(1.2, 0.18, 0.6), body.darkened(0.2))
	Build.glow(Build.box(f, Vector3(0, 1.93, 0.15), Vector3(1.0, 0.03, 0.08), Color.WHITE), Color(0.8, 0.95, 1.0) if freezer else Color(1.0, 1.0, 0.95), 2.5)
	Build.blocker(f, Vector3(0, 1.0, 0), Vector3(1.2, 2.0, 0.6))
	for shelf in 4:
		var y := 0.2 + shelf * 0.44
		if shelf > 0:
			Build.box(f, Vector3(0, y - 0.01, 0), Vector3(1.1, 0.02, 0.5), STEEL)
		var id: String = items[shelf % items.size()]
		for i in 3:
			Food.unit(f, id, Vector3(-0.36 + i * 0.36, y, 0.02), Food.price(id, markup), Vector2(0.35, 0.4))
	# The door hangs from a hinge on the left edge, so it can swing out.
	var hinge := Node3D.new()
	hinge.position = Vector3(-0.6, 0, 0.31)
	f.add_child(hinge)
	Build.box(hinge, Vector3(0.6, 1.07, 0), Vector3(1.18, 1.82, 0.03), GLASS)
	Build.box(hinge, Vector3(0.6, 1.99, 0), Vector3(1.18, 0.04, 0.04), STEEL)
	Build.box(hinge, Vector3(0.6, 0.15, 0), Vector3(1.18, 0.04, 0.04), STEEL)
	Build.box(hinge, Vector3(1.1, 1.05, 0.04), Vector3(0.04, 0.5, 0.04), STEEL)                                # handle
	var door := Build.lookable(hinge, Vector3(0.6, 1.07, 0), Vector3(1.18, 1.82, 0.06), "Open the freezer" if freezer else "Open the fridge", "fridge_door")
	door.set_meta("hinge", hinge)
	door.set_meta("freezer", freezer)


## A crate of fruit, tilted towards you.
static func crate(room: Node3D, at: Vector3, yaw: float, id: String, markup: float) -> void:
	var f := _fixture(room, at, yaw)
	Build.box(f, Vector3(0, 0.3, 0), Vector3(1.0, 0.6, 0.6), Color(0.5, 0.36, 0.22), true)
	Build.box(f, Vector3(0, 0.62, 0), Vector3(1.0, 0.04, 0.6), Color(0.3, 0.5, 0.25))
	for i in 12:
		Food.unit(f, id, Vector3(-0.36 + (i % 4) * 0.24, 0.64, -0.18 + (i / 4) * 0.18), Food.price(id, markup), Vector2(0.23, 0.16))


## A till with a cashier behind it. Stand in front of it to pay.
static func till(room: Node3D, at: Vector3, yaw: float, look_seed: int) -> void:
	var f := _fixture(room, at, yaw)
	Build.box(f, Vector3(0, 0.45, 0), Vector3(1.8, 0.9, 0.7), Color(0.3, 0.32, 0.36), true)
	Build.box(f, Vector3(-0.2, 0.91, 0), Vector3(1.3, 0.02, 0.5), Color(0.08, 0.08, 0.08))                     # belt
	Build.box(f, Vector3(0.65, 1.05, -0.1), Vector3(0.35, 0.28, 0.35), Color(0.15, 0.15, 0.17))                # register
	Build.glow(Build.box(f, Vector3(0.65, 1.3, -0.1), Vector3(0.3, 0.2, 0.03), Color(0.1, 0.3, 0.15)), Color(0.3, 1.0, 0.5), 0.8)
	var rng := RandomNumberGenerator.new()
	rng.seed = look_seed
	Build.person(f, Vector3(0.3, 0, -0.9), PI, Body.random_look(rng))
	Build.trigger(f, Vector3(0, 1.0, 0.95), Vector3(2.0, 2.0, 1.2), "Pay at the till", "checkout")


static func _fixture(room: Node3D, at: Vector3, yaw: float) -> Node3D:
	var node := Node3D.new()
	node.position = at
	node.rotation.y = yaw
	room.add_child(node)
	return node


static func _lights(room: Node3D, spots: Array, reach: float) -> void:
	for spot in spots:
		Build.light(room, spot, Color(1.0, 0.98, 0.94), 2.6, reach)
		Build.glow(Build.box(room, spot + Vector3(0, 0.25, 0), Vector3(1.6, 0.06, 0.4), Color.WHITE), Color.WHITE, 2.5)


## The same list starting from a different place, so neighbouring shelves differ.
static func _turned(items: Array, by: int) -> Array:
	var turned: Array = []
	for i in items.size():
		turned.append(items[(i + by) % items.size()])
	return turned
