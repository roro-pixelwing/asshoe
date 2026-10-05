class_name Patient
extends Node3D
## A thin, motionless patient. Harmless, but used for reveal scares.

func _ready() -> void:
	var skin := StandardMaterial3D.new()
	skin.albedo_color = Color(0.6, 0.58, 0.55)
	var gown := StandardMaterial3D.new()
	gown.albedo_color = Color(0.45, 0.5, 0.55)
	_box(Vector3(0.45, 1.0, 0.25), Vector3(0, 1.05, 0), gown)
	_box(Vector3(0.12, 0.6, 0.12), Vector3(-0.1, 0.3, 0), skin)
	_box(Vector3(0.12, 0.6, 0.12), Vector3(0.1, 0.3, 0), skin)
	_box(Vector3(0.1, 0.95, 0.1), Vector3(-0.3, 1.05, 0), skin)   # arms hang too low
	_box(Vector3(0.1, 0.95, 0.1), Vector3(0.3, 1.05, 0), skin)
	_box(Vector3(0.26, 0.32, 0.26), Vector3(0.05, 1.75, 0), skin).rotation.z = 0.35  # head tilted


func _box(size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	bm.material = mat
	mi.mesh = bm
	mi.position = pos
	add_child(mi)
	return mi
