class_name Food
## Everything you can eat: what it costs, what it does for you, and what it looks like on a shelf.
##
## kind:    "meal" is ready to eat, "cook" needs your own kitchen, "snack" is a little extra.
## price:   euro in the supermarket; smaller shops charge more (Settings.SHOP_PRICES).
## gain:    wellbeing from eating it.
## section: where shops keep it.
## shape, color, band, size (width, height, depth in metres): how it is drawn.

const ITEMS := {
	# Dry goods
	"pasta": {"name": "Pasta", "price": 2, "gain": 7, "kind": "cook", "section": "dry", "shape": "box", "color": Color(0.15, 0.3, 0.7), "band": Color(0.95, 0.85, 0.4), "size": Vector3(0.13, 0.24, 0.06)},
	"rice": {"name": "Rice", "price": 2, "gain": 6, "kind": "cook", "section": "dry", "shape": "box", "color": Color(0.93, 0.93, 0.88), "band": Color(0.8, 0.2, 0.2), "size": Vector3(0.12, 0.2, 0.06)},
	"soup": {"name": "Tinned soup", "price": 2, "gain": 5, "kind": "cook", "section": "dry", "shape": "can", "color": Color(0.8, 0.15, 0.12), "band": Color(0.95, 0.95, 0.9), "size": Vector3(0.09, 0.12, 0.09)},
	"beans": {"name": "Tinned beans", "price": 1, "gain": 4, "kind": "cook", "section": "dry", "shape": "can", "color": Color(0.1, 0.35, 0.45), "band": Color(0.9, 0.5, 0.2), "size": Vector3(0.09, 0.12, 0.09)},
	"noodles": {"name": "Instant noodles", "price": 1, "gain": 4, "kind": "cook", "section": "dry", "shape": "can", "color": Color(0.95, 0.8, 0.2), "band": Color(0.85, 0.2, 0.15), "size": Vector3(0.11, 0.1, 0.11)},
	# Snacks
	"chocolate": {"name": "Chocolate", "price": 2, "gain": 2, "kind": "snack", "section": "snacks", "shape": "box", "color": Color(0.35, 0.2, 0.12), "band": Color(0.85, 0.7, 0.3), "size": Vector3(0.1, 0.19, 0.025)},
	"crisps": {"name": "Crisps", "price": 2, "gain": 1, "kind": "snack", "section": "snacks", "shape": "box", "color": Color(0.95, 0.75, 0.1), "band": Color(0.8, 0.15, 0.15), "size": Vector3(0.17, 0.24, 0.07)},
	"biscuits": {"name": "Biscuits", "price": 2, "gain": 1, "kind": "snack", "section": "snacks", "shape": "can", "color": Color(0.85, 0.45, 0.15), "band": Color(0.95, 0.9, 0.75), "size": Vector3(0.07, 0.22, 0.07)},
	# Drinks
	"water": {"name": "Water", "price": 1, "gain": 1, "kind": "snack", "section": "drinks", "shape": "bottle", "color": Color(0.6, 0.8, 0.95), "band": Color(0.2, 0.4, 0.8), "size": Vector3(0.08, 0.28, 0.08)},
	"cola": {"name": "Cola", "price": 2, "gain": 1, "kind": "snack", "section": "drinks", "shape": "can", "color": Color(0.75, 0.08, 0.1), "band": Color(0.95, 0.95, 0.95), "size": Vector3(0.066, 0.12, 0.066)},
	"energy": {"name": "Energy drink", "price": 3, "gain": 2, "kind": "snack", "section": "drinks", "shape": "can", "color": Color(0.15, 0.6, 0.3), "band": Color(0.1, 0.1, 0.1), "size": Vector3(0.055, 0.15, 0.055)},
	"beer": {"name": "Beer", "price": 2, "gain": 2, "kind": "snack", "section": "drinks", "shape": "bottle", "color": Color(0.4, 0.25, 0.08), "band": Color(0.9, 0.8, 0.3), "size": Vector3(0.07, 0.25, 0.07)},
	"juice": {"name": "Orange juice", "price": 2, "gain": 1, "kind": "snack", "section": "drinks", "shape": "box", "color": Color(0.95, 0.55, 0.1), "band": Color(0.95, 0.95, 0.9), "size": Vector3(0.08, 0.22, 0.08)},
	# Bakery
	"bread": {"name": "Bread", "price": 2, "gain": 3, "kind": "meal", "section": "bakery", "shape": "ball", "color": Color(0.75, 0.55, 0.3), "size": Vector3(0.24, 0.12, 0.12)},
	"focaccia": {"name": "Focaccia", "price": 3, "gain": 4, "kind": "meal", "section": "bakery", "shape": "box", "color": Color(0.85, 0.7, 0.4), "band": Color(0.5, 0.6, 0.25), "size": Vector3(0.22, 0.04, 0.16)},
	"cornetto": {"name": "Cornetto", "price": 1, "gain": 1, "kind": "snack", "section": "bakery", "shape": "ball", "color": Color(0.85, 0.6, 0.25), "size": Vector3(0.14, 0.07, 0.08)},
	# Fruit
	"banana": {"name": "Banana", "price": 1, "gain": 1, "kind": "snack", "section": "produce", "shape": "ball", "color": Color(0.95, 0.85, 0.2), "size": Vector3(0.18, 0.05, 0.05)},
	"apple": {"name": "Apple", "price": 1, "gain": 1, "kind": "snack", "section": "produce", "shape": "ball", "color": Color(0.8, 0.15, 0.15), "size": Vector3(0.09, 0.09, 0.09)},
	"orange": {"name": "Orange", "price": 1, "gain": 1, "kind": "snack", "section": "produce", "shape": "ball", "color": Color(0.95, 0.5, 0.1), "size": Vector3(0.1, 0.1, 0.1)},
	# The fridges
	"panino": {"name": "Panino", "price": 4, "gain": 5, "kind": "meal", "section": "fridge", "shape": "box", "color": Color(0.85, 0.7, 0.45), "band": Color(0.75, 0.25, 0.2), "size": Vector3(0.2, 0.08, 0.1)},
	"tramezzino": {"name": "Tramezzino", "price": 3, "gain": 4, "kind": "meal", "section": "fridge", "shape": "box", "color": Color(0.95, 0.93, 0.85), "band": Color(0.4, 0.65, 0.3), "size": Vector3(0.16, 0.08, 0.08)},
	"salad": {"name": "Salad bowl", "price": 5, "gain": 5, "kind": "meal", "section": "fridge", "shape": "can", "color": Color(0.3, 0.6, 0.25), "band": Color(0.9, 0.9, 0.9), "size": Vector3(0.18, 0.08, 0.18)},
	"eggs": {"name": "Eggs", "price": 3, "gain": 7, "kind": "cook", "section": "fridge", "shape": "box", "color": Color(0.7, 0.68, 0.62), "size": Vector3(0.24, 0.07, 0.1)},
	"milk": {"name": "Milk", "price": 1, "gain": 1, "kind": "snack", "section": "fridge", "shape": "box", "color": Color(0.96, 0.96, 0.98), "band": Color(0.2, 0.4, 0.8), "size": Vector3(0.08, 0.22, 0.08)},
	"yogurt": {"name": "Yogurt", "price": 1, "gain": 1, "kind": "snack", "section": "fridge", "shape": "can", "color": Color(0.97, 0.95, 0.9), "band": Color(0.85, 0.3, 0.5), "size": Vector3(0.07, 0.08, 0.07)},
	"cheese": {"name": "Cheese", "price": 3, "gain": 2, "kind": "snack", "section": "fridge", "shape": "box", "color": Color(0.95, 0.8, 0.3), "size": Vector3(0.14, 0.06, 0.1)},
	# The freezers
	"pizza": {"name": "Frozen pizza", "price": 4, "gain": 8, "kind": "cook", "section": "freezer", "shape": "box", "color": Color(0.75, 0.2, 0.15), "band": Color(0.95, 0.85, 0.5), "size": Vector3(0.27, 0.27, 0.035)},
	"fishfingers": {"name": "Fish fingers", "price": 3, "gain": 6, "kind": "cook", "section": "freezer", "shape": "box", "color": Color(0.15, 0.4, 0.75), "band": Color(0.95, 0.7, 0.2), "size": Vector3(0.2, 0.12, 0.05)},
	"icecream": {"name": "Ice cream", "price": 3, "gain": 3, "kind": "snack", "section": "freezer", "shape": "can", "color": Color(0.95, 0.85, 0.8), "band": Color(0.5, 0.3, 0.2), "size": Vector3(0.12, 0.1, 0.12)},
}

