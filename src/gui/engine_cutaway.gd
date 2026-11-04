class_name EngineCutaway
extends Node3D

var simulator: EngineSimulator
var engine_parameters: EngineParameters
var model_root: Node3D
var camera: Camera3D
var cylinder_parts: Array[Dictionary] = []
var piston_top_y: float = 1.48
var crank_radius: float = 0.095
var rod_length: float = 0.33
var crank_center_y: float = 0.89
var visual_scale: float = 2.2


func _ready() -> void:
	_build_lighting()


func configure(engine_simulator: EngineSimulator, parameters: EngineParameters) -> void:
	simulator = engine_simulator
	engine_parameters = parameters
	if is_node_ready():
		_build_engine()


func _build_lighting() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.018, 0.025, 0.04)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.46, 0.53, 0.68)
	environment.ambient_light_energy = 0.75
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC

	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)

	camera = Camera3D.new()
	camera.position = Vector3(0.0, 2.0, 5.6)
	camera.fov = 34.0
	camera.look_at(Vector3(0.0, 1.02, 0.0), Vector3.UP)
	camera.current = true
	add_child(camera)

	var key_light := DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-42.0, -28.0, 0.0)
	key_light.light_energy = 2.0
	key_light.shadow_enabled = true
	add_child(key_light)

	var rim_light := OmniLight3D.new()
	rim_light.position = Vector3(2.0, 2.6, -2.3)
	rim_light.light_color = Color(0.28, 0.54, 1.0)
	rim_light.light_energy = 2.2
	rim_light.omni_range = 7.0
	add_child(rim_light)

	var fill_light := OmniLight3D.new()
	fill_light.position = Vector3(-2.4, 1.2, 3.2)
	fill_light.light_color = Color(1.0, 0.56, 0.25)
	fill_light.light_energy = 1.0
	fill_light.omni_range = 6.0
	add_child(fill_light)

	var floor := MeshInstance3D.new()
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(7.0, 5.0)
	floor.mesh = floor_mesh
	floor.position.y = 0.36
	floor.material_override = _make_material(
		Color(0.025, 0.035, 0.055),
		0.35,
		0.0
	)
	add_child(floor)


