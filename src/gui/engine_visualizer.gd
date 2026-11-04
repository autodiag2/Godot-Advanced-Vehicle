class_name EngineVisualizer
extends PopupPanel

var vehicle: BaseCar
var simulator: EngineSimulator
var engine_parameters: EngineParameters
var viewport: SubViewport
var engine_root: Node3D
var camera: Camera3D
var status_label: Label
var speed_label: Label
var speed_slider: HSlider
var cylinder_nodes: Array[Dictionary] = []
var visual_scale: float = 2.0
var piston_tdc_y: float = 1.1
var crank_radius: float = 0.086
var rod_length: float = 0.301
var crank_center_y: float = 0.713


func _ready() -> void:
	title = "Engine simulation"
	size = Vector2i(820, 540)
	min_size = Vector2i(680, 460)
	_build_interface()


func set_vehicle(value: BaseCar) -> void:
	vehicle = value
	simulator = vehicle.engine_controller.simulator
	engine_parameters = vehicle.engine_controller.engine_parameters
	if is_node_ready():
		_build_engine()
	_update_speed_controls()


func _build_interface() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.custom_minimum_size = Vector2(780.0, 500.0)
	add_child(root)

	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(status_label)

	var viewport_container := SubViewportContainer.new()
	viewport_container.stretch = true
	viewport_container.custom_minimum_size = Vector2(780.0, 390.0)
	viewport_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	viewport_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(viewport_container)

	viewport = SubViewport.new()
	viewport.size = Vector2i(780, 390)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport_container.add_child(viewport)

	var controls := HBoxContainer.new()
	controls.custom_minimum_size = Vector2(0.0, 36.0)
	root.add_child(controls)

	speed_label = Label.new()
	speed_label.custom_minimum_size = Vector2(90.0, 0.0)
	controls.add_child(speed_label)

	speed_slider = HSlider.new()
	speed_slider.min_value = 0.01
	speed_slider.max_value = 1.0
	speed_slider.step = 0.01
	speed_slider.value = Engine.time_scale
	speed_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	speed_slider.value_changed.connect(_on_speed_changed)
	controls.add_child(speed_slider)

	var reset_button := Button.new()
	reset_button.text = "1×"
	reset_button.pressed.connect(_on_reset_speed)
	controls.add_child(reset_button)

	var close_button := Button.new()
	close_button.text = "Close"
	close_button.pressed.connect(hide)
	controls.add_child(close_button)

	_build_viewport()


func _build_viewport() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.035, 0.045, 0.06)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.72, 0.76, 0.84)

	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	viewport.add_child(world_environment)

	camera = Camera3D.new()
	camera.position = Vector3(0.0, 1.9, 4.8)
	camera.fov = 38.0
	camera.look_at(Vector3(0.0, 0.95, 0.0), Vector3.UP)
	camera.current = true
	viewport.add_child(camera)

	var key_light := DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-35.0, 25.0, 0.0)
	key_light.light_energy = 2.0
	key_light.shadow_enabled = true
	viewport.add_child(key_light)

	var fill_light := OmniLight3D.new()
	fill_light.position = Vector3(-2.0, 2.5, 2.0)
	fill_light.light_energy = 1.1
	viewport.add_child(fill_light)


func _build_engine() -> void:
	if viewport == null or engine_parameters == null:
		return

	if is_instance_valid(engine_root):
		engine_root.queue_free()

	engine_root = Node3D.new()
	viewport.add_child(engine_root)
	cylinder_nodes.clear()

	var cylinder_count := maxi(engine_parameters.cylinder_count, 1)
	var bore_radius := engine_parameters.bore_mm / 1000.0 * visual_scale * 0.5
	var stroke := engine_parameters.stroke_mm / 1000.0 * visual_scale
	crank_radius = stroke * 0.5
	rod_length = crank_radius * engine_parameters.connecting_rod_ratio
	crank_center_y = piston_tdc_y - crank_radius - rod_length
	var spacing := maxf(bore_radius * 2.5, 0.26)
	var width := spacing * float(cylinder_count - 1) + bore_radius * 2.8
	camera.position = Vector3(0.0, 1.9, maxf(4.8, width * 1.6))
	camera.look_at(Vector3(0.0, 0.95, 0.0), Vector3.UP)

	var frame_material := _make_material(Color(0.12, 0.15, 0.19), 0.75)
	var metal_material := _make_material(Color(0.56, 0.61, 0.67), 0.88)
	var dark_material := _make_material(Color(0.055, 0.065, 0.08), 0.55)
	var flame_material := _make_material(
		Color(1.0, 0.32, 0.035),
		0.0,
		Color(1.0, 0.18, 0.015)
	)

	_add_box(
		engine_root,
		Vector3(width + 0.24, 0.12, 0.34),
		Vector3(0.0, 0.59, 0.0),
		frame_material
	)
	_add_box(
		engine_root,
		Vector3(width + 0.24, 0.14, 0.34),
		Vector3(0.0, 1.39, 0.0),
		frame_material
	)
	_add_box(
		engine_root,
		Vector3(0.12, 0.78, 0.34),
		Vector3(-width * 0.5, 0.99, 0.0),
		frame_material
	)
	_add_box(
		engine_root,
		Vector3(0.12, 0.78, 0.34),
		Vector3(width * 0.5, 0.99, 0.0),
		frame_material
	)

	var crankshaft := _add_cylinder(
		engine_root,
		0.055,
		width + 0.42,
		metal_material
	)
	crankshaft.rotation.z = PI * 0.5
	crankshaft.position.y = crank_center_y

	for cylinder_index in range(cylinder_count):
		var x_position := (
			(float(cylinder_index) - float(cylinder_count - 1) * 0.5) *
			spacing
		)
		var ring_radius := bore_radius
		for ring_index in range(4):
			var ring := MeshInstance3D.new()
			var ring_mesh := TorusMesh.new()
			ring_mesh.inner_radius = ring_radius * 0.82
			ring_mesh.outer_radius = ring_radius
			ring.mesh = ring_mesh
			ring.material_override = metal_material
			ring.position = Vector3(
				x_position,
				piston_tdc_y - float(ring_index) * 0.13 - 0.02,
				0.0
			)
			engine_root.add_child(ring)

		var piston := _add_cylinder(
			engine_root,
			bore_radius * 0.84,
			0.13,
			metal_material
		)
		piston.position = Vector3(x_position, piston_tdc_y - 0.065, 0.0)

		var connecting_rod := _add_cylinder(
			engine_root,
			0.028,
			1.0,
			metal_material
		)
		var crank_pin := _add_cylinder(
			engine_root,
			0.045,
			0.13,
			metal_material
		)
		crank_pin.rotation.z = PI * 0.5

		var flame := MeshInstance3D.new()
		var flame_mesh := SphereMesh.new()
		flame_mesh.radius = bore_radius * 0.5
		flame_mesh.height = bore_radius
		flame.mesh = flame_mesh
		flame.material_override = flame_material
		flame.position = Vector3(x_position, piston_tdc_y + 0.12, 0.0)
		flame.visible = false
		engine_root.add_child(flame)

		var valve_a := _add_cylinder(
			engine_root,
			0.025,
			0.12,
			dark_material
		)
		var valve_b := _add_cylinder(
			engine_root,
			0.025,
			0.12,
			dark_material
		)
		valve_a.position = Vector3(x_position - bore_radius * 0.32, 1.49, 0.0)
		valve_b.position = Vector3(x_position + bore_radius * 0.32, 1.49, 0.0)

		cylinder_nodes.append({
			"piston": piston,
			"rod": connecting_rod,
			"crank_pin": crank_pin,
			"flame": flame,
			"valve_a": valve_a,
			"valve_b": valve_b,
			"x": x_position,
		})


