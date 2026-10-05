class_name FuseBox
extends Node3D
## Needs FUSES_NEEDED fuses; restores power to the exit gate.

signal powered
const FUSES_NEEDED := 2
var inserted := 0
var _lamp_mat := StandardMaterial3D.new()


func setup(cell_pos: Vector3, wall_dir: Vector2i) -> void:
	add_to_group("interactable")
	var offset := Vector3(wall_dir.x, 0, wall_dir.y) * 1.1
	global_position = cell_pos + offset
	var mi := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = Vector3(0.6, 0.8, 0.6) if wall_dir.y != 0 else Vector3(0.6, 0.8, 0.6)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.4, 0.4, 0.35)
	m.material = mat
	mi.mesh = m
	mi.position.y = 1.4
	add_child(mi)
	var lamp := MeshInstance3D.new()
	var lm := SphereMesh.new()
	lm.radius = 0.06
	lm.height = 0.12
	_lamp_mat.emission_enabled = true
	_lamp_mat.emission = Color(1, 0.1, 0.05)
	_lamp_mat.emission_energy_multiplier = 3.0
	lm.material = _lamp_mat
	lamp.mesh = lm
	lamp.position = Vector3(0, 1.9, 0)
	add_child(lamp)


func interact_point() -> Vector3:
	return global_position + Vector3(0, 1.4, 0)


func prompt(player) -> String:
	if inserted >= FUSES_NEEDED:
		return ""
	if player.fuses == 0:
		return "Fuse box (needs %d fuses)" % (FUSES_NEEDED - inserted)
	return "Insert fuse"


func interact(player) -> void:
	if player.fuses == 0 or inserted >= FUSES_NEEDED:
		return
	player.fuses -= 1
	inserted += 1
	Sfx.play_at("clank", global_position, -6.0, 1.6)
	if inserted >= FUSES_NEEDED:
		_lamp_mat.emission = Color(0.1, 1, 0.2)
		powered.emit()
	player.emit_signal("objective_changed")