func _build_engine() -> void:
	if engine_parameters == null or simulator == null:
		return
	if is_instance_valid(model_root):
		model_root.queue_free()

	model_root = Node3D.new()
	add_child(model_root)
	cylinder_parts.clear()

	var cylinder_count := maxi(engine_parameters.cylinder_count, 1)
	var bore_radius := (
		engine_parameters.bore_mm /
		1000.0 *
		visual_scale *
		0.5
	)
	var stroke := engine_parameters.stroke_mm / 1000.0 * visual_scale
	crank_radius = stroke * 0.5
	rod_length = crank_radius * engine_parameters.connecting_rod_ratio
	piston_top_y = 1.48
	crank_center_y = piston_top_y - crank_radius - rod_length
	var spacing := maxf(bore_radius * 2.65, 0.29)
	var width := (
		spacing * float(cylinder_count - 1) +
		bore_radius * 3.0
	)
	camera.position = Vector3(
		0.0,
		2.05,
		maxf(5.2, width * 1.75)
	)
	camera.look_at(Vector3(0.0, 1.02, 0.0), Vector3.UP)

	var block_material := _make_material(Color(0.12, 0.17, 0.24), 0.78, 0.0)
	var block_edge_material := _make_material(Color(0.24, 0.3, 0.38), 0.83, 0.0)
	var steel_material := _make_material(Color(0.67, 0.73, 0.81), 0.92, 0.0)
	var dark_steel_material := _make_material(Color(0.11, 0.14, 0.19), 0.82, 0.0)
	var copper_material := _make_material(Color(0.8, 0.42, 0.19), 0.76, 0.0)
	var glass_material := _make_material(
		Color(0.3, 0.64, 0.91, 0.09),
		0.18,
		0.0
	)
	glass_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var flame_glow_material := _make_material(
		Color(1.0, 0.36, 0.06, 0.82),
		0.0,
		2.5
	)

	_add_box(
		model_root,
		Vector3(width + 0.54, 0.2, 0.82),
		Vector3(0.0, 0.69, 0.0),
		block_material
	)
	_add_box(
		model_root,
		Vector3(width + 0.56, 0.18, 0.84),
		Vector3(0.0, piston_top_y + 0.25, 0.0),
		block_edge_material
	)
	_add_box(
		model_root,
		Vector3(width + 0.26, 0.16, 0.74),
		Vector3(0.0, crank_center_y - 0.18, 0.0),
		dark_steel_material
	)

	var crankshaft := _add_cylinder(
		model_root,
		0.055,
		width + 0.68,
		steel_material
	)
	crankshaft.rotation.z = PI * 0.5
	crankshaft.position.y = crank_center_y

	var bearing_count := maxi(cylinder_count + 1, 2)
	for bearing_index in range(bearing_count):
		var bearing_x := (
			(float(bearing_index) - float(bearing_count - 1) * 0.5) *
			spacing
		)
		var bearing := _add_cylinder(
			model_root,
			0.115,
			0.18,
			dark_steel_material
		)
		bearing.rotation.z = PI * 0.5
		bearing.position = Vector3(bearing_x, crank_center_y, 0.0)

	for cylinder_index in range(cylinder_count):
		var x_position := (
			(float(cylinder_index) - float(cylinder_count - 1) * 0.5) *
			spacing
		)
		var liner := _add_cylinder(
			model_root,
			bore_radius * 1.06,
			stroke + 0.38,
			glass_material
		)
		liner.position = Vector3(
			x_position,
			piston_top_y - stroke * 0.5 + 0.1,
			0.0
		)

		var liner_rim := _add_torus(
			model_root,
			bore_radius * 0.98,
			bore_radius * 1.08,
			steel_material
		)
		liner_rim.position = Vector3(x_position, piston_top_y + 0.02, 0.0)

		var piston := _add_cylinder(
			model_root,
			bore_radius * 0.88,
			0.15,
			steel_material
		)
		piston.position = Vector3(x_position, piston_top_y - 0.075, 0.0)

		var piston_rings: Array[MeshInstance3D] = []
		for ring_index in range(3):
			var ring := _add_torus(
				model_root,
				bore_radius * 0.86,
				bore_radius * 0.96,
				copper_material if ring_index == 2 else dark_steel_material
			)
			ring.position = Vector3(
				x_position,
				piston_top_y - 0.035 - float(ring_index) * 0.035,
				0.0
			)
			piston_rings.append(ring)

		var connecting_rod := _add_cylinder(
			model_root,
			0.033,
			1.0,
			copper_material
		)
		var big_end := _add_cylinder(
			model_root,
			0.072,
			0.15,
			steel_material
		)
		big_end.rotation.z = PI * 0.5
		var crank_pin := _add_cylinder(
			model_root,
			0.047,
			0.15,
			copper_material
		)
		crank_pin.rotation.z = PI * 0.5

		var glow := MeshInstance3D.new()
		var glow_mesh := SphereMesh.new()
		glow_mesh.radius = bore_radius * 0.46
		glow_mesh.height = bore_radius * 0.92
		glow.mesh = glow_mesh
		glow.material_override = flame_glow_material
		glow.position = Vector3(x_position, piston_top_y + 0.09, 0.0)
		glow.visible = false
		model_root.add_child(glow)

		var flame_particles := _create_particles(
			x_position,
			piston_top_y + 0.08,
			0.035,
			0.12,
			40,
			0.28,
			Color(1.0, 0.2, 0.025, 0.95),
			Color(1.0, 0.86, 0.24, 0.0),
			Vector3(0.0, 0.55, 0.0),
			0.45,
			1.35
		)
		var smoke_particles := _create_particles(
			x_position,
			piston_top_y + 0.15,
			0.055,
			0.2,
			34,
			1.05,
			Color(0.25, 0.29, 0.35, 0.4),
			Color(0.16, 0.19, 0.24, 0.0),
			Vector3(0.0, 0.28, 0.0),
			0.08,
			0.35
		)

		var chamber_light := OmniLight3D.new()
		chamber_light.position = Vector3(x_position, piston_top_y + 0.1, 0.02)
		chamber_light.light_color = Color(1.0, 0.25, 0.035)
		chamber_light.light_energy = 0.0
		chamber_light.omni_range = 1.2
		model_root.add_child(chamber_light)

		var intake_valve := _build_valve(
			x_position - bore_radius * 0.36,
			piston_top_y + 0.3,
			steel_material
		)
		var exhaust_valve := _build_valve(
			x_position + bore_radius * 0.36,
			piston_top_y + 0.3,
			copper_material
		)
		var ignition_device := _add_cylinder(
			model_root,
			0.027,
			0.2,
			copper_material
		)
		ignition_device.position = Vector3(
			x_position,
			piston_top_y + 0.35,
			-0.12
		)

		var pressure_label := Label3D.new()
		pressure_label.text = "CYL %02d" % (cylinder_index + 1)
		pressure_label.font_size = 30
		pressure_label.pixel_size = 0.002
		pressure_label.position = Vector3(
			x_position,
			piston_top_y + 0.61,
			0.0
		)
		pressure_label.modulate = Color(0.74, 0.84, 0.98)
		model_root.add_child(pressure_label)

		cylinder_parts.append({
			"piston": piston,
			"piston_rings": piston_rings,
			"rod": connecting_rod,
			"big_end": big_end,
			"crank_pin": crank_pin,
			"glow": glow,
			"flame_particles": flame_particles,
			"smoke_particles": smoke_particles,
			"chamber_light": chamber_light,
			"intake_valve": intake_valve,
			"exhaust_valve": exhaust_valve,
			"pressure_label": pressure_label,
			"x": x_position,
		})

	_add_box(
		model_root,
		Vector3(width + 0.35, 0.08, 0.48),
		Vector3(0.0, piston_top_y + 0.42, 0.0),
		block_material
	)
	_add_box(
		model_root,
		Vector3(width + 0.5, 0.08, 0.78),
		Vector3(0.0, crank_center_y - 0.34, 0.0),
		block_edge_material
	)

	var camshaft := _add_cylinder(
		model_root,
		0.035,
		width + 0.5,
		copper_material
	)
	camshaft.rotation.z = PI * 0.5
	camshaft.position = Vector3(0.0, piston_top_y + 0.52, -0.21)


