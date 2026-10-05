class_name MusicDirector
extends Node
## Dynamic music layers: ambient drone, chase layer, and the heartbeat when he's near.

var player: Player
var orderly: Orderly

var _drone := AudioStreamPlayer.new()
var _chase := AudioStreamPlayer.new()
var _heart := AudioStreamPlayer.new()


func _ready() -> void:
	for p in [_drone, _chase, _heart]:
		add_child(p)
		p.volume_db = -80.0
	_drone.stream = Sfx.streams["drone"]
	_chase.stream = Sfx.streams["chase"]
	_heart.stream = Sfx.streams["heartbeat"]
	_drone.play()
	_chase.play()
	_heart.play()


func _process(delta: float) -> void:
	var chasing := orderly.state in [Orderly.State.CHASE, Orderly.State.GRAB]
	var d := orderly.global_position.distance_to(player.global_position)
	var near := clampf(1.0 - d / 12.0, 0.0, 1.0)
	if player.hidden_in:
		near = maxf(near, 0.3)
	_fade(_drone, -30.0 if chasing else -12.0, delta)   # silence before the storm
	_fade(_chase, -6.0 if chasing else -80.0, delta * (4.0 if chasing else 0.7))
	_fade(_heart, lerpf(-40.0, 0.0, near) if near > 0.0 else -80.0, delta)
	_heart.pitch_scale = lerpf(1.0, 1.6, near if not chasing else 1.0)


func _fade(p: AudioStreamPlayer, target: float, rate: float) -> void:
	p.volume_db = lerpf(p.volume_db, target, clampf(rate * 2.0, 0.0, 1.0))
