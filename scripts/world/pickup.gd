class_name Pickup
extends Node3D
## Battery or fuse lying on the floor.

enum Kind { BATTERY, FUSE }
var kind := Kind.BATTERY


func _ready() -> void:
	add_to_group("interactable")
	var mi := MeshInstance3D.new()
	var mat := StandardMaterial3D.new()
	mat.emission_enabled = true
	if kind == Kind.BATTERY:
		var m := CylinderMesh.new()
		m.top_radius = 0.07
		m.bottom_radius = 0.07
		m.height = 0.22
		mi.mesh = m
		mat.albedo_color = Color(0.1, 0.5, 0.2)
		mat.emission = Color(0.1, 0.4, 0.15)
	else:
		var m := BoxMesh.new()
		m.size = Vector3(0.12, 0.3, 0.12)
		mi.mesh = m
		mat.albedo_color = Color(0.7, 0.5, 0.2)
		mat.emission = Color(0.5, 0.3, 0.05)
	mat.emission_energy_multiplier = 0.4
	mi.material_override = mat
	mi.position.y = 0.85
	add_child(mi)
	# A little table so it reads at a glance.
	var table := MeshInstance3D.new()
	var tm := BoxMesh.new()
	tm.size = Vector3(0.8, 0.75, 0.5)
	table.mesh = tm
	table.position.y = 0.375
	add_child(table)


func interact_point() -> Vector3:
	return global_position + Vector3(0, 0.9, 0)


func prompt(_player) -> String:
	return "Take battery" if kind == Kind.BATTERY else "Take fuse"


func interact(player) -> void:
	if kind == Kind.BATTERY:
		player.spare_batteries += 1
	else:
		player.fuses += 1
	Sfx.play("pickup")
	player.emit_signal("objective_changed")
	queue_free()
