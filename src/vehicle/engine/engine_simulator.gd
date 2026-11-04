class_name EngineSimulator
extends RefCounted

const ATMOSPHERIC_PRESSURE_PA: float = 101325.0
const AIR_GAS_CONSTANT: float = 287.05
const RPM_TO_DEGREES_PER_SECOND: float = 6.0
const RPM_PER_RADIAN_PER_SECOND: float = 60.0 / TAU
const CYCLE_DEGREES: float = 720.0
const MAX_SUBSTEP_DEGREES: float = 4.0
const AVERAGE_SAMPLE_COUNT: int = 72

var parameters: EngineParameters
var crank_angle_deg: float = 0.0
var rpm: float = 0.0
var angular_velocity: float = 0.0
var output_torque: float = 0.0
var mean_output_torque: float = 0.0
var last_throttle: float = 0.0
var cylinder_firing_offsets: Array[float] = []


func initialize(engine_parameters: EngineParameters, initial_rpm: float) -> void:
	parameters = engine_parameters
	rpm = initial_rpm
	angular_velocity = rpm / RPM_PER_RADIAN_PER_SECOND
	crank_angle_deg = 0.0
	output_torque = 0.0
	mean_output_torque = 0.0
	last_throttle = 0.0
	_build_firing_offsets()


func advance(
	delta: float,
	throttle_input: float,
	requested_mean_torque: float,
	reaction_torque: float
) -> float:
	if parameters == null or delta <= 0.0:
		return output_torque

	last_throttle = clampf(throttle_input, 0.0, 1.0)
	var average_pressure_torque := _calculate_average_pressure_torque(last_throttle)
	var angle_span := rpm * RPM_TO_DEGREES_PER_SECOND * delta
	var steps := maxi(1, int(ceil(angle_span / MAX_SUBSTEP_DEGREES)))
	steps = mini(steps, 128)
	var step_delta := delta / float(steps)
	var torque_sum := 0.0

	for step_index in range(steps):
		var angle_step := maxf(rpm, 0.0) * RPM_TO_DEGREES_PER_SECOND * step_delta
		var sample_angle := crank_angle_deg + angle_step * 0.5
		var pressure_torque := _calculate_pressure_torque(sample_angle, last_throttle)
		var pulse_ratio := 1.0

		if requested_mean_torque > 0.0 and average_pressure_torque > 0.001:
			var waveform_ratio := clampf(
				pressure_torque / average_pressure_torque,
				0.0,
				2.8
			)
			pulse_ratio = lerpf(
				1.0,
				waveform_ratio,
				parameters.torque_pulse_strength
			)

		var rpm_factor := clampf(rpm / maxf(parameters.max_rpm, 1.0), 0.0, 1.0)
		var friction_torque := parameters.friction_torque_nm * rpm_factor
		var torque := requested_mean_torque * pulse_ratio - friction_torque

		if rpm >= parameters.max_rpm and torque > 0.0:
			torque = 0.0

		torque_sum += torque
		var net_torque := torque + reaction_torque
		rpm = maxf(
			rpm + net_torque / maxf(parameters.inertia_kg_m2, 0.001) * RPM_PER_RADIAN_PER_SECOND * step_delta,
			0.0
		)
		rpm = minf(rpm, parameters.max_rpm)
		crank_angle_deg = fposmod(
			crank_angle_deg + rpm * RPM_TO_DEGREES_PER_SECOND * step_delta,
			CYCLE_DEGREES
		)

	output_torque = torque_sum / float(steps)
	var friction_at_current_speed := (
		parameters.friction_torque_nm *
		clampf(rpm / maxf(parameters.max_rpm, 1.0), 0.0, 1.0)
	)
	mean_output_torque = requested_mean_torque - friction_at_current_speed
	angular_velocity = rpm / RPM_PER_RADIAN_PER_SECOND
	return output_torque


func get_cylinder_phase(cylinder_index: int) -> float:
	if cylinder_index < 0 or cylinder_index >= cylinder_firing_offsets.size():
		return 0.0
	return fposmod(
		crank_angle_deg - cylinder_firing_offsets[cylinder_index],
		CYCLE_DEGREES
	)


func get_cylinder_pressure_kpa(cylinder_index: int) -> float:
	if parameters == null:
		return 0.0
	return _calculate_cylinder_pressure(
		get_cylinder_phase(cylinder_index),
		last_throttle
	) / 1000.0


func get_cylinder_combustion_intensity(cylinder_index: int) -> float:
	var progress := _get_combustion_progress(get_cylinder_phase(cylinder_index))
	if progress <= 0.0 or progress >= 1.0:
		return 0.0
	return clampf(4.0 * progress * (1.0 - progress), 0.0, 1.0)


func get_piston_displacement(phase_deg: float) -> float:
	if parameters == null:
		return 0.0
	var stroke := parameters.stroke_mm / 1000.0
	var crank_radius := stroke * 0.5
	var rod_length := crank_radius * parameters.connecting_rod_ratio
	var theta := deg_to_rad(fposmod(phase_deg, 360.0))
	return (
		crank_radius * (1.0 - cos(theta)) +
		rod_length -
		sqrt(maxf(
			rod_length * rod_length -
			crank_radius * crank_radius * sin(theta) * sin(theta),
			0.000000001
		))
	)


