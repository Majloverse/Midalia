extends SceneTree
## Checks that the map still works in the game, then quits. Run after rebuilding the map:
##   godot --path . -s world/milan/check.gd
## Prints "MAP OK" or what went wrong. It walks out of the station, into the supermarket and
## back out, and makes sure there is ground under the player and a wall behind the door.

var _frames := 0
var _started := Time.get_ticks_msec()
var _wrong: Array[String] = []


func _initialize() -> void:
	change_scene_to_file("res://world/world.tscn")


func _expect(ok: bool, what: String) -> void:
	if not ok:
		_wrong.append(what)


func _process(_delta: float) -> bool:
	_frames += 1
	var world = current_scene
	if _frames == 3:
		_expect(Time.get_ticks_msec() - _started < 15000, "the world took over 15 seconds to load")
	elif _frames == 10:
		world.call("_leave")
	elif _frames == 90:
		var player = world.get("_player")
		_expect(world.get("_inside") == "" and player.is_on_floor(), "no ground outside the station")
		world.call("_enter", "SUPERMERCATO")
	elif _frames == 170:
		_expect(world.get("_player").is_on_floor(), "no floor in the supermarket")
		world.call("_leave")
	elif _frames == 250:
		var player = world.get("_player")
		var door: Array = world.get("_street_doors")["SUPERMERCATO"]
		_expect(player.is_on_floor() and player.global_position.distance_to(door[0]) < 1.0, "not back at the supermarket's street door")
		var into := Vector3(sin(door[1]), 0, cos(door[1]))  # the door faces the street; the wall is behind it
		var ray := PhysicsRayQueryParameters3D.create(door[0] + Vector3(0, 1, 0), door[0] + Vector3(0, 1, 0) + into * 6.0)
		ray.exclude = [player.get_rid()]
		_expect(not player.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(), "no wall behind the supermarket's door")
		print("MAP OK" if _wrong.is_empty() else "MAP BROKEN: " + ", ".join(_wrong))
		quit(0 if _wrong.is_empty() else 1)
	return false
