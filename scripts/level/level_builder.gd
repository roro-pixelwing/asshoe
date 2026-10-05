class_name LevelBuilder
extends Node3D
## Builds walls, floor, lights and props from an ASCII grid (see LevelData),
## and provides grid pathfinding (AStarGrid2D) for the enemy AI.

const CELL := 2.5
const WALL_H := 3.2
const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

var grid: Array[String] = []
var astar := AStarGrid2D.new()
## char -> Array of Vector2i cells where it appears
var markers := {}
var lights: Array[FlickerLight] = []
var lockers: Array[Locker] = []
var exit_gate: ExitGate
var fuse_box: FuseBox


func build(map: Array[String]) -> void:
	grid = map
	var w := grid[0].length()
	var h := grid.size()
	astar.region = Rect2i(0, 0, w, h)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.update()

	var wall_mat := _material(_wall_texture(), 1.0)
	var floor_mat := _material(_floor_texture(), 1.0)
	var ceil_mat := _material(_noise_texture(Color(0.16, 0.16, 0.15), 0.12), 1.0)
	var walls := StaticBody3D.new()
	walls.name = "Walls"
	add_child(walls)
	var wall_mesh := BoxMesh.new()
	wall_mesh.size = Vector3(CELL, WALL_H, CELL)
	wall_mesh.material = wall_mat

	for y in h:
		for x in w:
			var c := grid[y][x]
			var cell := Vector2i(x, y)
			if c == "#":
				astar.set_point_solid(cell, true)
				var mi := MeshInstance3D.new()
				mi.mesh = wall_mesh
				mi.position = cell_to_world(cell) + Vector3(0, WALL_H / 2.0, 0)
				walls.add_child(mi)
				var cs := CollisionShape3D.new()
				var box := BoxShape3D.new()
				box.size = wall_mesh.size
				cs.shape = box
				cs.position = mi.position
				walls.add_child(cs)
			else:
				if not markers.has(c):
					markers[c] = []
				markers[c].append(cell)

	# Floor and ceiling slabs spanning the whole map.
	var size := Vector3(w * CELL, 0.2, h * CELL)
	var center := Vector3((w - 1) * CELL / 2.0, 0, (h - 1) * CELL / 2.0)
	_slab(center + Vector3(0, -0.1, 0), size, floor_mat, Vector2(w, h))
	_slab(center + Vector3(0, WALL_H + 0.1, 0), size, ceil_mat, Vector2(w, h) * 0.5)

	for cell in cells_of("*"):
		var l := FlickerLight.new()
		add_child(l)
		l.position = cell_to_world(cell) + Vector3(0, WALL_H - 0.15, 0)
		lights.append(l)
	for cell in cells_of("L"):
		var front := _open_neighbour(cell)
		astar.set_point_solid(cell, true)  # enemies walk to the front cell instead
		var lk := Locker.new()
		add_child(lk)
		lk.setup(cell_to_world(cell), cell_to_world(front))
		lockers.append(lk)
	for cell in cells_of("B"):
		var b := Pickup.new()
		b.kind = Pickup.Kind.BATTERY
		add_child(b)
		b.position = cell_to_world(cell)
	for cell in cells_of("F"):
		var f := Pickup.new()
		f.kind = Pickup.Kind.FUSE
		add_child(f)
		f.position = cell_to_world(cell)
	for cell in cells_of("G"):
		fuse_box = FuseBox.new()
		add_child(fuse_box)
		fuse_box.setup(cell_to_world(cell), _nearest_wall_dir(cell))
	for cell in cells_of("X"):
		exit_gate = ExitGate.new()
		add_child(exit_gate)
		exit_gate.position = cell_to_world(cell)


func cells_of(c: String) -> Array:
	return markers.get(c, [])


func patrol_points() -> Array[Vector3]:
	var pts: Array[Vector3] = []
	for d in ["1", "2", "3", "4", "5", "6", "7", "8", "9"]:
		for cell in cells_of(d):
			pts.append(cell_to_world(cell))
	return pts


func cell_to_world(cell: Vector2i) -> Vector3:
	return Vector3(cell.x * CELL, 0, cell.y * CELL)


