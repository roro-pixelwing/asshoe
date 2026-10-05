class_name Orderly
extends CharacterBody3D
## The Orderly. See docs/CHARACTERS.md.
##   PATROL -> (noise) -> INVESTIGATE -> (sees you) -> CHASE
##   CHASE -> (lost you) -> SEARCH -> (gives up) -> PATROL
##   CHASE + saw you enter a locker -> GRAB (rips it open)

signal state_changed(state: int)

enum State { PATROL, INVESTIGATE, CHASE, SEARCH, GRAB, STAGGER }

const SPEED := {
	State.PATROL: 1.6, State.INVESTIGATE: 2.6, State.CHASE: 5.25,
	State.SEARCH: 1.9, State.GRAB: 4.5, State.STAGGER: 0.0,
}
const FOV_COS := 0.5            # ~120 degree vision cone
const LOSE_AFTER := 4.0         # seconds without sight before he gives up the chase
const SEARCH_TIME := 14.0

var level: LevelBuilder
var player: Player
var state := State.PATROL

var _waypoints: Array[Vector3] = []
var _wp := 0
var _path := PackedVector3Array()
var _path_i := 0
var _goal := Vector3.INF
var _repath := 0.0
var _wait := 0.0
var _last_seen := Vector3.ZERO
var _unseen := 0.0
var _state_time := 0.0
var _attack_cd := 0.0
var _search_points := 0
var _grab_locker: Locker = null
var _hiding_suspicion := 0.0
var _step := 0.0
var _mumble := randf_range(5, 10)
var _hurry := false
var _voice := AudioStreamPlayer3D.new()
var _headlamp := SpotLight3D.new()


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 2.1
	cs.shape = cap
	cs.position.y = 1.05
	add_child(cs)
	_build_body()
	_voice.max_distance = 40.0
	_voice.unit_size = 5.0
	_voice.position.y = 2.0
	add_child(_voice)
	_waypoints = level.patrol_points()
	if _waypoints.is_empty():
		_waypoints = [global_position]


func _physics_process(delta: float) -> void:
	_state_time += delta
	_attack_cd -= delta
	_repath -= delta
	var sees := can_see_player()
	if sees:
		_last_seen = player.global_position
		_unseen = 0.0
	else:
		_unseen += delta

	match state:
		State.PATROL:
			if sees:
				_set_state(State.CHASE)
			elif _wait > 0.0:
				_wait -= delta
			elif _go_to(_waypoints[_wp]):
				_wp = (_wp + 1) % _waypoints.size()
				_wait = randf_range(1.0, 2.5)
		State.INVESTIGATE:
			if sees:
				_set_state(State.CHASE)
			elif _go_to(_last_seen):
				_set_state(State.SEARCH)
		State.CHASE:
			# The moment you vanish into a locker while he can see you, he knows.
			if player.hidden_in and _unseen < 0.6:
				_grab_locker = player.hidden_in
				_set_state(State.GRAB)
			elif _unseen > LOSE_AFTER:
				_set_state(State.SEARCH)
			else:
				_go_to(player.global_position if sees else _last_seen, 0.3)
				_try_attack()
		State.SEARCH:
			if sees:
				_set_state(State.CHASE)
			elif _state_time > SEARCH_TIME:
				_set_state(State.PATROL)
			elif _wait > 0.0:
				_wait -= delta
				_look_around(delta)
			elif _go_to(_goal if _goal != Vector3.INF else _last_seen):
				_wait = randf_range(1.5, 3.0)
				_goal = level.random_walkable_near(_last_seen, 3)
			_check_lockers(delta)
		State.GRAB:
			if _grab_locker == null or player.hidden_in != _grab_locker:
				_set_state(State.CHASE)
			elif _go_to(_grab_locker.front_point, 0.0, 0.9):
				_grab_locker.slam()
				Sfx.play_at("crash", _grab_locker.global_position, 2.0, 0.6)
				_say("roar")
				player.take_hit(global_position)
				_set_state(State.STAGGER)
		State.STAGGER:
			velocity.x = 0
			velocity.z = 0
			if _state_time > 1.0:
				_set_state(State.CHASE)

	velocity.y = 0.0 if is_on_floor() else velocity.y - 9.8 * delta
	move_and_slide()
	_footsteps(delta)
	_mumble -= delta
	if _mumble < 0.0 and state != State.CHASE:
		_mumble = randf_range(7, 14)
		_say("mumble")


