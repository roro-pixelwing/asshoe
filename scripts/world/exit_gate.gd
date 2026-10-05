class_name ExitGate
extends StaticBody3D
## Barred security gate. Opens when the fuse box is powered.

var is_open := false
var _bars := Node3D.new()


func _ready() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.25, 0.25, 0.27)
	mat.metallic = 0.8
	add_child(_bars)
	for i in 9:
		var mi := MeshInstance3D.new()
		var m := CylinderMesh.new()
		m.top_radius = 0.04
		m.bottom_radius = 0.04
		m.height = 3.2
		m.material = mat
		mi.mesh = m
		mi.position = Vector3(-1.0 + i * 0.25, 1.6, 0)
		_bars.add_child(mi)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(2.5, 3.2, 0.2)
	cs.shape = bs
	cs.position = Vector3(0, 1.6, 0)
	add_child(cs)
	cs.name = "Shape"
	# Exit sign above the gate.
	var sign := Label3D.new()
	sign.text = "EXIT"
	sign.modulate = Color(1, 0.15, 0.1)
	sign.font_size = 64
	sign.position = Vector3(0, 2.9, 0.3)
	add_child(sign)


func open() -> void:
	is_open = true
	Sfx.play_at("clank", global_position, 4.0, 0.7)
	($Shape as CollisionShape3D).set_deferred("disabled", true)
	create_tween().tween_property(_bars, "position:y", 3.0, 2.5)