func world_to_cell(p: Vector3) -> Vector2i:
	return Vector2i(roundi(p.x / CELL), roundi(p.z / CELL))


func is_walkable(cell: Vector2i) -> bool:
	return astar.is_in_boundsv(cell) and not astar.is_point_solid(cell)


## Nearest walkable cell to `cell` (itself if walkable).
func nearest_walkable(cell: Vector2i) -> Vector2i:
	if is_walkable(cell):
		return cell
	for r in range(1, 4):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var c := cell + Vector2i(dx, dy)
				if is_walkable(c):
					return c
	return cell


func find_path(from: Vector3, to: Vector3) -> PackedVector3Array:
	var a := nearest_walkable(world_to_cell(from))
	var b := nearest_walkable(world_to_cell(to))
	var out := PackedVector3Array()
	for id in astar.get_id_path(a, b):
		out.append(cell_to_world(id))
	if out.size() > 0:
		out[out.size() - 1] = Vector3(to.x, 0, to.z) if is_walkable(world_to_cell(to)) else out[out.size() - 1]
	return out


func random_walkable_near(p: Vector3, radius_cells: int) -> Vector3:
	var c := world_to_cell(p)
	for i in 20:
		var t := c + Vector2i(randi_range(-radius_cells, radius_cells), randi_range(-radius_cells, radius_cells))
		if is_walkable(t):
			return cell_to_world(t)
	return p


func lit_at(p: Vector3) -> bool:
	for l in lights:
		if l.is_on and Vector2(l.global_position.x - p.x, l.global_position.z - p.z).length() < 4.0:
			return true
	return false


func _open_neighbour(cell: Vector2i) -> Vector2i:
	for d in DIRS:
		var n := cell + d
		if grid[n.y][n.x] != "#":
			return n
	return cell


func _nearest_wall_dir(cell: Vector2i) -> Vector2i:
	for d in DIRS:
		var n := cell + d
		if grid[n.y][n.x] == "#":
			return d
	return Vector2i(0, -1)


func _slab(pos: Vector3, size: Vector3, mat: Material, uv: Vector2) -> void:
	var body := StaticBody3D.new()
	add_child(body)
	body.position = pos
	var mi := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = size
	mi.mesh = m
	var sm := mat.duplicate() as StandardMaterial3D
	sm.uv1_scale = Vector3(uv.x, uv.y, 1)
	mi.material_override = sm
	body.add_child(mi)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	body.add_child(cs)


# --- PS1-style procedural textures: tiny, nearest-filtered, dirty. ---

static func _material(tex: Texture2D, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.roughness = rough
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	return m


static func _noise_texture(base: Color, amount: float) -> ImageTexture:
	var img := Image.create(32, 32, false, Image.FORMAT_RGB8)
	for y in 32:
		for x in 32:
			img.set_pixel(x, y, base.darkened(randf() * amount))
	return ImageTexture.create_from_image(img)


static func _wall_texture() -> ImageTexture:
	# Institutional green paint over a darker wainscot, with grime streaks.
	var img := Image.create(32, 32, false, Image.FORMAT_RGB8)
	var streaks := []
	for i in 6:
		streaks.append(randi() % 32)
	for y in 32:
		for x in 32:
			var c := Color(0.42, 0.5, 0.42) if y < 20 else Color(0.25, 0.27, 0.24)
			if y == 20:
				c = Color(0.15, 0.15, 0.13)
			c = c.darkened(randf() * 0.15)
			if x in streaks and y > randi() % 12:
				c = c.darkened(0.3)
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


static func _floor_texture() -> ImageTexture:
	# Checkerboard linoleum, stained.
	var img := Image.create(32, 32, false, Image.FORMAT_RGB8)
	for y in 32:
		for x in 32:
			var light := ((x / 16) + (y / 16)) % 2 == 0
			var c := Color(0.55, 0.53, 0.47) if light else Color(0.2, 0.19, 0.18)
			img.set_pixel(x, y, c.darkened(randf() * 0.2))
	return ImageTexture.create_from_image(img)
