class_name Player
extends CharacterBody3D
## Mara. No weapons: walk, sprint, crouch, lean, look back, hide, film.

signal noise(pos: Vector3, radius: float)   ## heard by enemies
signal objective_changed
signal hurt(health: int)
signal died
signal subtitle(text: String)

const WALK := 2.7
const SPRINT := 5.6
const CROUCH := 1.3
const MAX_HEALTH := 3
const BATTERY_SECONDS := 90.0
const BREATH_SECONDS := 6.0
const MOUSE_SENS := 0.0022

var level: LevelBuilder
var env: Environment

var neck := Node3D.new()      # look-back yaw + lean
var head := Node3D.new()      # pitch
var cam := Camera3D.new()
var ir_lamp := SpotLight3D.new()

var health := MAX_HEALTH
var battery := 1.0            # charge of the battery in the camera, 0..1
var spare_batteries := 1
var fuses := 0
var camcorder_up := false
var night_vision := false
var crouching := false
var sprinting := false
var hidden_in: Locker = null
var holding_breath := false
var breath := 1.0
var dead := false
var controls_enabled := false

var _pitch := 0.0
var _step_dist := 0.0
var _bob := 0.0
var _since_hurt := 99.0
var _regen := 0.0
var _locker_yaw := 0.0


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	var cs := CollisionShape3D.new()
	cs.name = "CollisionShape3D"
	var cap := CapsuleShape3D.new()
	cap.radius = 0.32
	cap.height = 1.75
	cs.shape = cap
	cs.position.y = 0.875
	add_child(cs)
	add_child(neck)
	neck.position.y = 1.6
	neck.add_child(head)
	head.add_child(cam)
	cam.fov = 75.0
	cam.near = 0.05
	cam.current = true
	# The camcorder's infrared lamp: what makes night vision actually see things.
	ir_lamp.light_color = Color(0.85, 1.0, 0.85)
	ir_lamp.light_energy = 0.0
	ir_lamp.spot_range = 14.0
	ir_lamp.spot_angle = 38.0
	ir_lamp.shadow_enabled = true
	head.add_child(ir_lamp)


