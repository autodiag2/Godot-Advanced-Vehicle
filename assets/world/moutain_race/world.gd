extends World

const TRACK_POINTS := [
	Vector3(0, 0, 75),
	Vector3(38, 8, 58),
	Vector3(68, 15, 28),
	Vector3(78, 22, -12),
	Vector3(58, 30, -48),
	Vector3(22, 24, -72),
	Vector3(-18, 18, -68),
	Vector3(-52, 12, -48),
	Vector3(-76, 8, -16),
	Vector3(-68, 5, 22),
	Vector3(-42, 2, 55)
]

const RIVER_POINTS := [
	Vector3(0, 0, -48),
	Vector3(-4, 0, -40),
	Vector3(-8, 0, -32),
	Vector3(-7, 0, -25),
	Vector3(-2, 0, -18),
	Vector3(1, 0, -13)
]

const TRACK_WIDTH := 12.0
const SHOULDER_WIDTH := 4.0
const TRACK_SAMPLES := 440
const TRACK_SPATIAL_CELL_SIZE := 16.0
const MULTIMESH_CELL_SIZE := 48.0
const MULTIMESH_BATCH_MARGIN := 8.0
const TERRAIN_SIZE := 300.0
const TERRAIN_RESOLUTION := 151
const TRACK_SURFACE_OFFSET := 0.45

const GUARDRAIL_HEIGHT := 1.25
const GUARDRAIL_OFFSET := 0.65
const GUARDRAIL_STEP := 4

const SPAWN_HEIGHT_OFFSET := 2.0

const LAKE_RADIUS := 16.0
const LAKE_SHORE_WIDTH := 4.5
const LAKE_WATER_LEVEL := -3.0
const LAKE_DEPTH := 1.5

const RIVER_SAMPLES := 180
const RIVER_WIDTH := 4.8
const RIVER_BANK_WIDTH := 8.0
const RIVER_CARVE_DEPTH := 2.8

const TREE_COUNT := 180
const ROADSIDE_TREE_STEP := 5
const ROADSIDE_TREE_ROWS := 2
const ROCK_COUNT := 100
const GRASS_COUNT := 3000

var rng := RandomNumberGenerator.new()
var track_centers: Array[Vector3] = []
var track_tangents: Array[Vector3] = []
var track_sides: Array[Vector3] = []
var river_centers: Array[Vector3] = []
var track_spatial_bins: Dictionary = {}
var tree_trunk_batches: Dictionary = {}
var tree_crown_batches: Dictionary = {}
var rock_batches: Dictionary = {}

var track_mesh_instance: MeshInstance3D
var terrain_mesh_instance: MeshInstance3D

var track_material: StandardMaterial3D
var shoulder_material: StandardMaterial3D
var terrain_material: StandardMaterial3D
var rock_material: StandardMaterial3D
var tree_material: StandardMaterial3D
var tree_trunk_material: StandardMaterial3D
var guardrail_material: StandardMaterial3D
var grass_material: StandardMaterial3D
var marking_material: StandardMaterial3D
var shoreline_material: StandardMaterial3D
var water_material: StandardMaterial3D


func _init() -> void:
	level_name = "Mountain Race"
	preview = preload("res://assets/world/moutain_race/preview.png")


func _ready() -> void:
	rng.seed = 41027

	_create_materials()
	_build_track_samples()
	_build_track_spatial_bins()
	_build_terrain()
	_build_lake_and_river()
	_build_track()
	_build_shoulders()
	_build_guardrails()
	_build_spawn_marker()
	_build_scenery()
	_build_grass()
	_build_trackside_details()
	_build_environment()


func _create_materials() -> void:
	track_material = _material(Color(0.105, 0.115, 0.12), 0.9)
	shoulder_material = _material(Color(0.48, 0.43, 0.32), 1.0)
	terrain_material = _material(Color(0.19, 0.29, 0.16), 1.0)
	rock_material = _material(Color(0.32, 0.33, 0.31), 1.0)
	tree_material = _material(Color(0.07, 0.20, 0.09), 1.0)
	tree_trunk_material = _material(Color(0.25, 0.16, 0.09), 1.0)
	guardrail_material = _material(Color(0.72, 0.74, 0.75), 0.45)
	grass_material = _material(Color(0.22, 0.34, 0.13), 1.0)
	marking_material = _material(Color(0.88, 0.84, 0.66), 0.8)
	shoreline_material = _material(Color(0.48, 0.43, 0.31), 1.0)

	track_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	shoulder_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	terrain_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	marking_material.cull_mode = BaseMaterial3D.CULL_DISABLED

	water_material = StandardMaterial3D.new()
	water_material.albedo_color = Color(0.04, 0.25, 0.39, 0.88)
	water_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water_material.roughness = 0.2
	water_material.metallic = 0.1
	water_material.cull_mode = BaseMaterial3D.CULL_DISABLED


func _material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material


