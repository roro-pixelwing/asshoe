extends Node3D
## Assembles Level 1: world, player, the Orderly, directors and HUD.

enum Phase { TITLE, PLAYING, DEAD, WON }

var level := LevelBuilder.new()
var player := Player.new()
var orderly := Orderly.new()
var hud := Hud.new()
var scares := ScareDirector.new()
var music := MusicDirector.new()
var env := Environment.new()
var phase := Phase.TITLE


func _ready() -> void:
	_setup_input()
	_setup_environment()
	add_child(level)
	level.build(LevelData.LEVEL1)

	player.level = level
	player.env = env
	add_child(player)
	player.global_position = level.cell_to_world(level.cells_of("P")[0])
	player.rotation.y = PI  # face into the room
	player._set_night_vision(false)

	orderly.level = level
	orderly.player = player
	add_child(orderly)
	orderly.global_position = level.patrol_points()[0]
	player.noise.connect(orderly.hear)

	hud.player = player
	add_child(hud)
	for n in [scares, music]:
		n.set("player", player)
		n.set("orderly", orderly)
	scares.level = level
	scares.hud = hud
	add_child(scares)
	scares.setup()
	add_child(music)

	level.fuse_box.powered.connect(_on_powered)
	player.died.connect(_on_died)
	hud.show_panel("WITNESS", "Level 1 - Admin Wing\n\nClick to begin\n\n"
		+ "WASD move   Shift sprint (loud)   Ctrl crouch (silent)   Q/E lean   V look back\n"
		+ "Right mouse camcorder   F night vision   R swap battery   Mouse wheel zoom\n"
		+ "Left mouse interact / hide in lockers   Space hold breath (in locker)   Esc release mouse\n\n"
		+ "You cannot fight. Stay in the dark. Don't let him see you.")


func _process(_delta: float) -> void:
	if phase == Phase.PLAYING and level.exit_gate.is_open:
		var gate := level.exit_gate.global_position
		if player.global_position.z < gate.z + 0.6 and absf(player.global_position.x - gate.x) < 1.3:
			_win()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		if phase == Phase.TITLE:
			_start()
		elif phase in [Phase.DEAD, Phase.WON]:
			get_tree().reload_current_scene()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _start() -> void:
	phase = Phase.PLAYING
	hud.hide_panel()
	player.controls_enabled = true
	hud.say(LevelData.INTRO_LINES[0])
	get_tree().create_timer(4.5).timeout.connect(func() -> void: hud.say(LevelData.INTRO_LINES[1]))


func _on_powered() -> void:
	hud.set_objective("Power restored. Get to the EXIT.")
	scares.on_power_restored()


func _on_died() -> void:
	phase = Phase.DEAD
	player.controls_enabled = false
	Sfx.play("stinger", 0.0, 0.6)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.show_panel("YOU DIED", "The tape keeps recording.\n\nClick to try again")


func _win() -> void:
	phase = Phase.WON
	player.controls_enabled = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.show_panel("END OF LEVEL 1", "Mara made it out of the Admin Wing.\nEli is still somewhere inside.\n\nClick to play again")


func _setup_environment() -> void:
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.BLACK
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color(0.02, 0.02, 0.025)
	env.fog_density = 0.035
	env.glow_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)


func _setup_input() -> void:
	var keys := {
		"move_forward": [KEY_W, KEY_UP], "move_back": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
		"sprint": [KEY_SHIFT], "crouch": [KEY_CTRL, KEY_C], "lean_left": [KEY_Q], "lean_right": [KEY_E],
		"look_back": [KEY_V], "night_vision": [KEY_F], "reload_battery": [KEY_R], "hold_breath": [KEY_SPACE],
	}
	for action in keys:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for k in keys[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)
	for pair in [["interact", MOUSE_BUTTON_LEFT], ["camcorder", MOUSE_BUTTON_RIGHT]]:
		if InputMap.has_action(pair[0]):
			continue
		InputMap.add_action(pair[0])
		var mb := InputEventMouseButton.new()
		mb.button_index = pair[1]
		InputMap.action_add_event(pair[0], mb)
