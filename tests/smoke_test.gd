extends Node
## Headless gameplay test. Run:
##   godot --headless res://tests/smoke_test.tscn
## Drives the real main scene and checks the core loops actually work.

var main
var failures := 0


func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _frames(5)
	main._start()
	var p: Player = main.player
	var o: Orderly = main.orderly
	var lv: LevelBuilder = main.level

	_check(lv.lockers.size() == 6, "6 lockers built (got %d)" % lv.lockers.size())
	_check(lv.patrol_points().size() == 4, "4 patrol points")
	_check(lv.find_path(p.global_position, lv.exit_gate.global_position).size() > 0, "exit reachable by pathfinding")

	# 1. Patrol: the Orderly moves on his own.
	var start := o.global_position
	await _frames(180)
	_check(o.global_position.distance_to(start) > 2.0, "Orderly patrols (moved %.1f m)" % o.global_position.distance_to(start))

	# 2. Hearing: a loud noise nearby makes him investigate.
	o.hear(o.global_position + Vector3(3, 0, 0), 16.0)
	_check(o.state == Orderly.State.INVESTIGATE, "noise -> INVESTIGATE")

	# 3. Sight: put the player in front of him, he chases.
	_place_in_front(p, o, 4.0)
	await _frames(10)
	_check(o.state == Orderly.State.CHASE, "seen -> CHASE (state %d)" % o.state)

	# 4. Contact damages the player.
	var hp := p.health
	await _frames(240)
	_check(p.health < hp, "chase ends in a hit (health %d -> %d)" % [hp, p.health])

	# 5. Hiding while seen: he rips the locker open.
	p.health = 3
	p.dead = false
	var lk: Locker = lv.lockers[0]
	o.global_position = lk.front_point + (lk.front_point - lk.global_position).normalized() * 3.0
	o._set_state(Orderly.State.CHASE)
	o._unseen = 0.0
	p.enter_locker(lk)
	await _frames(240)
	_check(p.hidden_in == null and p.health < 3, "seen hiding -> dragged out (health %d)" % p.health)

	# 6. Hiding unseen with held breath: he searches and gives up.
	p.health = 3
	o.global_position = lv.patrol_points()[2]
	o._set_state(Orderly.State.PATROL)
	await _frames(5)
	p.enter_locker(lv.lockers[5])
	p.breath = 1.0
	_check(not o.can_see_player(), "hidden player is invisible")

	# 7. Objective chain: fuses -> fuse box -> gate -> win.
	p.exit_locker()
	p.dead = false        # step 5 may have killed her; resurrect for the remaining checks
	p.health = 3
	main.phase = main.Phase.PLAYING
	o.global_position = Vector3(-50, 0, -50)    # out of the way
	o.set_physics_process(false)
	for n in get_tree().get_nodes_in_group("interactable"):
		if n is Pickup and n.kind == Pickup.Kind.FUSE:
			n.interact(p)
	await _frames(2)
	_check(p.fuses == 2, "picked up 2 fuses")
	lv.fuse_box.interact(p)
	lv.fuse_box.interact(p)
	await _frames(2)
	_check(lv.exit_gate.is_open, "gate opens after 2 fuses")
	p.global_position = lv.exit_gate.global_position + Vector3(0, 0, 0.2)
	await _frames(3)
	_check(main.phase == main.Phase.WON, "reaching the gate wins")

	# 8. Night vision drains the battery.
	p.dead = false
	p.camcorder_up = true
	p._set_night_vision(true)
	var b := p.battery
	await _frames(120)
	_check(p.battery < b, "night vision drains battery")

	print("\n%s: %d failure(s)" % ["PASS" if failures == 0 else "FAIL", failures])
	get_tree().quit(1 if failures > 0 else 0)


func _place_in_front(p: Player, o: Orderly, dist: float) -> void:
	var fwd := -o.global_basis.z
	var lv: LevelBuilder = main.level
	for i in 16:
		var a := i * TAU / 16.0
		var dir := fwd.rotated(Vector3.UP, a * (1 if i % 2 else -1) * 0.5)
		var pos := o.global_position + dir * dist
		if lv.is_walkable(lv.world_to_cell(pos)):
			p.global_position = pos
			var q := PhysicsRayQueryParameters3D.create(o.global_position + Vector3.UP * 1.9, pos + Vector3.UP * 1.6, 1)
			if o.get_world_3d().direct_space_state.intersect_ray(q).is_empty():
				o.look_at(Vector3(pos.x, o.global_position.y, pos.z), Vector3.UP)
				return


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		failures += 1
