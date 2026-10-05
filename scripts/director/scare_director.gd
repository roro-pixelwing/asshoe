class_name ScareDirector
extends Node
## Owns the level's scripted scares and ambient sounds. Paces them so they
## don't stack: an optional scare is vetoed if another happened recently.
## See GAME_DESIGN.md section 5.

const MIN_GAP := 40.0   ## seconds between optional scares

var level: LevelBuilder
var player: Player
var orderly: Orderly
var hud: Hud

var _fired := {}
var _clock := 0.0
var _last_scare := -999.0
var _ambient_t := 25.0
var _patient: Patient
var _patient_stage := 0     # 0 waiting, 1 seen (vanish when you look away), 2 gone


func setup() -> void:
	for cell in level.cells_of("b"):
		_patient = Patient.new()
		level.add_child(_patient)
		# Stands in the corner of the ward, facing the door.
		_patient.position = level.cell_to_world(cell) + Vector3(0.6, 0, 1.0)
		_patient.rotation.y = PI


func _process(delta: float) -> void:
	_clock += delta
	if player.dead:
		return
	_trigger("a", 2.0, _scare_false_alarm, false)
	_trigger("c", 2.5, _scare_the_hunt, true)
	_update_patient()
	_ambient(delta)


func _trigger(key: String, radius: float, scare: Callable, forced: bool) -> void:
	if _fired.has(key):
		return
	for cell in level.cells_of(key):
		if player.global_position.distance_to(level.cell_to_world(cell)) < radius:
			if not forced and _clock - _last_scare < MIN_GAP:
				return
			_fired[key] = true
			_last_scare = _clock
			scare.call()
			return


## (a) A crash behind you, the corridor lights die for 2 seconds. Nothing is there.
func _scare_false_alarm() -> void:
	var behind := player.global_position + player.global_basis.z * 6.0
	Sfx.play_at("crash", behind, 4.0)
	for l in level.lights:
		if l.global_position.distance_to(player.global_position) < 18.0:
			l.blackout(2.2)
	orderly.hear(behind, 30.0)   # he heard it too; he'll come check
	hud.say("What was that...")


## (b) The ward patient. You only notice him when you look at him closely or through
## night vision; once seen, he's gone the next time you look away.
func _update_patient() -> void:
	if _patient == null or _patient_stage == 2:
		return
	var to := _patient.global_position + Vector3(0, 1.5, 0) - player.cam.global_position
	var d := to.length()
	var looking := -player.cam.global_basis.z.dot(to / d) > 0.9
	if _patient_stage == 0 and looking and (d < 3.0 or (player.night_vision and d < 9.0)):
		_patient_stage = 1
		_last_scare = _clock
		Sfx.play("stinger", 0.0)
		hud.say("Jesus...! Hello? ...Are you a patient?")
	elif _patient_stage == 1 and -player.cam.global_basis.z.dot(to / d) < 0.2:
		_patient_stage = 2
		_patient.queue_free()


## (c) Storage room: he hears you, wherever he is. Scripted chase.
func _scare_the_hunt() -> void:
	Sfx.play("stinger", 2.0, 0.8)
	orderly.alert(player.global_position)
	hud.say("He heard me. Run. RUN.")


## Distant sounds keep the building alive between scares.
func _ambient(delta: float) -> void:
	_ambient_t -= delta
	if _ambient_t > 0.0:
		return
	_ambient_t = randf_range(18.0, 35.0)
	if orderly.state == Orderly.State.CHASE:
		return
	var pos := level.random_walkable_near(player.global_position, 8)
	if pos.distance_to(player.global_position) < 8.0:
		return
	var sounds := ["crash", "heavy_step", "mumble", "clank"]
	Sfx.play_at(sounds.pick_random(), pos, -10.0, randf_range(0.5, 0.8))


## Gate opening is loud. The final run.
func on_power_restored() -> void:
	level.exit_gate.open()
	orderly.alert(level.exit_gate.global_position)
	hud.say("The gate's open... and he heard it.")