static var _meshes := {}
static var _materials := {}
static var _shapes := {}


static func name_of(id: String) -> String:
	return ITEMS[id].name


## Everything a shop keeps in one section, in a fixed order.
static func in_section(section: String) -> Array:
	return ITEMS.keys().filter(func(id): return ITEMS[id].section == section)


## What a shop charges. `markup` is 1.0 in the supermarket and more elsewhere.
static func price(id: String, markup: float) -> int:
	return ceili(ITEMS[id].price * markup)


## The item as a little 3D model, standing on its own origin.
static func model(id: String) -> Node3D:
	var item: Dictionary = ITEMS[id]
	var size: Vector3 = item.size
	var color: Color = item.color
	var band: Color = item.get("band", color.darkened(0.25))
	var node := Node3D.new()
	match item.shape:
		"box":
			_part(node, _box(size), color, Vector3(0, size.y / 2, 0))
			if item.has("band"):
				_part(node, _box(Vector3(size.x * 1.03, size.y * 0.3, size.z * 1.03)), band, Vector3(0, size.y * 0.55, 0))
		"can":
			_part(node, _cylinder(size.x / 2, size.y), color, Vector3(0, size.y / 2, 0))
			_part(node, _cylinder(size.x / 2 * 1.03, size.y * 0.35), band, Vector3(0, size.y * 0.5, 0))
		"bottle":
			_part(node, _cylinder(size.x / 2, size.y * 0.65), color, Vector3(0, size.y * 0.325, 0))
			_part(node, _cylinder(size.x / 5, size.y * 0.3), color, Vector3(0, size.y * 0.8, 0))
			_part(node, _cylinder(size.x / 4, size.y * 0.06), band, Vector3(0, size.y * 0.97, 0))
			_part(node, _cylinder(size.x / 2 * 1.03, size.y * 0.2), band, Vector3(0, size.y * 0.35, 0))
		"ball":
			# A sphere squashed into the item's proportions: loaves, fruit, pastries.
			var ball := _part(node, _sphere(), color, Vector3(0, size.y / 2, 0))
			ball.scale = size
	return node