func _process(_delta: float) -> void:
	if simulator == null or engine_parameters == null:
		return

	for cylinder_index in range(cylinder_parts.size()):
		var phase := simulator.get_cylinder_phase(cylinder_index)
		var theta := deg_to_rad(fposmod(phase, 360.0))
		var piston_displacement := (
			simulator.get_piston_displacement(phase) *
			visual_scale
		)
		var piston_y := piston_top_y - piston_displacement
		var crank_pin_position := Vector3(
			cylinder_parts[cylinder_index].x,
			crank_center_y + crank_radius * cos(theta),
			crank_radius * sin(theta)
		)
		var piston_pin_position := Vector3(
			cylinder_parts[cylinder_index].x,
			piston_y,
			0.0
		)
		var rod_delta := piston_pin_position - crank_pin_position
		var connecting_rod: MeshInstance3D = cylinder_parts[cylinder_index].rod
		connecting_rod.position = (
			piston_pin_position + crank_pin_position
		) * 0.5
		connecting_rod.scale.y = rod_delta.length()
		connecting_rod.rotation.x = atan2(-rod_delta.z, rod_delta.y)
		cylinder_parts[cylinder_index].piston.position.y = piston_y - 0.075

		for ring_index in range(cylinder_parts[cylinder_index].piston_rings.size()):
			var ring: MeshInstance3D = (
				cylinder_parts[cylinder_index].piston_rings[ring_index]
			)
			ring.position.y = piston_y - 0.025 - float(ring_index) * 0.035

		cylinder_parts[cylinder_index].big_end.position = crank_pin_position
		cylinder_parts[cylinder_index].crank_pin.position = crank_pin_position

		var flame_intensity := (
			simulator.get_cylinder_combustion_intensity(cylinder_index)
		)
		var smoke_intensity := simulator.get_cylinder_smoke_intensity(cylinder_index)
		var glow: MeshInstance3D = cylinder_parts[cylinder_index].glow
		glow.visible = flame_intensity > 0.03
		glow.scale = Vector3.ONE * maxf(flame_intensity, 0.04)
		cylinder_parts[cylinder_index].flame_particles.emitting = (
			flame_intensity > 0.06
		)
		cylinder_parts[cylinder_index].smoke_particles.emitting = (
			smoke_intensity > 0.12
		)
		cylinder_parts[cylinder_index].chamber_light.light_energy = (
			flame_intensity * 4.5
		)

		var intake_lift := _visual_valve_lift(
			phase,
			engine_parameters.intake_valve_open_deg,
			engine_parameters.intake_valve_close_deg
		)
		var exhaust_lift := _visual_valve_lift(
			phase,
			engine_parameters.exhaust_valve_open_deg,
			engine_parameters.exhaust_valve_close_deg
		)
		cylinder_parts[cylinder_index].intake_valve.position.y = (
			piston_top_y + 0.3 - intake_lift * 2.0
		)
		cylinder_parts[cylinder_index].exhaust_valve.position.y = (
			piston_top_y + 0.3 - exhaust_lift * 2.0
		)
		var pressure := simulator.get_cylinder_pressure_kpa(cylinder_index)
		cylinder_parts[cylinder_index].pressure_label.text = (
			"C%02d  %.0f kPa" % [cylinder_index + 1, pressure]
		)