func _build_track_samples() -> void:
	track_centers.clear()
	track_tangents.clear()
	track_sides.clear()

	var count := TRACK_POINTS.size()

	for i in range(TRACK_SAMPLES):
		var t := float(i) / float(TRACK_SAMPLES) * count
		var segment := int(floor(t)) % count
		var u: float = t - floor(t)

		var p0: Vector3 = TRACK_POINTS[(segment - 1 + count) % count]
		var p1: Vector3 = TRACK_POINTS[segment]
		var p2: Vector3 = TRACK_POINTS[(segment + 1) % count]
		var p3: Vector3 = TRACK_POINTS[(segment + 2) % count]

		track_centers.append(_catmull_rom(p0, p1, p2, p3, u))

	for i in range(TRACK_SAMPLES):
		var previous: Vector3 = track_centers[(i - 1 + TRACK_SAMPLES) % TRACK_SAMPLES]
		var following: Vector3 = track_centers[(i + 1) % TRACK_SAMPLES]

		var tangent := (following - previous).normalized()
		var side := Vector3.UP.cross(tangent).normalized()

		if side.length_squared() < 0.001:
			side = Vector3.RIGHT

		track_tangents.append(tangent)
		track_sides.append(side)


func _build_track_spatial_bins() -> void:
	track_spatial_bins.clear()

	for index in range(track_centers.size()):
		var center: Vector3 = track_centers[index]
		var cell := Vector2i(
			floori(center.x / TRACK_SPATIAL_CELL_SIZE),
			floori(center.z / TRACK_SPATIAL_CELL_SIZE)
		)
		var bucket: Array = track_spatial_bins.get(cell, [])
		bucket.append(index)
		track_spatial_bins[cell] = bucket


func _nearest_track_sample(x: float, z: float) -> Vector2:
	var nearest_distance_squared := 1.0e9
	var nearest_height := 0.0
	var cell := Vector2i(
		floori(x / TRACK_SPATIAL_CELL_SIZE),
		floori(z / TRACK_SPATIAL_CELL_SIZE)
	)

	for cell_z in range(-1, 2):
		for cell_x in range(-1, 2):
			var bucket: Array = track_spatial_bins.get(
				cell + Vector2i(cell_x, cell_z),
				[]
			)
			for sample_value in bucket:
				var sample_index: int = sample_value
				var center: Vector3 = track_centers[sample_index]
				var dx := x - center.x
				var dz := z - center.z
				var distance_squared := dx * dx + dz * dz
				if distance_squared < nearest_distance_squared:
					nearest_distance_squared = distance_squared
					nearest_height = center.y

	return Vector2(nearest_distance_squared, nearest_height)