func _process(_delta: float) -> void:
	if simulator == null or engine_parameters == null:
		return

	var fuel_name := "Gasoline"
	if engine_parameters.fuel_type == EngineParameters.FuelType.DIESEL:
		fuel_name = "Diesel (gasoil)"
	var displacement_l := (
		PI *
		pow(engine_parameters.bore_mm, 2.0) *
		0.25 *
		engine_parameters.stroke_mm *
		float(engine_parameters.cylinder_count) /
		1000000.0
	)
	status_label.text = "%s · %d cylinders · %.2f L · %d rpm · %.0f N·m" % [
		fuel_name,
		engine_parameters.cylinder_count,
		displacement_l,
		int(simulator.rpm),
		simulator.output_torque,
	]
	speed_label.text = "%.2fx" % Engine.time_scale
	if absf(speed_slider.value - Engine.time_scale) > 0.005:
		speed_slider.set_value_no_signal(Engine.time_scale)

	for cylinder_index in range(cylinder_nodes.size()):
		var phase := simulator.get_cylinder_phase(cylinder_index)
		var theta := deg_to_rad(fposmod(phase, 360.0))
		var piston_displacement := (
			simulator.get_piston_displacement(phase) * visual_scale
		)
		var piston_y := piston_tdc_y - piston_displacement
		var crank_pin_position := Vector3(
			cylinder_nodes[cylinder_index].x + crank_radius * sin(theta),
			crank_center_y + crank_radius * cos(theta),
			0.0
		)
		var piston_pin_position := Vector3(
			cylinder_nodes[cylinder_index].x,
			piston_y,
			0.0
		)
		var rod_delta := piston_pin_position - crank_pin_position
		var connecting_rod: MeshInstance3D = cylinder_nodes[cylinder_index].rod
		connecting_rod.position = (
			piston_pin_position + crank_pin_position
		) * 0.5
		connecting_rod.scale.y = rod_delta.length()
		connecting_rod.rotation.z = atan2(-rod_delta.x, rod_delta.y)
		cylinder_nodes[cylinder_index].piston.position.y = piston_y - 0.065
		cylinder_nodes[cylinder_index].crank_pin.position = crank_pin_position

		var combustion_intensity := (
			simulator.get_cylinder_combustion_intensity(cylinder_index)
		)
		var flame: MeshInstance3D = cylinder_nodes[cylinder_index].flame
		flame.visible = combustion_intensity > 0.02
		flame.scale = Vector3.ONE * maxf(combustion_intensity, 0.05)

		var valve_lift := 0.0
		if (
			phase > 185.0 and phase < 355.0 or
			phase > 365.0 and phase < 535.0
		):
			valve_lift = 0.035
		cylinder_nodes[cylinder_index].valve_a.position.y = 1.49 - valve_lift
		cylinder_nodes[cylinder_index].valve_b.position.y = 1.49 - valve_lift


func _on_speed_changed(value: float) -> void:
	Engine.time_scale = clampf(value, 0.01, 1.0)


func _on_reset_speed() -> void:
	Engine.time_scale = 1.0
	speed_slider.set_value_no_signal(1.0)


func _update_speed_controls() -> void:
	if speed_slider != null:
		speed_slider.set_value_no_signal(Engine.time_scale)


func _make_material(
	color: Color,
	metallic: float,
	emission_color: Color = Color(0.0, 0.0, 0.0)
) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = 0.32
	if emission_color != Color(0.0, 0.0, 0.0):
		material.emission_enabled = true
		material.emission = emission_color
		material.emission_energy_multiplier = 2.0
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
	instance.mesh = mesh
	instance.material_override = material
	parent.add_child(instance)
	return instance
