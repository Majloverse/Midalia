extends SceneTree
## Starts the game with the player on the open ground nearest a real place, for looking round the map.
##   godot --path . -s world/milan/spawn.gd -- <latitude> <longitude>
## For example in front of Bocconi:  -- 45.4502 9.1893     On the Duomo's roof: -- 45.4641 9.1919 roof

const CENTRE := Vector2(45.4641, 9.1919)  # the map's middle, as in build_map.py
var _frames := 0


func _initialize() -> void:
	change_scene_to_file("res://world/world.tscn")


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames != 10:  # the world needs a few frames before its walls can be felt
		return false
	var args := OS.get_cmdline_user_args()
	var target := Vector3((float(args[1]) - CENTRE.y) * 111320.0 * cos(deg_to_rad(CENTRE.x)), 0, -(float(args[0]) - CENTRE.x) * 111320.0)
	var on_roof := args.size() > 2 and args[2] == "roof"
	var player = current_scene.get("_player")
	var space = player.get_world_3d().direct_space_state
	for i in 400:  # spiral outwards until there is open ground, not a roof
		var at := target + Vector3(cos(i * 0.7), 0, sin(i * 0.7)) * (i * 0.25)
		var ray := PhysicsRayQueryParameters3D.create(at + Vector3(0, 400, 0), at + Vector3(0, -1, 0))
		ray.exclude = [player.get_rid()]
		var hit = space.intersect_ray(ray)
		if hit and (on_roof or hit.position.y < 0.3):
			current_scene.set("_inside", "")
			player.teleport(hit.position + Vector3(0, 0.2, 0), 0.0)
			player.set_camera_distance(Settings.CAMERA_DISTANCE)
			break
	return false
