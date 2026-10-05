extends Node
## Procedurally synthesised sounds, so the prototype ships with zero audio assets.
## Replace any entry with a real recording later (e.g. from Freesound, CC0) by
## assigning `streams["name"] = load("res://assets/audio/...")`.

const RATE := 22050

var streams := {}


func _ready() -> void:
	streams["step"] = _make(0.22, func(t: float) -> float:
		return sin(TAU * 70.0 * t) * exp(-t * 30.0) * 0.6 + randf_range(-1, 1) * exp(-t * 70.0) * 0.25)
	streams["heavy_step"] = _make(0.4, func(t: float) -> float:
		return sin(TAU * 42.0 * t) * exp(-t * 12.0) + randf_range(-1, 1) * exp(-t * 40.0) * 0.35)
	streams["crash"] = _make(1.2, func(t: float) -> float:
		return randf_range(-1, 1) * exp(-t * 5.0) * 0.8 \
			+ sin(TAU * 2350.0 * t) * exp(-t * 7.0) * 0.3 + sin(TAU * 3170.0 * t) * exp(-t * 9.0) * 0.25)
	streams["stinger"] = _make(2.6, func(t: float) -> float:
		var env := minf(t * 30.0, 1.0) * exp(-t * 1.3)
		var tone := sin(TAU * 220.0 * t) + sin(TAU * 233.1 * t) + sin(TAU * 311.1 * t) + sin(TAU * 466.2 * t * (1.0 + t * 0.02))
		return (tone * 0.22 + randf_range(-1, 1) * 0.35 * exp(-t * 4.0)) * env)
	streams["roar"] = _make(1.6, func(t: float) -> float:
		var f := 75.0 + 25.0 * sin(TAU * 5.0 * t)
		var saw := fmod(t * f, 1.0) * 2.0 - 1.0
		var env := minf(t * 8.0, 1.0) * exp(-t * 1.2)
		return (saw * 0.6 + randf_range(-1, 1) * 0.5) * env)
	streams["mumble"] = _make(1.4, func(t: float) -> float:
		var f := 95.0 + 15.0 * sin(TAU * 3.0 * t)
		var syll := 0.5 + 0.5 * sin(TAU * 4.5 * t)
		return (fmod(t * f, 1.0) - 0.5) * syll * sin(PI * t / 1.4) * 0.5)
	streams["clank"] = _make(1.8, func(t: float) -> float:
		return (sin(TAU * 180.0 * t) + sin(TAU * 431.0 * t) * 0.7 + sin(TAU * 1077.0 * t) * 0.4) * exp(-t * 2.5) * 0.4 \
			+ randf_range(-1, 1) * exp(-t * 25.0) * 0.6)
	streams["pickup"] = _make(0.15, func(t: float) -> float:
		return sin(TAU * (900.0 + t * 3000.0) * t) * exp(-t * 20.0) * 0.4)
	streams["nv_on"] = _make(0.35, func(t: float) -> float:
		return sin(TAU * (3000.0 + t * 6000.0) * t) * 0.08 + randf_range(-1, 1) * 0.05 * exp(-t * 10.0))
	streams["locker"] = _make(0.5, func(t: float) -> float:
		return (sin(TAU * 260.0 * t) * 0.5 + randf_range(-1, 1) * 0.5) * exp(-t * 9.0))
	streams["gasp"] = _make(0.7, func(t: float) -> float:
		return randf_range(-1, 1) * sin(PI * t / 0.7) * 0.6)
	streams["hit"] = _make(0.5, func(t: float) -> float:
		return (sin(TAU * 60.0 * t) + randf_range(-1, 1)) * exp(-t * 8.0) * 0.8)
	# Loops: frequencies chosen so each loop contains whole cycles (no clicks).
	var drone := func(t: float) -> float:
		var wob := 0.6 + 0.4 * sin(TAU * 0.25 * t)
		return (sin(TAU * 55.0 * t) + sin(TAU * 55.75 * t) + sin(TAU * 82.5 * t) * 0.4) * 0.22 * wob
	streams["drone"] = _make(4.0, drone, true)
	var chase := func(t: float) -> float:
		var beat := fmod(t, 0.25)
		var kick := sin(TAU * 50.0 * beat) * exp(-beat * 18.0)
		var pulse := (fmod(t * 110.0, 1.0) * 2.0 - 1.0) * (0.5 + 0.5 * sin(TAU * 8.0 * t)) * 0.25
		var shriek := sin(TAU * (1760.0 + 40.0 * sin(TAU * 0.5 * t)) * t) * 0.04
		return kick * 0.7 + pulse + shriek
	streams["chase"] = _make(2.0, chase, true)
	var heartbeat := func(t: float) -> float:
		var a := sin(TAU * 48.0 * t) * exp(-t * 18.0)
		var t2 := maxf(t - 0.24, 0.0)
		var b := sin(TAU * 44.0 * t2) * exp(-t2 * 20.0) * (1.0 if t > 0.24 else 0.0)
		return (a + b * 0.8) * 0.9
	streams["heartbeat"] = _make(0.9, heartbeat, true)


func _make(length: float, f: Callable, loop := false) -> AudioStreamWAV:
	var n := int(length * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var v: float = clampf(f.call(float(i) / RATE), -1.0, 1.0)
		data.encode_s16(i * 2, int(v * 32767.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.data = data
	if loop:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_end = n
	return s


## Fire-and-forget 3D sound at a world position.
func play_at(sound: String, pos: Vector3, volume_db := 0.0, pitch := 1.0) -> void:
	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = streams[sound]
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.max_distance = 60.0
	p.unit_size = 6.0
	tree.current_scene.add_child(p)
	p.global_position = pos
	p.finished.connect(p.queue_free)
	p.play()


## Fire-and-forget non-positional sound (UI, player's own body).
func play(sound: String, volume_db := 0.0, pitch := 1.0) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = streams[sound]
	p.volume_db = volume_db
	p.pitch_scale = pitch
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()
