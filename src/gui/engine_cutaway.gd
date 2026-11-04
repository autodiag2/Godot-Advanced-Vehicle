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
var camera_target := Vector3(0.0, 1.02, 0.0)
var camera_distance: float = 5.2
var camera_yaw: float = 0.0
var camera_pitch: float = 0.18
var rotating_view: bool = false
var crankshaft_pick_radius: float = 0.14
var crankshaft_pick_half_length: float = 0.5
var crankshaft_mesh: MeshInstance3D
var hovered_cylinder_index: int = -1
var selected_cylinder_index: int = -1
var hovered_crankshaft: bool = false
var selected_crankshaft: bool = false
var hover_material: StandardMaterial3D
var info_panel: PanelContainer
var info_label: Label
var fluid_shader: Shader
var fluid_time: float = 0.0


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
	camera.fov = 30.0
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
	_create_selection_info_panel()



func _create_selection_info_panel() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 5
	add_child(canvas)

	info_panel = PanelContainer.new()
	info_panel.position = Vector2(18.0, 18.0)
	info_panel.custom_minimum_size = Vector2(280.0, 112.0)
	info_panel.size = Vector2(280.0, 112.0)
	info_panel.visible = false
	info_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.018, 0.03, 0.052, 0.94)
	panel_style.border_color = Color(0.28, 0.57, 0.82, 0.9)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(8)
	panel_style.content_margin_left = 12.0
	panel_style.content_margin_top = 9.0
	panel_style.content_margin_right = 12.0
	panel_style.content_margin_bottom = 9.0
	info_panel.add_theme_stylebox_override("panel", panel_style)

	info_label = Label.new()
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_label.add_theme_color_override("font_color", Color(0.86, 0.92, 1.0))
	info_label.add_theme_font_size_override("font_size", 14)
	info_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_panel.add_child(info_label)
	canvas.add_child(info_panel)





func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_update_hover(event.position)
		if rotating_view:
			_rotate_camera(event.relative)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_update_hover(event.position)
		if event.pressed:
			_select_hovered_part()
		rotating_view = event.pressed
	elif event is InputEventScreenTouch:
		_update_hover(event.position)
		if event.pressed:
			_select_hovered_part()
		rotating_view = event.pressed
	elif event is InputEventScreenDrag:
		_update_hover(event.position)
		_rotate_camera(event.relative)


func _pick_interactable(screen_position: Vector2) -> Dictionary:
	if camera == null or model_root == null:
		return {}
	var world_origin := camera.project_ray_origin(screen_position)
	var world_direction := camera.project_ray_normal(screen_position)
	var ray_origin := model_root.to_local(world_origin)
	var ray_direction := (
		model_root.to_local(world_origin + world_direction) - ray_origin
	).normalized()
	var nearest_distance := 1.0e20
	var nearest_hit: Dictionary = {}

	for cylinder_index in range(cylinder_parts.size()):
		var part: Dictionary = cylinder_parts[cylinder_index]
		var distance := _ray_cylinder_distance(
			ray_origin,
			ray_direction,
			part.pick_center,
			float(part.pick_radius),
			float(part.pick_half_length),
			false
		)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_hit = {
				"kind": "cylinder",
				"index": cylinder_index,
			}

	var crankshaft_distance := _ray_cylinder_distance(
		ray_origin,
		ray_direction,
		Vector3(0.0, crank_center_y, 0.0),
		crankshaft_pick_radius,
		crankshaft_pick_half_length,
		true
	)
	if crankshaft_distance < nearest_distance:
		nearest_hit = {"kind": "crankshaft"}
	return nearest_hit


func _ray_cylinder_distance(
	ray_origin: Vector3,
	ray_direction: Vector3,
	center: Vector3,
	radius: float,
	half_length: float,
	axis_is_x: bool
) -> float:
	var perpendicular_origin: Vector2
	var perpendicular_direction: Vector2
	var axial_origin: float
	var axial_direction: float
	var axial_center: float
	if axis_is_x:
		perpendicular_origin = Vector2(
			ray_origin.y - center.y,
			ray_origin.z - center.z
		)
		perpendicular_direction = Vector2(ray_direction.y, ray_direction.z)
		axial_origin = ray_origin.x
		axial_direction = ray_direction.x
		axial_center = center.x
	else:
		perpendicular_origin = Vector2(
			ray_origin.x - center.x,
			ray_origin.z - center.z
		)
		perpendicular_direction = Vector2(ray_direction.x, ray_direction.z)
		axial_origin = ray_origin.y
		axial_direction = ray_direction.y
		axial_center = center.y

	var quadratic_a := perpendicular_direction.length_squared()
	if quadratic_a < 0.000001:
		return 1.0e20
	var quadratic_b := 2.0 * perpendicular_origin.dot(perpendicular_direction)
	var quadratic_c := perpendicular_origin.length_squared() - radius * radius
	var discriminant := quadratic_b * quadratic_b - 4.0 * quadratic_a * quadratic_c
	if discriminant < 0.0:
		return 1.0e20
	var root := sqrt(discriminant)
	var near_distance := (-quadratic_b - root) / (2.0 * quadratic_a)
	var far_distance := (-quadratic_b + root) / (2.0 * quadratic_a)
	for distance in [near_distance, far_distance]:
		if distance < 0.0:
			continue
		var axial_position := axial_origin + axial_direction * distance
		if absf(axial_position - axial_center) <= half_length:
			return distance
	return 1.0e20