func _catmull_rom(
	p0: Vector3,
	p1: Vector3,
	p2: Vector3,
	p3: Vector3,
	t: float
) -> Vector3:
	var t2 := t * t
	var t3 := t2 * t

	return 0.5 * (
		(2.0 * p1)
		+ (-p0 + p2) * t
		+ (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2
		+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3
	)


func _sample_open_path(points: Array, sample_count: int) -> Array[Vector3]:
	var result: Array[Vector3] = []

	if points.size() < 2:
		return result

	var segment_count := points.size() - 1

	for i in range(sample_count):
		var t := float(i) / float(sample_count - 1) * segment_count
		var segment := mini(int(floor(t)), segment_count - 1)
		var u: float = t - float(segment)

		var p0: Vector3 = points[maxi(segment - 1, 0)]
		var p1: Vector3 = points[segment]
		var p2: Vector3 = points[segment + 1]
		var p3: Vector3 = points[mini(segment + 2, points.size() - 1)]

		result.append(_catmull_rom(p0, p1, p2, p3, u))

	return result


func _terrain_height(x: float, z: float) -> float:
	var h := -2.0

	h += 15.0 * exp(-((x - 95.0) * (x - 95.0) + (z + 35.0) * (z + 35.0)) / 2500.0)
	h += 24.0 * exp(-((x + 95.0) * (x + 95.0) + (z - 5.0) * (z - 5.0)) / 3100.0)
	h += 31.0 * exp(-((x - 10.0) * (x - 10.0) + (z + 120.0) * (z + 120.0)) / 1800.0)
	h += 20.0 * exp(-((x + 35.0) * (x + 35.0) + (z - 115.0) * (z - 115.0)) / 2400.0)
	h += 2.0 * sin(x * 0.055) * cos(z * 0.041)

	var river_distance := _distance_to_river(x, z)

	if river_distance < RIVER_BANK_WIDTH:
		var river_factor := 1.0 - river_distance / RIVER_BANK_WIDTH
		h -= RIVER_CARVE_DEPTH * river_factor * river_factor

	var lake_distance := Vector2(x, z).length()
	var lake_floor := LAKE_WATER_LEVEL - LAKE_DEPTH

	if lake_distance < LAKE_RADIUS:
		h = minf(h, lake_floor)
	elif lake_distance < LAKE_RADIUS + LAKE_SHORE_WIDTH:
		var shore_t := (lake_distance - LAKE_RADIUS) / LAKE_SHORE_WIDTH
		shore_t = clampf(shore_t, 0.0, 1.0)
		shore_t = shore_t * shore_t * (3.0 - 2.0 * shore_t)
		h = lerpf(lake_floor, h, shore_t)

	var nearest_track := _nearest_track_sample(x, z)
	var nearest_distance_squared := nearest_track.x
	var nearest_height := nearest_track.y
	var track_blend_radius := TRACK_WIDTH * 0.5 + SHOULDER_WIDTH + 1.5

	if nearest_distance_squared < track_blend_radius * track_blend_radius:
		var nearest_distance := sqrt(nearest_distance_squared)
		var blend := clampf(
			(nearest_distance - TRACK_WIDTH * 0.5) / (SHOULDER_WIDTH + 1.5),
			0.0,
			1.0
		)
		var target := nearest_height + TRACK_SURFACE_OFFSET - 0.3
		h = lerpf(target, h, blend)

	return h


func _distance_to_river(x: float, z: float) -> float:
	var point := Vector2(x, z)
	var best := 1.0e9

	for i in range(RIVER_POINTS.size() - 1):
		var a3: Vector3 = RIVER_POINTS[i]
		var b3: Vector3 = RIVER_POINTS[i + 1]
		var a := Vector2(a3.x, a3.z)
		var b := Vector2(b3.x, b3.z)
		var segment := b - a
		var length_squared := segment.length_squared()

		if length_squared < 0.001:
			continue

		var t := clampf((point - a).dot(segment) / length_squared, 0.0, 1.0)
		var nearest := a + segment * t
		best = minf(best, point.distance_to(nearest))

	return best


func _add_triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	st.set_uv(Vector2(a.x * 0.04, a.z * 0.04))
	st.add_vertex(a)
	st.set_uv(Vector2(b.x * 0.04, b.z * 0.04))
	st.add_vertex(b)
	st.set_uv(Vector2(c.x * 0.04, c.z * 0.04))
	st.add_vertex(c)


func _build_terrain() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var half := TERRAIN_SIZE * 0.5
	var step := TERRAIN_SIZE / float(TERRAIN_RESOLUTION - 1)
	var terrain_heights := PackedFloat32Array()
	terrain_heights.resize(TERRAIN_RESOLUTION * TERRAIN_RESOLUTION)

	for z_index in range(TERRAIN_RESOLUTION):
		for x_index in range(TERRAIN_RESOLUTION):
			var x := -half + x_index * step
			var z := -half + z_index * step
			terrain_heights[z_index * TERRAIN_RESOLUTION + x_index] = _terrain_height(x, z)

	for z_index in range(TERRAIN_RESOLUTION - 1):
		for x_index in range(TERRAIN_RESOLUTION - 1):
			var x0 := -half + x_index * step
			var z0 := -half + z_index * step
			var x1 := x0 + step
			var z1 := z0 + step
			var row := z_index * TERRAIN_RESOLUTION
			var next_row := row + TERRAIN_RESOLUTION

			var a := Vector3(x0, terrain_heights[row + x_index], z0)
			var b := Vector3(x1, terrain_heights[row + x_index + 1], z0)
			var c := Vector3(x0, terrain_heights[next_row + x_index], z1)
			var d := Vector3(x1, terrain_heights[next_row + x_index + 1], z1)

			_add_triangle(st, a, c, b)
			_add_triangle(st, b, c, d)

	st.generate_normals()

	var mesh := st.commit()

	terrain_mesh_instance = MeshInstance3D.new()
	terrain_mesh_instance.name = "MountainTerrain"
	terrain_mesh_instance.mesh = mesh
	terrain_mesh_instance.material_override = terrain_material
	add_child(terrain_mesh_instance)

	var body := StaticBody3D.new()
	body.name = "TerrainCollision"
	body.add_to_group("colliding")
	body.collision_layer = 1
	body.collision_mask = 1
	terrain_mesh_instance.add_child(body)

	var collision := CollisionShape3D.new()
	collision.name = "TerrainShape"
	collision.shape = mesh.create_trimesh_shape()
	body.add_child(collision)


func _build_lake_and_river() -> void:
	river_centers = _sample_open_path(RIVER_POINTS, RIVER_SAMPLES)

	var lake_mesh := CylinderMesh.new()
	lake_mesh.top_radius = LAKE_RADIUS
	lake_mesh.bottom_radius = LAKE_RADIUS
	lake_mesh.height = 0.04
	lake_mesh.radial_segments = 96

	var lake := MeshInstance3D.new()
	lake.name = "CentralLake"
	lake.mesh = lake_mesh
	lake.material_override = water_material
	lake.position = Vector3(0.0, LAKE_WATER_LEVEL - 0.02, 0.0)
	add_child(lake)

	var shore_st := SurfaceTool.new()
	shore_st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var shore_segments := 96
	var inner_radius := LAKE_RADIUS
	var outer_radius := LAKE_RADIUS + LAKE_SHORE_WIDTH

	for i in range(shore_segments):
		var a0 := TAU * float(i) / shore_segments
		var a1 := TAU * float(i + 1) / shore_segments

		var inner0 := Vector3(
			cos(a0) * inner_radius,
			LAKE_WATER_LEVEL + 0.01,
			sin(a0) * inner_radius
		)
		var inner1 := Vector3(
			cos(a1) * inner_radius,
			LAKE_WATER_LEVEL + 0.01,
			sin(a1) * inner_radius
		)

		var outer0 := Vector3(
			cos(a0) * outer_radius,
			_terrain_height(cos(a0) * outer_radius, sin(a0) * outer_radius) + 0.04,
			sin(a0) * outer_radius
		)
		var outer1 := Vector3(
			cos(a1) * outer_radius,
			_terrain_height(cos(a1) * outer_radius, sin(a1) * outer_radius) + 0.04,
			sin(a1) * outer_radius
		)

		_add_triangle(shore_st, inner0, inner1, outer0)
		_add_triangle(shore_st, inner1, outer1, outer0)

	shore_st.generate_normals()

	var shore := MeshInstance3D.new()
	shore.name = "LakeShore"
	shore.mesh = shore_st.commit()
	shore.material_override = shoreline_material
	shoreline_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	add_child(shore)

	var river_st := SurfaceTool.new()
	river_st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for i in range(river_centers.size() - 1):
		var c0: Vector3 = river_centers[i]
		var c1: Vector3 = river_centers[i + 1]

		c0.y = LAKE_WATER_LEVEL + 0.015
		c1.y = LAKE_WATER_LEVEL + 0.015

		var tangent := (c1 - c0).normalized()
		var side := Vector3.UP.cross(tangent).normalized()

		if side.length_squared() < 0.001:
			side = Vector3.RIGHT

		var s0 := side * RIVER_WIDTH * 0.5
		var s1 := side * RIVER_WIDTH * 0.5

		_add_triangle(river_st, c0 - s0, c1 - s1, c0 + s0)
		_add_triangle(river_st, c1 - s1, c1 + s1, c0 + s0)

	river_st.generate_normals()

	var river := MeshInstance3D.new()
	river.name = "MountainRiver"
	river.mesh = river_st.commit()
	river.material_override = water_material
	add_child(river)


func _build_track() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for i in range(TRACK_SAMPLES):
		var next := (i + 1) % TRACK_SAMPLES

		var c0: Vector3 = track_centers[i] + Vector3.UP * TRACK_SURFACE_OFFSET
		var c1: Vector3 = track_centers[next] + Vector3.UP * TRACK_SURFACE_OFFSET
		var s0: Vector3 = track_sides[i] * TRACK_WIDTH * 0.5
		var s1: Vector3 = track_sides[next] * TRACK_WIDTH * 0.5

		_add_triangle(st, c0 - s0, c1 - s1, c0 + s0)
		_add_triangle(st, c1 - s1, c1 + s1, c0 + s0)

	st.generate_normals()

	var mesh := st.commit()
	track_mesh_instance = MeshInstance3D.new()
	track_mesh_instance.name = "RaceTrack"
	track_mesh_instance.mesh = mesh
	track_mesh_instance.material_override = track_material
	add_child(track_mesh_instance)

	var body := StaticBody3D.new()
	body.name = "TrackCollision"
	body.add_to_group("colliding")
	body.collision_layer = 1
	body.collision_mask = 1
	track_mesh_instance.add_child(body)

	var collision := CollisionShape3D.new()
	collision.name = "TrackSurfaceShape"

	var shape := mesh.create_trimesh_shape() as ConcavePolygonShape3D
	shape.backface_collision = true
	collision.shape = shape

	body.add_child(collision)

	_add_track_markings()


func _build_shoulders() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for i in range(TRACK_SAMPLES):
		var next := (i + 1) % TRACK_SAMPLES

		for sign_value in [-1.0, 1.0]:
			var inner0: Vector3 = (
				track_centers[i]
				+ track_sides[i] * TRACK_WIDTH * 0.5 * sign_value
				+ Vector3.UP * 0.25
			)
			var inner1: Vector3 = (
				track_centers[next]
				+ track_sides[next] * TRACK_WIDTH * 0.5 * sign_value
				+ Vector3.UP * 0.25
			)
			var outer0: Vector3 = (
				track_centers[i]
				+ track_sides[i] * (TRACK_WIDTH * 0.5 + SHOULDER_WIDTH) * sign_value
			)
			var outer1: Vector3 = (
				track_centers[next]
				+ track_sides[next] * (TRACK_WIDTH * 0.5 + SHOULDER_WIDTH) * sign_value
			)

			if sign_value > 0.0:
				_add_triangle(st, inner0, inner1, outer0)
				_add_triangle(st, inner1, outer1, outer0)
			else:
				_add_triangle(st, inner0, outer0, inner1)
				_add_triangle(st, inner1, outer0, outer1)

	st.generate_normals()

	var mesh := st.commit()

	var shoulders := MeshInstance3D.new()
	shoulders.name = "GravelShoulders"
	shoulders.mesh = mesh
	shoulders.material_override = shoulder_material
	add_child(shoulders)


func _add_track_markings() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for i in range(0, TRACK_SAMPLES, 3):
		var next := (i + 1) % TRACK_SAMPLES

		var c0: Vector3 = track_centers[i] + Vector3.UP * (TRACK_SURFACE_OFFSET + 0.025)
		var c1: Vector3 = track_centers[next] + Vector3.UP * (TRACK_SURFACE_OFFSET + 0.025)

		for side_offset in [-TRACK_WIDTH * 0.5 + 0.25, TRACK_WIDTH * 0.5 - 0.25]:
			var p0: Vector3 = c0 + track_sides[i] * side_offset
			var p1: Vector3 = c1 + track_sides[next] * side_offset
			var w := 0.12

			_add_triangle(
				st,
				p0 - track_sides[i] * w,
				p1 - track_sides[next] * w,
				p0 + track_sides[i] * w
			)
			_add_triangle(
				st,
				p1 - track_sides[next] * w,
				p1 + track_sides[next] * w,
				p0 + track_sides[i] * w
			)

	st.generate_normals()

	var markings := MeshInstance3D.new()
	markings.name = "TrackEdgeLines"
	markings.mesh = st.commit()
	markings.material_override = marking_material
	add_child(markings)

	var center_st := SurfaceTool.new()
	center_st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for i in range(0, TRACK_SAMPLES, 8):
		var next := (i + 3) % TRACK_SAMPLES

		var p0: Vector3 = track_centers[i] + Vector3.UP * (TRACK_SURFACE_OFFSET + 0.03)
		var p1: Vector3 = track_centers[next] + Vector3.UP * (TRACK_SURFACE_OFFSET + 0.03)
		var side0 := track_sides[i] * 0.08
		var side1 := track_sides[next] * 0.08

		_add_triangle(center_st, p0 - side0, p1 - side1, p0 + side0)
		_add_triangle(center_st, p1 - side1, p1 + side1, p0 + side0)

	center_st.generate_normals()

	var centerline := MeshInstance3D.new()
	centerline.name = "DashedCenterLine"
	centerline.mesh = center_st.commit()
	centerline.material_override = _material(Color(0.9, 0.78, 0.22), 0.8)
	add_child(centerline)


func _basis_from_forward(forward: Vector3) -> Basis:
	var direction := forward.normalized()
	var right := direction.cross(Vector3.UP).normalized()

	if right.length_squared() < 0.001:
		right = Vector3.RIGHT

	var up := right.cross(direction).normalized()
	return Basis(right, up, -direction)



func _build_guardrails() -> void:
	var post_mesh := CylinderMesh.new()
	post_mesh.top_radius = 0.10
	post_mesh.bottom_radius = 0.13
	post_mesh.height = GUARDRAIL_HEIGHT

	var upper_mesh := BoxMesh.new()
	upper_mesh.size = Vector3(0.18, 0.22, 1.0)
	var lower_mesh := BoxMesh.new()
	lower_mesh.size = Vector3(0.14, 0.16, 1.0)

	var post_batches: Dictionary = {}
	var upper_batches: Dictionary = {}
	var lower_batches: Dictionary = {}

	for i in range(0, TRACK_SAMPLES, GUARDRAIL_STEP):
		var next := (i + GUARDRAIL_STEP) % TRACK_SAMPLES

		for side_sign in [-1.0, 1.0]:
			var start: Vector3 = (
				track_centers[i]
				+ track_sides[i] * (TRACK_WIDTH * 0.5 + GUARDRAIL_OFFSET) * side_sign
				+ Vector3.UP * TRACK_SURFACE_OFFSET
			)
			var finish: Vector3 = (
				track_centers[next]
				+ track_sides[next] * (TRACK_WIDTH * 0.5 + GUARDRAIL_OFFSET) * side_sign
				+ Vector3.UP * TRACK_SURFACE_OFFSET
			)

			var direction := finish - start
			var length := direction.length()
			var basis := _basis_from_forward(direction)
			var midpoint := (start + finish) * 0.5

			for z_offset in [-length * 0.5 + 0.1, length * 0.5 - 0.1]:
				var local_position := Vector3(
					0.0,
					GUARDRAIL_HEIGHT * 0.5,
					z_offset
				)
				_append_multimesh_transform(
					post_batches,
					midpoint,
					Transform3D(
						basis,
						midpoint + basis * local_position
					)
				)

			_append_multimesh_transform(
				upper_batches,
				midpoint,
				Transform3D(
					basis.scaled_local(Vector3(1.0, 1.0, length + 0.3)),
					midpoint + basis * Vector3(0.0, GUARDRAIL_HEIGHT - 0.15, 0.0)
				)
			)
			_append_multimesh_transform(
				lower_batches,
				midpoint,
				Transform3D(
					basis.scaled_local(Vector3(1.0, 1.0, length + 0.3)),
					midpoint + basis * Vector3(0.0, GUARDRAIL_HEIGHT * 0.45, 0.0)
				)
			)

			var segment_root := Node3D.new()
			segment_root.name = "GuardrailSegment"
			segment_root.position = midpoint
			segment_root.basis = basis
			add_child(segment_root)

			var body := StaticBody3D.new()
			body.name = "GuardrailCollision"
			body.add_to_group("colliding")
			body.collision_layer = 1
			body.collision_mask = 1
			body.position = Vector3.ZERO
			segment_root.add_child(body)

			var collision := CollisionShape3D.new()
			var box_shape := BoxShape3D.new()
			box_shape.size = Vector3(0.55, GUARDRAIL_HEIGHT, length + 0.35)
			collision.shape = box_shape
			collision.position = Vector3(0.0, GUARDRAIL_HEIGHT * 0.5, 0.0)
			body.add_child(collision)

	_create_chunked_multimesh_instances("GuardrailPosts", post_mesh, guardrail_material, post_batches)
	_create_chunked_multimesh_instances("UpperGuardrails", upper_mesh, guardrail_material, upper_batches)
	_create_chunked_multimesh_instances("LowerGuardrails", lower_mesh, guardrail_material, lower_batches)


func _append_multimesh_transform(
	batches: Dictionary,
	position: Vector3,
	transform: Transform3D
) -> void:
	var cell := Vector2i(
		floori(position.x / MULTIMESH_CELL_SIZE),
		floori(position.z / MULTIMESH_CELL_SIZE)
	)
	var transforms: Array = batches.get(cell, [])
	transforms.append(transform)
	batches[cell] = transforms


func _create_chunked_multimesh_instances(
	node_name: String,
	mesh: Mesh,
	material: Material,
	batches: Dictionary
) -> void:
	for cell_value in batches:
		var cell: Vector2i = cell_value
		var transforms: Array = batches[cell]
		var margin := MULTIMESH_BATCH_MARGIN
		var extent := MULTIMESH_CELL_SIZE + margin * 2.0
		var bounds := AABB(
			Vector3(
				float(cell.x) * MULTIMESH_CELL_SIZE - margin,
				-20.0,
				float(cell.y) * MULTIMESH_CELL_SIZE - margin
			),
			Vector3(extent, 100.0, extent)
		)
		_create_multimesh_instance(
			"%s_%d_%d" % [node_name, cell.x, cell.y],
			mesh,
			material,
			transforms,
			bounds
		)


func _create_multimesh_instance(
	node_name: String,
	mesh: Mesh,
	material: Material,
	transforms: Array,
	custom_aabb: AABB
) -> void:
	if transforms.is_empty():
		return

	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	multimesh.custom_aabb = custom_aabb

	for i in range(transforms.size()):
		var instance_transform: Transform3D = transforms[i]
		multimesh.set_instance_transform(i, instance_transform)

	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = multimesh
	instance.material_override = material
	add_child(instance)


func _build_spawn_marker() -> void:
	var road_center: Vector3 = track_centers[0]
	var road_surface_y := road_center.y + TRACK_SURFACE_OFFSET
	var heading := atan2(-track_tangents[0].x, -track_tangents[0].z)

	var marker := Marker3D.new()
	marker.name = "VehicleSpawn"
	marker.position = Vector3(
		road_center.x,
		road_surface_y + SPAWN_HEIGHT_OFFSET,
		road_center.z
	)
	marker.rotation.y = heading
	add_child(marker)

	var start_line := Node3D.new()
	start_line.name = "StartFinishLine"
	start_line.position = Vector3(
		road_center.x,
		road_surface_y + 0.025,
		road_center.z
	)
	start_line.rotation.y = heading
	add_child(start_line)

	var tile_count := 12
	var tile_width := TRACK_WIDTH / float(tile_count)

	for i in range(tile_count):
		var tile_mesh := BoxMesh.new()
		tile_mesh.size = Vector3(tile_width, 0.04, 0.8)

		var checker := MeshInstance3D.new()
		checker.name = "StartLineTile"
		checker.mesh = tile_mesh
		checker.material_override = _material(
			Color.WHITE if i % 2 == 0 else Color.BLACK,
			0.8
		)
		checker.position = Vector3(
			(float(i) - float(tile_count - 1) * 0.5) * tile_width,
			0.0,
			0.0
		)
		start_line.add_child(checker)

	var arch := Node3D.new()
	arch.name = "StartFinishArch"
	arch.position = Vector3(
		road_center.x,
		road_surface_y,
		road_center.z
	)
	arch.rotation.y = heading
	add_child(arch)

	_add_box(
		arch,
		"StartBeam",
		Vector3(0.0, 3.8, 0.0),
		Vector3(TRACK_WIDTH + 1.0, 0.5, 0.5),
		_material(Color(0.82, 0.08, 0.045), 0.6),
		false
	)
	_add_box(
		arch,
		"StartPostLeft",
		Vector3(-TRACK_WIDTH * 0.5, 1.9, 0.0),
		Vector3(0.5, 3.8, 0.5),
		guardrail_material,
		false
	)
	_add_box(
		arch,
		"StartPostRight",
		Vector3(TRACK_WIDTH * 0.5, 1.9, 0.0),
		Vector3(0.5, 3.8, 0.5),
		guardrail_material,
		false
	)


func _add_tree_at(x: float, z: float) -> void:
	var y := _terrain_height(x, z)
	var trunk_height := rng.randf_range(3.5, 6.0)
	_append_multimesh_transform(
		tree_trunk_batches,
		Vector3(x, y, z),
		Transform3D(
			Basis().scaled(Vector3(1.0, trunk_height, 1.0)),
			Vector3(x, y + trunk_height * 0.5, z)
		)
	)

	var crown_size := Vector3(
		rng.randf_range(3.5, 6.0),
		rng.randf_range(7.0, 12.0),
		rng.randf_range(3.5, 6.0)
	)
	_append_multimesh_transform(
		tree_crown_batches,
		Vector3(x, y, z),
		Transform3D(
			Basis().scaled(crown_size),
			Vector3(x, y + trunk_height + crown_size.y * 0.35, z)
		)
	)

func _build_scenery() -> void:
	for i in range(0, TRACK_SAMPLES, ROADSIDE_TREE_STEP):
		var center: Vector3 = track_centers[i]
		var side: Vector3 = track_sides[i]

		for side_sign in [-1.0, 1.0]:
			for row in range(ROADSIDE_TREE_ROWS):
				var distance := (
					TRACK_WIDTH * 0.5
					+ SHOULDER_WIDTH
					+ 1.8
					+ float(row) * 7.0
					+ rng.randf_range(-1.5, 1.5)
				)

				var position: Vector3 = center + side * distance * side_sign

				if _distance_to_track(position.x, position.z) < TRACK_WIDTH * 0.5 + 1.0:
					continue

				if Vector2(position.x, position.z).length() < LAKE_RADIUS + LAKE_SHORE_WIDTH + 2.0:
					continue

				if _distance_to_river(position.x, position.z) < RIVER_WIDTH:
					continue

				_add_tree_at(position.x, position.z)

	for i in range(TREE_COUNT):
		var x := rng.randf_range(-140.0, 140.0)
		var z := rng.randf_range(-140.0, 140.0)

		if _distance_to_track(x, z) < TRACK_WIDTH * 0.5 + SHOULDER_WIDTH + 3.0:
			continue

		if Vector2(x, z).length() < LAKE_RADIUS + LAKE_SHORE_WIDTH + 2.0:
			continue

		if _distance_to_river(x, z) < RIVER_WIDTH + 2.0:
			continue

		_add_tree_at(x, z)

	for i in range(ROCK_COUNT):
		var x := rng.randf_range(-145.0, 145.0)
		var z := rng.randf_range(-145.0, 145.0)

		if _distance_to_track(x, z) < TRACK_WIDTH * 0.5 + SHOULDER_WIDTH + 2.0:
			continue

		if Vector2(x, z).length() < LAKE_RADIUS + LAKE_SHORE_WIDTH + 2.0:
			continue

		if _distance_to_river(x, z) < RIVER_WIDTH + 1.5:
			continue


		var radius := rng.randf_range(0.5, 2.2)
		var height := radius * rng.randf_range(0.7, 1.6)
		var y := _terrain_height(x, z)
		var rock_scale := Vector3(
			rng.randf_range(0.7, 1.8),
			rng.randf_range(0.5, 1.3),
			rng.randf_range(0.7, 1.8)
		)
		_append_multimesh_transform(
			rock_batches,
			Vector3(x, y, z),
			Transform3D(
				Basis().scaled(Vector3(
					radius * rock_scale.x,
					height * 0.5 * rock_scale.y,
					radius * rock_scale.z
				)),
				Vector3(x, y + height * 0.35, z)
			)
		)

	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.16
	trunk_mesh.bottom_radius = 0.28
	trunk_mesh.height = 1.0
	var crown_mesh := PrismMesh.new()
	crown_mesh.size = Vector3.ONE
	var rock_mesh := SphereMesh.new()
	rock_mesh.radius = 1.0
	rock_mesh.height = 2.0

	_create_chunked_multimesh_instances("TreeTrunks", trunk_mesh, tree_trunk_material, tree_trunk_batches)
	_create_chunked_multimesh_instances("TreeCrowns", crown_mesh, tree_material, tree_crown_batches)
	_create_chunked_multimesh_instances("Rocks", rock_mesh, rock_material, rock_batches)

func _build_grass() -> void:
	var grass_mesh := CylinderMesh.new()
	grass_mesh.top_radius = 0.015
	grass_mesh.bottom_radius = 0.08
	grass_mesh.height = 1.0
	grass_mesh.radial_segments = 3

	var transforms: Array[Transform3D] = []
	var colors: Array[Color] = []

	for i in range(GRASS_COUNT):
		var x := rng.randf_range(-145.0, 145.0)
		var z := rng.randf_range(-145.0, 145.0)

		if _distance_to_track(x, z) < TRACK_WIDTH * 0.5 + SHOULDER_WIDTH + 0.5:
			continue

		if Vector2(x, z).length() < LAKE_RADIUS + LAKE_SHORE_WIDTH + 1.0:
			continue

		if _distance_to_river(x, z) < RIVER_WIDTH * 0.5 + 1.0:
			continue

		var height := rng.randf_range(0.25, 0.8)
		var width := rng.randf_range(0.6, 1.5)
		var yaw := rng.randf_range(0.0, TAU)
		var basis := Basis(Vector3.UP, yaw).scaled(Vector3(width, height, width))
		var ground := _terrain_height(x, z)

		transforms.append(
			Transform3D(
				basis,
				Vector3(x, ground + height * 0.5, z)
			)
		)

		var shade := rng.randf_range(0.75, 1.15)
		colors.append(Color(0.22, 0.34, 0.13) * shade)

	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = grass_mesh
	multimesh.instance_count = transforms.size()

	for i in range(transforms.size()):
		multimesh.set_instance_transform(i, transforms[i])
		multimesh.set_instance_color(i, colors[i])

	grass_material.vertex_color_use_as_albedo = true

	var grass := MultiMeshInstance3D.new()
	grass.name = "GrassClumps"
	grass.multimesh = multimesh
	grass.material_override = grass_material
	add_child(grass)


func _build_trackside_details() -> void:
	for i in range(0, TRACK_SAMPLES, 14):
		var center: Vector3 = track_centers[i]
		var side: Vector3 = track_sides[i]
		var sign_value := -1.0 if i % 28 == 0 else 1.0

		var pos := center + side * (TRACK_WIDTH * 0.5 + 2.0) * sign_value

		var pole := MeshInstance3D.new()
		var pole_mesh := CylinderMesh.new()
		pole_mesh.top_radius = 0.045
		pole_mesh.bottom_radius = 0.07
		pole_mesh.height = 1.4
		pole.mesh = pole_mesh
		pole.material_override = marking_material
		pole.position = pos + Vector3.UP * 0.7
		add_child(pole)

		var cap := MeshInstance3D.new()
		var cap_mesh := SphereMesh.new()
		cap_mesh.radius = 0.13
		cap_mesh.height = 0.22
		cap.mesh = cap_mesh
		cap.material_override = _material(Color(0.95, 0.12, 0.06), 0.6)
		cap.position = pos + Vector3.UP * 1.4
		add_child(cap)

	for i in range(8):
		var index := int(float(i) / 8.0 * TRACK_SAMPLES)
		var center: Vector3 = track_centers[index]
		var tangent: Vector3 = track_tangents[index]

		var board := _add_box(
			self,
			"SectorBoard",
			center + track_sides[index] * 9.0 + Vector3.UP * 3.0,
			Vector3(3.5, 1.5, 0.25),
			_material(Color(0.08, 0.12, 0.15), 0.6),
			false
		)
		board.look_at(board.global_position + tangent, Vector3.UP)

	for i in range(10):
		var index := int(float(i) / 10.0 * TRACK_SAMPLES)
		var center: Vector3 = track_centers[index]
		var side: Vector3 = track_sides[index]

		var cone := MeshInstance3D.new()
		var cone_mesh := CylinderMesh.new()
		cone_mesh.top_radius = 0.0
		cone_mesh.bottom_radius = 0.32
		cone_mesh.height = 0.65
		cone.mesh = cone_mesh
		cone.material_override = _material(Color(1.0, 0.25, 0.04), 0.8)
		cone.position = (
			center
			+ side * (TRACK_WIDTH * 0.5 - 0.8)
			+ Vector3.UP * (TRACK_SURFACE_OFFSET + 0.35)
		)
		add_child(cone)


func _add_box(
	parent: Node3D,
	node_name: String,
	pos: Vector3,
	size: Vector3,
	material: Material,
	collision: bool
) -> Node3D:
	var root := Node3D.new()
	root.name = node_name
	root.position = pos
	parent.add_child(root)

	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	root.add_child(mesh_instance)

	if collision:
		var body := StaticBody3D.new()
		body.add_to_group("colliding")
		body.collision_layer = 1
		body.collision_mask = 1
		root.add_child(body)

		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		shape.shape = box
		body.add_child(shape)

	return root


func _distance_to_track(x: float, z: float) -> float:
	return sqrt(_nearest_track_sample(x, z).x)


func _build_environment() -> void:
	var world_environment := WorldEnvironment.new()
	world_environment.name = "WorldEnvironment"

	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY

	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.12, 0.25, 0.42)
	sky_material.sky_horizon_color = Color(0.62, 0.73, 0.82)
	sky_material.ground_bottom_color = Color(0.12, 0.16, 0.13)
	sky_material.ground_horizon_color = Color(0.46, 0.52, 0.43)
	sky.sky_material = sky_material

	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.55, 0.62, 0.72)
	environment.ambient_light_energy = 0.65
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.58, 0.67, 0.73)
	environment.fog_density = 0.0015

	world_environment.environment = environment
	add_child(world_environment)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-48.0, -32.0, 0.0)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	add_child(sun)

	var fill := DirectionalLight3D.new()
	fill.name = "MountainFillLight"
	fill.rotation_degrees = Vector3(-18.0, 145.0, 0.0)
	fill.light_energy = 0.25
	fill.shadow_enabled = false
	add_child(fill)