func _visual_valve_lift(phase: float, open_angle: float, close_angle: float) -> float:
	if phase < open_angle or phase > close_angle or close_angle <= open_angle:
		return 0.0
	var ratio := (phase - open_angle) / (close_angle - open_angle)
	return (
		engine_parameters.max_valve_lift_mm /
		1000.0 *
		pow(maxf(sin(PI * ratio), 0.0), 0.7)
	)


func _build_valve(x: float, y: float, material: Material) -> Node3D:
	var valve := Node3D.new()
	valve.position = Vector3(x, y, 0.0)
	model_root.add_child(valve)
	var stem := _add_cylinder(
		valve,
		0.012,
		0.18,
		material
	)
	stem.position.y = 0.04
	var head := _add_cylinder(
		valve,
		0.045,
		0.025,
		material
	)
	head.position.y = -0.06
	return valve


func _create_particles(
	x: float,
	y: float,
	z: float,
	radius: float,
	amount: int,
	lifetime: float,
	start_color: Color,
	end_color: Color,
	gravity: Vector3,
	velocity_min: float,
	velocity_max: float
) -> GPUParticles3D:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([start_color, end_color])
	gradient.offsets = PackedFloat32Array([0.0, 1.0])
	var ramp := GradientTexture1D.new()
	ramp.gradient = gradient

	var process_material := ParticleProcessMaterial.new()
	process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process_material.emission_sphere_radius = radius
	process_material.direction = Vector3.UP
	process_material.spread = 45.0
	process_material.initial_velocity_min = velocity_min
	process_material.initial_velocity_max = velocity_max
	process_material.gravity = gravity
	process_material.scale_min = 0.3
	process_material.scale_max = 1.2
	process_material.color_ramp = ramp

	var particles := GPUParticles3D.new()
	particles.position = Vector3(x, y, z)
	particles.amount = amount
	particles.lifetime = lifetime
	particles.explosiveness = 0.15
	particles.randomness = 0.45
	particles.emitting = false
	particles.process_material = process_material

	var sphere := SphereMesh.new()
	sphere.radius = 0.035
	sphere.height = 0.07
	particles.draw_pass_1 = sphere
	var particle_material := StandardMaterial3D.new()
	particle_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	particle_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	particles.material_override = particle_material
	model_root.add_child(particles)
	return particles


func _make_material(
	color: Color,
	metallic: float,
	emission_energy: float
) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = 0.27
	if emission_energy > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = emission_energy
	return material


func _add_box(
	parent: Node3D,
	box_size: Vector3,
	position: Vector3,
	material: Material
) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = box_size
	instance.mesh = mesh
	instance.material_override = material
	instance.position = position
	parent.add_child(instance)
	return instance


func _add_cylinder(
	parent: Node3D,
	radius: float,
	height: float,
	material: Material
) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 48
	instance.mesh = mesh
	instance.material_override = material
	parent.add_child(instance)
	return instance


func _add_torus(
	parent: Node3D,
	inner_radius: float,
	outer_radius: float,
	material: Material
) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner_radius
	mesh.outer_radius = outer_radius
	mesh.rings = 24
	mesh.ring_segments = 12
	instance.mesh = mesh
	instance.material_override = material
	parent.add_child(instance)
	return instance
