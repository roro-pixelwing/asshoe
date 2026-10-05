class_name FlickerLight
extends Node3D
## Dying fluorescent ceiling lamp. Standing under one makes the player visible from afar.

var is_on := true
var light := OmniLight3D.new()
var lamp := MeshInstance3D.new()
var _blackout := 0.0
var _flicker_t := randf_range(2.0, 8.0)
var _lamp_mat := StandardMaterial3D.new()


func _ready() -> void:
	add_to_group("lights")
	light.light_color = Color(1.0, 0.86, 0.62)
	light.light_energy = 1.4
	light.omni_range = 7.5
	light.omni_attenuation = 1.4
	light.shadow_enabled = true
	light.position.y = -0.3
	add_child(light)
	var m := BoxMesh.new()
	m.size = Vector3(1.2, 0.08, 0.3)
	_lamp_mat.emission_enabled = true
	_lamp_mat.emission = Color(1.0, 0.9, 0.7)
	_lamp_mat.emission_energy_multiplier = 2.0
	m.material = _lamp_mat
	lamp.mesh = m
	add_child(lamp)


func _process(delta: float) -> void:
	if _blackout > 0.0:
		_blackout -= delta
		_switch(false)
		return
	_flicker_t -= delta
	if _flicker_t < 0.0:
		# Short stutter, then on again.
		_switch(randf() > 0.5)
		if _flicker_t < -0.4:
			_flicker_t = randf_range(3.0, 10.0)
			_switch(true)


## Kill the light for `seconds` (used by scares).
func blackout(seconds: float) -> void:
	_blackout = seconds


func _switch(on: bool) -> void:
	is_on = on
	light.visible = on
	_lamp_mat.emission_energy_multiplier = 2.0 if on else 0.0