## One item on a shop shelf: look at it and click to put it in your basket.
## `slot` is how much shelf the item has to itself (width, height): the whole of
## it can be aimed at, so there are no dead gaps between small things.
static func unit(parent: Node3D, id: String, at: Vector3, cost: int, slot: Vector2 = Vector2.ZERO) -> Node3D:
	var node := model(id)
	node.position = at
	parent.add_child(node)
	var size: Vector3 = ITEMS[id].size
	var reach := Vector3(maxf(maxf(size.x, 0.1) + 0.04, slot.x), maxf(size.y + 0.06, slot.y), maxf(size.z, 0.1) + 0.04)
	var area := Build.lookable(node, Vector3(0, reach.y / 2, 0), Vector3.ONE, "%s, %d euro: add to basket" % [name_of(id), cost], "take")
	var key := "%s %s" % [id, slot]
	if not _shapes.has(key):
		var shape := BoxShape3D.new()
		shape.size = reach
		_shapes[key] = shape
	area.get_child(0).shape = _shapes[key]
	area.set_meta("item", id)
	area.set_meta("price", cost)
	return node


static func _part(node: Node3D, mesh: Mesh, color: Color, at: Vector3) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	var key := color.to_html()
	if not _materials.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		_materials[key] = material
	part.material_override = _materials[key]
	part.position = at
	node.add_child(part)
	return part


static func _box(size: Vector3) -> Mesh:
	var key := "box %s" % size
	if not _meshes.has(key):
		var mesh := BoxMesh.new()
		mesh.size = size
		_meshes[key] = mesh
	return _meshes[key]


static func _cylinder(radius: float, height: float) -> Mesh:
	var key := "cylinder %s %s" % [radius, height]
	if not _meshes.has(key):
		var mesh := CylinderMesh.new()
		mesh.top_radius = radius
		mesh.bottom_radius = radius
		mesh.height = height
		mesh.radial_segments = 12
		mesh.rings = 1
		_meshes[key] = mesh
	return _meshes[key]


static func _sphere() -> Mesh:
	if not _meshes.has("sphere"):
		var mesh := SphereMesh.new()
		mesh.radius = 0.5
		mesh.height = 1.0
		mesh.radial_segments = 12
		mesh.rings = 6
		_meshes["sphere"] = mesh
	return _meshes["sphere"]