## Called for every noise in the world (player footsteps, gasps, scares).
func hear(pos: Vector3, radius: float) -> void:
	if global_position.distance_to(pos) > radius:
		return
	if state in [State.CHASE, State.GRAB, State.STAGGER]:
		return
	_last_seen = pos
	_hurry = false
	_set_state(State.INVESTIGATE)


## Scripted alert: he knows exactly where you are and runs there.
func alert(pos: Vector3) -> void:
	if state in [State.CHASE, State.GRAB]:
		return
	_last_seen = pos
	_say("roar")
	_hurry = true
	_set_state(State.INVESTIGATE)


func can_see_player() -> bool:
	if player.hidden_in or player.dead:
		return false
	var eye := global_position + Vector3(0, 1.9, 0)
	var target := player.cam.global_position
	var to := target - eye
	var d := to.length()
	if d < 1.5:
		return true
	var sight := 6.0                     # darkness hides you...
	if player.is_lit():
		sight = 20.0                     # ...light betrays you
	if player.crouching:
		sight *= 0.6
	if state == State.CHASE:
		sight = maxf(sight, 16.0)        # once locked on, he keeps you
	if d > sight:
		return false
	var fwd := -global_basis.z
	if state != State.CHASE and fwd.dot(to / d) < FOV_COS:
		return false
	var q := PhysicsRayQueryParameters3D.create(eye, target, 1)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _set_state(s: State) -> void:
	if s == State.CHASE and state != State.CHASE:
		_say("roar")
	if s == State.SEARCH:
		_goal = Vector3.INF
		_hiding_suspicion = 0.0
	state = s
	_state_time = 0.0
	_repath = 0.0
	_wait = 0.0
	state_changed.emit(s)


func _speed() -> float:
	var s: float = SPEED[state]
	if state == State.INVESTIGATE and _hurry:
		s = SPEED[State.CHASE] * 0.9
	if state == State.CHASE:
		var d := global_position.distance_to(player.global_position)
		if _state_time < 1.5:
			s *= 0.75                     # a fair head start when he first spots you
		elif d > 12.0:
			s *= 1.15                     # rubber-band so he never falls hopelessly behind
	return s


## Moves along a grid path toward `goal`. Returns true on arrival.
func _go_to(goal: Vector3, repath_every := 1.0, arrive := 0.5) -> bool:
	var flat := Vector3(goal.x, 0, goal.z)
	if _repath <= 0.0 or flat.distance_to(_path_end()) > 1.0:
		_path = level.find_path(global_position, flat)
		_path_i = 0
		_repath = repath_every if repath_every > 0.0 else 999.0
	var pos := Vector3(global_position.x, 0, global_position.z)
	if pos.distance_to(flat) < arrive:
		velocity.x = 0
		velocity.z = 0
		return true
	while _path_i < _path.size() and pos.distance_to(_path[_path_i]) < 0.35:
		_path_i += 1
	var next := flat if _path_i >= _path.size() else _path[_path_i]
	var dir := (next - pos)
	dir.y = 0
	if dir.length() < 0.01:
		return true
	dir = dir.normalized()
	var spd := _speed()
	velocity.x = dir.x * spd
	velocity.z = dir.z * spd
	_face(dir, get_physics_process_delta_time())
	return false


func _path_end() -> Vector3:
	return _path[_path.size() - 1] if _path.size() > 0 else Vector3.INF


func _face(dir: Vector3, delta: float) -> void:
	var target_yaw := atan2(-dir.x, -dir.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, minf(delta * 8.0, 1.0))


func _look_around(delta: float) -> void:
	rotation.y += sin(_state_time * 1.3) * delta * 1.5