func _unhandled_input(event: InputEvent) -> void:
	if not controls_enabled or dead:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var zoom_scale := cam.fov / 75.0
		if hidden_in:
			_locker_yaw = clampf(_locker_yaw - event.relative.x * MOUSE_SENS * zoom_scale, -0.6, 0.6)
			_pitch = clampf(_pitch - event.relative.y * MOUSE_SENS * zoom_scale, -0.4, 0.4)
		else:
			rotate_y(-event.relative.x * MOUSE_SENS * zoom_scale)
			_pitch = clampf(_pitch - event.relative.y * MOUSE_SENS * zoom_scale, -1.4, 1.4)
	if event.is_action_pressed("camcorder"):
		camcorder_up = not camcorder_up
		if not camcorder_up:
			_set_night_vision(false)
	if event.is_action_pressed("night_vision") and camcorder_up:
		_set_night_vision(not night_vision)
	if event.is_action_pressed("reload_battery"):
		_swap_battery()
	if event.is_action_pressed("interact"):
		if hidden_in:
			exit_locker()
		else:
			var target = find_interactable()
			if target:
				target.interact(self)
	if camcorder_up and event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			cam.fov = maxf(cam.fov - 5.0, 25.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cam.fov = minf(cam.fov + 5.0, 75.0)


func _physics_process(delta: float) -> void:
	if dead:
		return
	head.rotation.x = _pitch
	_update_battery(delta)
	_update_health(delta)
	if not camcorder_up:
		cam.fov = lerpf(cam.fov, 75.0, delta * 8.0)

	if hidden_in:
		_update_hidden(delta)
		return

	var input := Vector2.ZERO
	if controls_enabled:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	crouching = controls_enabled and Input.is_action_pressed("crouch")
	sprinting = controls_enabled and Input.is_action_pressed("sprint") and input.y < 0 and not crouching
	var speed := CROUCH if crouching else (SPRINT if sprinting else WALK)
	if camcorder_up and not sprinting:
		speed *= 0.85
	var dir := (global_basis * Vector3(input.x, 0, input.y)).normalized()
	velocity.x = lerpf(velocity.x, dir.x * speed, delta * 10.0)
	velocity.z = lerpf(velocity.z, dir.z * speed, delta * 10.0)
	velocity.y = 0.0 if is_on_floor() else velocity.y - 9.8 * delta
	move_and_slide()

	# Head height, bob, lean, look-back.
	var horiz := Vector2(velocity.x, velocity.z).length()
	_bob += horiz * delta * (2.4 if sprinting else 2.0)
	var target_h := 0.95 if crouching else 1.6
	neck.position.y = lerpf(neck.position.y, target_h + sin(_bob * 2.0) * 0.04 * minf(horiz / 3.0, 1.0), delta * 10.0)
	var lean := 0.0
	if controls_enabled:
		lean = Input.get_axis("lean_left", "lean_right")
	neck.position.x = lerpf(neck.position.x, lean * 0.55, delta * 8.0)
	neck.rotation.z = lerpf(neck.rotation.z, -lean * 0.18, delta * 8.0)
	var look_back := controls_enabled and Input.is_action_pressed("look_back")
	neck.rotation.y = lerpf(neck.rotation.y, PI * 0.95 if look_back else 0.0, delta * 9.0)

	# Footsteps are the main way enemies find you.
	_step_dist += horiz * delta
	var stride := 1.7 if sprinting else 1.9
	if _step_dist > stride:
		_step_dist = 0.0
		var radius := 16.0 if sprinting else (1.5 if crouching else 5.0)
		noise.emit(global_position, radius)
		Sfx.play("step", -10.0 if crouching else (-2.0 if sprinting else -6.0), randf_range(0.85, 1.15))


func _update_hidden(delta: float) -> void:
	neck.rotation.y = _locker_yaw
	holding_breath = controls_enabled and Input.is_action_pressed("hold_breath") and breath > 0.0
	if holding_breath:
		breath -= delta / BREATH_SECONDS
		if breath <= 0.0:
			breath = 0.0
			holding_breath = false
			Sfx.play("gasp", 0.0)
			noise.emit(global_position, 7.0)
	else:
		breath = minf(breath + delta / (BREATH_SECONDS * 1.5), 1.0)


func _update_battery(delta: float) -> void:
	if night_vision:
		battery -= delta / BATTERY_SECONDS
		if battery <= 0.0:
			battery = 0.0
			_set_night_vision(false)
			subtitle.emit("Battery's dead. [R] to swap." if spare_batteries > 0 else "Battery's dead... I need to find more.")
	# Weak battery = flickering IR lamp.
	if night_vision:
		ir_lamp.light_energy = 1.6 * (1.0 if battery > 0.15 or randf() > 0.15 else 0.2)


func _update_health(delta: float) -> void:
	_since_hurt += delta
	if health < MAX_HEALTH and _since_hurt > 10.0:
		_regen += delta
		if _regen > 8.0:
			_regen = 0.0
			health += 1
			hurt.emit(health)


func _set_night_vision(on: bool) -> void:
	if on and battery <= 0.0:
		subtitle.emit("No charge. [R] to swap battery." if spare_batteries > 0 else "No batteries left.")
		return
	if on != night_vision:
		Sfx.play("nv_on", -8.0, 1.0 if on else 0.7)
	night_vision = on
	ir_lamp.light_energy = 1.6 if on else 0.0
	if env:
		env.ambient_light_energy = 0.9 if on else 0.35
		env.ambient_light_color = Color(0.6, 1.0, 0.6) if on else Color(0.3, 0.33, 0.42)


func _swap_battery() -> void:
	if spare_batteries <= 0 or battery >= 0.99:
		return
	spare_batteries -= 1
	battery = 1.0
	Sfx.play("pickup", -4.0, 0.6)
	objective_changed.emit()


## Returns the best interactable in front of the player, or null.
func find_interactable():
	var best = null
	var best_score := 0.0
	var fwd := -cam.global_basis.z
	for n in get_tree().get_nodes_in_group("interactable"):
		if not is_instance_valid(n) or n.prompt(self) == "":
			continue
		var to: Vector3 = n.interact_point() - cam.global_position
		var d := to.length()
		if d > 2.2:
			continue
		var facing := fwd.dot(to / d)
		if facing < 0.6:
			continue
		var score := facing - d * 0.1
		if score > best_score:
			best_score = score
			best = n
	return best


func enter_locker(l: Locker) -> void:
	hidden_in = l
	l.occupied = true
	l.set_door_visible(false)
	Sfx.play("locker", -4.0)
	velocity = Vector3.ZERO
	global_position = Vector3(l.inside_point.x, 0, l.inside_point.z)
	var out := l.front_point - l.global_position
	look_at(global_position + Vector3(out.x, 0, out.z), Vector3.UP)
	_pitch = 0.0
	_locker_yaw = 0.0
	neck.position = Vector3(0, 1.6, 0)
	neck.rotation = Vector3.ZERO
	$CollisionShape3D.set_deferred("disabled", true)


func exit_locker() -> void:
	if not hidden_in:
		return
	var l := hidden_in
	l.occupied = false
	l.set_door_visible(true)
	hidden_in = null
	holding_breath = false
	Sfx.play("locker", -4.0, 0.9)
	global_position = Vector3(l.front_point.x, 0, l.front_point.z)
	neck.rotation = Vector3.ZERO
	$CollisionShape3D.set_deferred("disabled", false)


func is_lit() -> bool:
	return level != null and level.lit_at(global_position)


func take_hit(from: Vector3) -> void:
	if dead:
		return
	if hidden_in:
		exit_locker()
	health -= 1
	_since_hurt = 0.0
	_regen = 0.0
	Sfx.play("hit", 2.0)
	var push := global_position - from
	push.y = 0
	velocity = push.normalized() * 7.0
	hurt.emit(health)
	if health <= 0:
		dead = true
		died.emit()