func _build_firing_offsets() -> void:
	cylinder_firing_offsets.clear()
	var cylinder_count := maxi(parameters.cylinder_count, 1)
	cylinder_firing_offsets.resize(cylinder_count)
	var valid_order := parameters.firing_order.size() == cylinder_count
	var seen: Dictionary = {}

	if valid_order:
		for cylinder_number in parameters.firing_order:
			if (
				cylinder_number < 1 or
				cylinder_number > cylinder_count or
				seen.has(cylinder_number)
			):
				valid_order = false
				break
			seen[cylinder_number] = true

	if valid_order:
		for event_index in range(cylinder_count):
			var cylinder_index: int = parameters.firing_order[event_index] - 1
			cylinder_firing_offsets[cylinder_index] = (
				float(event_index) * CYCLE_DEGREES / float(cylinder_count)
			)
	else:
		for cylinder_index in range(cylinder_count):
			cylinder_firing_offsets[cylinder_index] = (
				float(cylinder_index) * CYCLE_DEGREES / float(cylinder_count)
			)


func _calculate_average_pressure_torque(throttle_input: float) -> float:
	var total_torque := 0.0
	for sample_index in range(AVERAGE_SAMPLE_COUNT):
		var angle := (
			(float(sample_index) + 0.5) *
			CYCLE_DEGREES /
			float(AVERAGE_SAMPLE_COUNT)
		)
		total_torque += _calculate_pressure_torque(angle, throttle_input)
	return total_torque / float(AVERAGE_SAMPLE_COUNT)


func _calculate_pressure_torque(angle_deg: float, throttle_input: float) -> float:
	var total_torque := 0.0
	for cylinder_index in range(parameters.cylinder_count):
		var phase := fposmod(
			angle_deg - cylinder_firing_offsets[cylinder_index],
			CYCLE_DEGREES
		)
		total_torque += _calculate_cylinder_torque(phase, throttle_input)
	return total_torque


func _calculate_cylinder_torque(phase: float, throttle_input: float) -> float:
	var pressure := _calculate_cylinder_pressure(phase, throttle_input)
	var bore := parameters.bore_mm / 1000.0
	var area := PI * bore * bore * 0.25
	var crank_radius := parameters.stroke_mm / 2000.0
	var rod_length := crank_radius * parameters.connecting_rod_ratio
	var theta := deg_to_rad(fposmod(phase, 360.0))
	var sin_theta := sin(theta)
	var cos_theta := cos(theta)
	var rod_projection := sqrt(maxf(
		rod_length * rod_length -
		crank_radius * crank_radius * sin_theta * sin_theta,
		0.000000001
	))
	var piston_lever := (
		crank_radius * sin_theta +
		crank_radius * crank_radius * sin_theta * cos_theta /
		rod_projection
	)
	return (
		(pressure - ATMOSPHERIC_PRESSURE_PA) *
		area *
		piston_lever
	)


func _calculate_cylinder_pressure(phase: float, throttle_input: float) -> float:
	var bore := parameters.bore_mm / 1000.0
	var stroke := parameters.stroke_mm / 1000.0
	var area := PI * bore * bore * 0.25
	var swept_volume := area * stroke
	var clearance_volume := swept_volume / maxf(parameters.compression_ratio - 1.0, 0.1)
	var maximum_volume := clearance_volume + swept_volume
	var intake_pressure := ATMOSPHERIC_PRESSURE_PA

	if parameters.fuel_type == EngineParameters.FuelType.PETROL:
		intake_pressure *= lerpf(0.18, 1.0, throttle_input)

	var volume := clearance_volume + area * get_piston_displacement(phase)
	var air_mass := (
		intake_pressure *
		maximum_volume *
		parameters.volumetric_efficiency /
		(AIR_GAS_CONSTANT * maxf(parameters.intake_temperature_k, 1.0))
	)
	var air_fuel_ratio := parameters.stoichiometric_afr

	if parameters.fuel_type == EngineParameters.FuelType.DIESEL:
		air_fuel_ratio = lerpf(80.0, parameters.diesel_full_load_afr, throttle_input)
	else:
		air_fuel_ratio = lerpf(
			parameters.stoichiometric_afr,
			parameters.stoichiometric_afr * 0.88,
			throttle_input
		)

	var fuel_mass := air_mass / maxf(air_fuel_ratio, 1.0)
	var released_heat := (
		fuel_mass *
		parameters.lower_heating_value_mj_per_kg *
		1000000.0 *
		parameters.combustion_efficiency
	)
	var thermal_pressure := (
		(parameters.specific_heat_ratio - 1.0) *
		released_heat /
		maxf(clearance_volume, 0.000000001)
	)
	var compression_pressure := (
		intake_pressure *
		pow(maximum_volume / maxf(volume, 0.000000001), parameters.specific_heat_ratio)
	)
	var burn_progress := _get_combustion_progress(phase)
	var pressure := ATMOSPHERIC_PRESSURE_PA

	if phase < 180.0 or phase >= 540.0:
		pressure = (
			compression_pressure +
			thermal_pressure * burn_progress
		)
	elif phase < 360.0:
		pressure = parameters.exhaust_pressure_kpa * 1000.0
	else:
		pressure = intake_pressure

	return pressure


func _get_combustion_progress(phase: float) -> float:
	var advance := parameters.ignition_advance_deg
	var duration := parameters.combustion_duration_deg

	if parameters.fuel_type == EngineParameters.FuelType.DIESEL:
		advance = parameters.injection_advance_deg
		duration = maxf(duration, 45.0)

	var combustion_angle := fposmod(phase + advance, CYCLE_DEGREES)
	if combustion_angle >= duration:
		return 0.0
	var progress := combustion_angle / maxf(duration, 0.001)
	return 1.0 - exp(-5.0 * progress * progress * progress)