func _try_attack() -> void:
	if _attack_cd > 0.0:
		return
	if global_position.distance_to(player.global_position) < 1.5:
		_attack_cd = 1.8
		player.take_hit(global_position)
		_set_state(State.STAGGER)     # brief pause: the player's chance to escape


## While searching, he listens at lockers. Holding your breath beats it.
func _check_lockers(delta: float) -> void:
	if not player.hidden_in:
		return
	var l := player.hidden_in
	if global_position.distance_to(l.front_point) > 3.0:
		_hiding_suspicion = maxf(_hiding_suspicion - delta, 0.0)
		return
	_hiding_suspicion += delta * (0.0 if player.holding_breath else 1.0)
	if _hiding_suspicion > 2.0:
		_grab_locker = l
		_set_state(State.GRAB)


func _footsteps(delta: float) -> void:
	var v := Vector2(velocity.x, velocity.z).length()
	_step += v * delta
	if _step > 1.6:
		_step = 0.0
		Sfx.play_at("heavy_step", global_position, -2.0 if state == State.CHASE else -6.0, randf_range(0.9, 1.1))


func _say(sound: String) -> void:
	_voice.stream = Sfx.streams[sound]
	_voice.volume_db = 6.0 if sound == "roar" else -2.0
	_voice.pitch_scale = randf_range(0.85, 1.0)
	_voice.play()


func _build_body() -> void:
	# Hunched 2.1 m brute in stained scrubs with a taped-on headlamp.
	var scrubs := StandardMaterial3D.new()
	scrubs.albedo_color = Color(0.72, 0.7, 0.62)
	var skin := StandardMaterial3D.new()
	skin.albedo_color = Color(0.55, 0.42, 0.38)
	var blood := StandardMaterial3D.new()
	blood.albedo_color = Color(0.35, 0.03, 0.02)
	var eye_mat := StandardMaterial3D.new()
	eye_mat.emission_enabled = true
	eye_mat.emission = Color(1, 0.05, 0.02)
	eye_mat.emission_energy_multiplier = 6.0
	var torso := Node3D.new()
	torso.position.y = 1.15
	torso.rotation.x = -0.28  # hunch forward
	add_child(torso)
	_box(torso, Vector3(0.95, 1.05, 0.55), Vector3(0, 0.5, 0), scrubs)
	_box(torso, Vector3(0.6, 0.5, 0.05), Vector3(0.1, 0.4, -0.29), blood)   # stain on the front
	_box(torso, Vector3(0.42, 0.45, 0.42), Vector3(0, 1.22, -0.08), skin)  # head
	_box(torso, Vector3(0.25, 1.15, 0.25), Vector3(-0.62, 0.15, -0.05), skin)  # long arms
	_box(torso, Vector3(0.25, 1.15, 0.25), Vector3(0.62, 0.15, -0.05), skin)
	_box(torso, Vector3(0.34, 0.3, 0.34), Vector3(-0.62, -0.5, -0.05), skin)   # swollen hands
	_box(torso, Vector3(0.34, 0.3, 0.34), Vector3(0.62, -0.5, -0.05), skin)
	for x in [-0.1, 0.1]:
		var e := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.03
		sm.height = 0.06
		sm.material = eye_mat
		e.mesh = sm
		e.position = Vector3(x, 1.28, -0.3)
		torso.add_child(e)
	_box(self, Vector3(0.32, 1.15, 0.32), Vector3(-0.25, 0.57, 0), scrubs)  # legs
	_box(self, Vector3(0.32, 1.15, 0.32), Vector3(0.25, 0.57, 0), scrubs)
	# His headlamp is how you spot him coming in the dark.
	_headlamp.light_color = Color(1.0, 0.85, 0.6)
	_headlamp.light_energy = 2.0
	_headlamp.spot_range = 10.0
	_headlamp.spot_angle = 24.0
	_headlamp.shadow_enabled = true
	_headlamp.position = Vector3(0, 1.45, -0.25)
	_headlamp.rotation.x = 0.1
	torso.add_child(_headlamp)


func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	bm.material = mat
	mi.mesh = bm
	mi.position = pos
	parent.add_child(mi)
