class_name Locker
extends StaticBody3D
## Hiding spot. The player steps inside and looks out through the slats.

var front_point: Vector3   ## where the player steps out / enemies stand
var inside_point: Vector3
var occupied := false
var _door: MeshInstance3D


func setup(pos: Vector3, front: Vector3) -> void:
	add_to_group("interactable")
	global_position = pos
	front_point = front
	var dir := (front - pos).normalized()
	look_at(pos - dir, Vector3.UP)  # local +Z faces the open cell
	inside_point = pos + dir * 0.1
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.32, 0.36, 0.38)
	mat.metallic = 0.6
	mat.roughness = 0.5
	# Back + sides as one body; door separate so it can swing.
	for part in [[Vector3(1.0, 2.2, 0.08), Vector3(0, 1.1, -0.45)], [Vector3(0.08, 2.2, 0.9), Vector3(-0.5, 1.1, 0)],
			[Vector3(0.08, 2.2, 0.9), Vector3(0.5, 1.1, 0)], [Vector3(1.0, 0.08, 0.9), Vector3(0, 2.2, 0)]]:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = part[0]
		bm.material = mat
		mi.mesh = bm
		mi.position = part[1]
		add_child(mi)
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = part[0]
		cs.shape = bs
		cs.position = part[1]
		add_child(cs)
	_door = MeshInstance3D.new()
	var dm := BoxMesh.new()
	dm.size = Vector3(0.95, 2.1, 0.05)
	dm.material = mat
	_door.mesh = dm
	_door.position = Vector3(0, 1.1, 0.45)
	add_child(_door)
	var dcs := CollisionShape3D.new()
	var dbs := BoxShape3D.new()
	dbs.size = dm.size
	dcs.shape = dbs
	dcs.position = _door.position
	add_child(dcs)


func interact_point() -> Vector3:
	return global_position + Vector3(0, 1.0, 0)


func prompt(_player) -> String:
	return "" if occupied else "Hide"


func interact(player) -> void:
	player.enter_locker(self)


## The HUD draws the slats while you're inside, so hide the real door from the camera.
func set_door_visible(v: bool) -> void:
	_door.visible = v


## Burst-open animation used when the Orderly rips the door.
func slam() -> void:
	var t := create_tween()
	t.tween_property(_door, "rotation:y", -1.9, 0.12)
	t.tween_interval(1.0)
	t.tween_property(_door, "rotation:y", 0.0, 0.6)