func _update_hover(screen_position: Vector2) -> void:
	var hit := _pick_interactable(screen_position)
	var next_cylinder := -1
	var next_crankshaft := false
	if hit.get("kind", "") == "cylinder":
		next_cylinder = int(hit.index)
	elif hit.get("kind", "") == "crankshaft":
		next_crankshaft = true
	if next_cylinder != hovered_cylinder_index or next_crankshaft != hovered_crankshaft:
		hovered_cylinder_index = next_cylinder
		hovered_crankshaft = next_crankshaft
		_refresh_highlights()


func _select_hovered_part() -> void:
	selected_cylinder_index = hovered_cylinder_index
	selected_crankshaft = hovered_crankshaft
	_update_selection_info()
	_refresh_highlights()

func _rotate_camera(relative: Vector2) -> void:
	camera_yaw -= relative.x * 0.008
	camera_pitch = clampf(camera_pitch + relative.y * 0.008, -0.8, 0.8)
	_update_camera_orbit()


func _update_camera_orbit() -> void:
	if camera == null:
		return
	var horizontal_distance := camera_distance * cos(camera_pitch)
	camera.position = camera_target + Vector3(
		sin(camera_yaw) * horizontal_distance,
		camera_distance * sin(camera_pitch),
		cos(camera_yaw) * horizontal_distance
	)
	camera.look_at(camera_target, Vector3.UP)


