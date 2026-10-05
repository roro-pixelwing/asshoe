extends Node
## Dev tool: renders a few views to user:// screenshots. Run with a display:
##   godot --rendering-driver opengl3 res://tests/screenshot.tscn

var main

func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _frames(10)
	main._start()
	var p: Player = main.player
	var o: Orderly = main.orderly
	var lv: LevelBuilder = main.level
	o.set_physics_process(false)
	await _frames(30)
	await _shot("1_start")
	# Corridor under a light, the Orderly ahead.
	p.global_position = lv.cell_to_world(Vector2i(6, 7))
	p.rotation.y = -PI / 2
	o.global_position = lv.cell_to_world(Vector2i(12, 7))
	o.look_at(Vector3(p.global_position.x, 0, p.global_position.z), Vector3.UP)
	await _frames(30)
	await _shot("2_corridor")
	p.camcorder_up = true
	p._set_night_vision(true)
	await _frames(30)
	await _shot("3_nightvision")
	p._set_night_vision(false)
	p.camcorder_up = false
	p.enter_locker(lv.lockers[0])
	await _frames(20)
	await _shot("4_locker")
	get_tree().quit()

func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OS.get_environment("SHOT_DIR") + "/" + name + ".png")

func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