func _build_engine() -> void:
	if engine_parameters == null or simulator == null:
		return
	if is_instance_valid(model_root):
		model_root.queue_free()

	model_root = Node3D.new()
	add_child(model_root)
	cylinder_parts.clear()
	hovered_cylinder_index = -1
	selected_cylinder_index = -1
	hovered_crankshaft = false
	selected_crankshaft = false
	info_panel.visible = false

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
	camera_target = Vector3(0.0, 1.02, 0.0)
	camera_distance = maxf(3.8, width * 1.28)
	_update_camera_orbit()

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
		Color(1.0, 0.075, 0.008, 0.96),
		0.0,
		6.0
	)
	hover_material = _make_material(Color(0.95, 0.68, 0.2, 0.28), 0.1, 2.2)
	hover_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fluid_shader = _create_fluid_shader()
	crankshaft_mesh = null

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

	crankshaft_mesh = _add_cylinder(
		model_root,
		0.055,
		width + 0.68,
		steel_material
	)
	crankshaft_mesh.rotation.z = PI * 0.5
	crankshaft_mesh.position.y = crank_center_y
	crankshaft_pick_half_length = (width + 0.8) * 0.5

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

		var fluid_mesh := CylinderMesh.new()
		fluid_mesh.top_radius = bore_radius * 0.82
		fluid_mesh.bottom_radius = bore_radius * 0.82
		fluid_mesh.height = 1.0
		fluid_mesh.radial_segments = 48
		fluid_mesh.rings = 16
		var fluid_volume := MeshInstance3D.new()
		fluid_volume.mesh = fluid_mesh
		fluid_volume.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var fluid_material := ShaderMaterial.new()
		fluid_material.shader = fluid_shader
		fluid_material.set_shader_parameter("flame_fill", 0.0)
		fluid_material.set_shader_parameter("smoke_fill", 0.0)
		fluid_material.set_shader_parameter("flow_time", 0.0)
		fluid_volume.material_override = fluid_material
		fluid_volume.position = Vector3(x_position, piston_top_y, 0.04)
		fluid_volume.visible = false
		model_root.add_child(fluid_volume)

		var glow := MeshInstance3D.new()
		var glow_mesh := SphereMesh.new()
		glow_mesh.radius = bore_radius * 0.46
		glow_mesh.height = bore_radius * 0.92
		glow.mesh = glow_mesh
		glow.material_override = flame_glow_material
		glow.position = Vector3(x_position, piston_top_y + 0.09, 0.0)
		glow.visible = false
		model_root.add_child(glow)

		var chamber_light := OmniLight3D.new()
		chamber_light.position = Vector3(x_position, piston_top_y + 0.1, 0.02)
		chamber_light.light_color = Color(1.0, 0.09, 0.008)
		chamber_light.light_energy = 0.0
		chamber_light.omni_range = 1.8
		model_root.add_child(chamber_light)

		var red_flame_light := OmniLight3D.new()
		red_flame_light.position = Vector3(x_position, piston_top_y + 0.08, 0.03)
		red_flame_light.light_color = Color(1.0, 0.015, 0.002)
		red_flame_light.light_energy = 0.0
		red_flame_light.omni_range = 2.2
		model_root.add_child(red_flame_light)

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


		cylinder_parts.append({
			"piston": piston,
			"piston_rings": piston_rings,
			"rod": connecting_rod,
			"big_end": big_end,
			"crank_pin": crank_pin,
			"glow": glow,
			"chamber_light": chamber_light,
			"red_flame_light": red_flame_light,
			"intake_valve": intake_valve,
			"exhaust_valve": exhaust_valve,
			"liner": liner,
			"liner_rim": liner_rim,
			"pick_center": liner.position,
			"pick_radius": bore_radius * 1.28,
			"pick_half_length": (stroke + 0.42) * 0.5,
			"fluid_volume": fluid_volume,
			"fluid_material": fluid_material,
			"flow_offset": float(cylinder_index) * 2.37,
			"flame_fill": 0.0,
			"smoke_fill": 0.0,
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


func _process(delta: float) -> void:
	if simulator == null or engine_parameters == null:
		return

	fluid_time += delta
	var visual_angle_step := maxf(simulator.rpm * 6.0 * delta, 0.0)
	var flame_rise_blend := 1.0 - exp(-visual_angle_step / 16.0)
	var flame_fall_blend := 1.0 - exp(-visual_angle_step / 38.0)
	var smoke_rise_blend := 1.0 - exp(-visual_angle_step / 28.0)
	var smoke_fall_blend := 1.0 - exp(-visual_angle_step / 42.0)
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

		var flame_intensity := simulator.get_cylinder_combustion_intensity(cylinder_index)
		var smoke_intensity := simulator.get_cylinder_smoke_intensity(cylinder_index)
		var burned_fraction := simulator.get_cylinder_burned_fraction(cylinder_index)
		var fire_window := 0.0
		if phase < 210.0:
			fire_window = clampf(1.0 - phase / 210.0, 0.0, 1.0)
		elif phase >= 650.0:
			fire_window = clampf((phase - 650.0) / 70.0, 0.0, 1.0)
		var fire_target := maxf(
			clampf(flame_intensity * 18.0, 0.0, 1.0),
			clampf(burned_fraction * fire_window * 1.15, 0.0, 1.0)
		)
		var exhaust_fill := 0.0
		if phase >= 180.0 and phase < 360.0:
			exhaust_fill = clampf((phase - 180.0) / 180.0, 0.0, 1.0) * 0.92
		var transition_smoke := 0.0
		if phase >= 110.0 and phase < 180.0:
			transition_smoke = clampf((phase - 110.0) / 70.0, 0.0, 1.0) * 0.5
		var smoke_target := maxf(
			clampf(smoke_intensity * 2.5, 0.0, 1.0),
			maxf(exhaust_fill, transition_smoke)
		)
		var part: Dictionary = cylinder_parts[cylinder_index]
		var flame_fill := float(part.flame_fill)
		var smoke_fill := float(part.smoke_fill)
		var flame_blend := flame_rise_blend if fire_target > flame_fill else flame_fall_blend
		var smoke_blend := smoke_rise_blend if smoke_target > smoke_fill else smoke_fall_blend
		flame_fill = lerpf(flame_fill, fire_target, flame_blend)
		smoke_fill = lerpf(smoke_fill, smoke_target, smoke_blend)
		part.flame_fill = flame_fill
		part.smoke_fill = smoke_fill
		cylinder_parts[cylinder_index] = part

		var chamber_top := piston_top_y + 0.15
		var chamber_height := maxf(chamber_top - piston_y, 0.035)
		var fluid_volume: MeshInstance3D = part.fluid_volume
		fluid_volume.position = Vector3(
			part.x,
			(piston_y + chamber_top) * 0.5,
			0.04
		)
		fluid_volume.scale = Vector3(1.0, chamber_height, 1.0)
		fluid_volume.visible = flame_fill > 0.015 or smoke_fill > 0.015
		var fluid_material: ShaderMaterial = part.fluid_material
		fluid_material.set_shader_parameter("flame_fill", flame_fill)
		fluid_material.set_shader_parameter("smoke_fill", smoke_fill)
		fluid_material.set_shader_parameter("flow_time", fluid_time)
		fluid_material.set_shader_parameter("flow_offset", part.flow_offset)
		var glow: MeshInstance3D = part.glow
		glow.visible = flame_fill > 0.015
		glow.scale = Vector3(
			maxf(flame_fill, 0.04) * 0.9,
			maxf(flame_fill, 0.04) * 1.5,
			maxf(flame_fill, 0.04) * 0.9
		)
		part.chamber_light.light_energy = flame_fill * 4.5
		part.red_flame_light.light_energy = flame_fill * 3.5

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

	_update_selection_info()
	_refresh_highlights()


func _refresh_highlights() -> void:
	for cylinder_index in range(cylinder_parts.size()):
		var part: Dictionary = cylinder_parts[cylinder_index]
		var highlighted := (
			hovered_cylinder_index == cylinder_index or
			selected_cylinder_index == cylinder_index
		)
		var overlay: Material = hover_material if highlighted else null
		var liner: MeshInstance3D = part.liner
		var liner_rim: MeshInstance3D = part.liner_rim
		var piston: MeshInstance3D = part.piston
		liner.material_overlay = overlay
		liner_rim.material_overlay = overlay
		piston.material_overlay = overlay
		for ring in part.piston_rings:
			var piston_ring: MeshInstance3D = ring
			piston_ring.material_overlay = overlay
	if is_instance_valid(crankshaft_mesh):
		crankshaft_mesh.material_overlay = (
			hover_material
			if hovered_crankshaft or selected_crankshaft
			else null
		)


func _update_selection_info() -> void:
	if not is_instance_valid(info_panel) or simulator == null:
		return
	if selected_cylinder_index >= 0:
		var pressure_kpa := simulator.get_cylinder_pressure_kpa(selected_cylinder_index)
		var temperature_k := simulator.get_cylinder_temperature_k(selected_cylinder_index)
		var stage := simulator.get_cylinder_stage(selected_cylinder_index)
		info_label.text = (
			"CYLINDER %02d\nPRESSURE  %.1f bar  (%.0f kPa)\n"
			+ "TEMPERATURE  %.0f K\nCYCLE  %s"
		) % [
			selected_cylinder_index + 1,
			pressure_kpa / 100.0,
			pressure_kpa,
			temperature_k,
			stage,
		]
		info_panel.visible = true
	elif selected_crankshaft:
		info_label.text = (
			"CRANKSHAFT\nTORQUE  %.1f N·m\nSPEED  %.0f RPM  (%.1f rad/s)"
		) % [
			simulator.output_torque,
			simulator.rpm,
			simulator.angular_velocity,
		]
		info_panel.visible = true
	else:
		info_panel.visible = false


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


func _create_fluid_shader() -> Shader:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;

uniform float flame_fill : hint_range(0.0, 1.0) = 0.0;
uniform float smoke_fill : hint_range(0.0, 1.0) = 0.0;
uniform float flow_time = 0.0;
uniform float flow_offset = 0.0;

void fragment() {
	float local_time = flow_time + flow_offset;
	float phase_a = UV.x * 34.0 + sin(UV.y * 18.0 - local_time * 2.7) * 2.4 + local_time * 5.0;
	float phase_b = UV.x * 51.0 - UV.y * 27.0 + sin(UV.x * 19.0 + local_time * 1.8) * 1.7;
	float turbulence = clamp(0.5 + sin(phase_a) * 0.29 + cos(phase_b) * 0.21, 0.0, 1.0);
	float flame_edge = clamp(flame_fill + (turbulence - 0.5) * 0.18, 0.0, 1.0);
	float flame_region = 1.0 - smoothstep(flame_edge - 0.06, flame_edge + 0.08, UV.y);
	float flame = flame_region * flame_fill * (0.65 + turbulence * 0.35);
	float smoke_edge = clamp(smoke_fill + (turbulence - 0.5) * 0.13, 0.0, 1.0);
	float smoke_region = 1.0 - smoothstep(smoke_edge - 0.08, smoke_edge + 0.12, UV.y);
	float smoke = smoke_region * smoke_fill * (0.32 + turbulence * 0.28);
	vec3 flame_color = mix(vec3(0.95, 0.018, 0.002), vec3(1.0, 0.19, 0.008), clamp(turbulence * 0.72 + UV.y * 0.12, 0.0, 1.0));
	vec3 smoke_color = mix(vec3(0.075, 0.085, 0.105), vec3(0.25, 0.28, 0.32), turbulence);
	float total = max(flame + smoke, 0.001);
	ALBEDO = (flame_color * flame + smoke_color * smoke) / total;
	ALPHA = clamp(flame * 0.94 + smoke * 0.42, 0.0, 0.94);
	EMISSION = flame_color * flame * 4.2;
}
"""
	return shader


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
