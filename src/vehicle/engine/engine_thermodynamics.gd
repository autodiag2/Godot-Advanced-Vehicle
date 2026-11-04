class_name EngineThermodynamics
extends RefCounted

const ATMOSPHERIC_PRESSURE_PA: float = 101325.0
const AIR_GAS_CONSTANT: float = 287.05
const FUEL_GAS_CONSTANT: float = 180.0
const RPM_TO_DEGREES_PER_SECOND: float = 6.0
const RPM_PER_RADIAN_PER_SECOND: float = 60.0 / TAU
const CYCLE_DEGREES: float = 720.0
const MAX_SUBSTEP_DEGREES: float = 2.0
const MAX_SUBSTEPS: int = 96
const SMALL_MASS_KG: float = 0.000000001

var parameters: EngineParameters
var crank_angle_deg: float = 0.0
var rpm: float = 0.0
var angular_velocity: float = 0.0
var output_torque: float = 0.0
var mean_output_torque: float = 0.0
var last_throttle: float = 0.0
var cylinder_firing_offsets: Array[float] = []
var cylinder_states: Array[Dictionary] = []


func initialize(engine_parameters: EngineParameters, initial_rpm: float) -> void:
	parameters = engine_parameters
	crank_angle_deg = 0.0
	rpm = initial_rpm
	angular_velocity = rpm / RPM_PER_RADIAN_PER_SECOND
	output_torque = 0.0
	mean_output_torque = 0.0
	last_throttle = 0.0
	_build_firing_offsets()
	_build_initial_cylinder_states()


func set_rpm(value: float) -> void:
	rpm = clampf(value, 0.0, parameters.max_rpm)
	angular_velocity = rpm / RPM_PER_RADIAN_PER_SECOND


func set_cylinder_ignition_enabled(cylinder_index: int, enabled: bool) -> void:
	if (
		parameters == null or
		parameters.fuel_type != EngineParameters.FuelType.PETROL or
		cylinder_index < 0 or
		cylinder_index >= cylinder_states.size()
	):
		return
	var state: Dictionary = cylinder_states[cylinder_index]
	state.ignition_enabled = enabled
	cylinder_states[cylinder_index] = state


func is_cylinder_ignition_enabled(cylinder_index: int) -> bool:
	if cylinder_index < 0 or cylinder_index >= cylinder_states.size():
		return false
	return bool(cylinder_states[cylinder_index].get("ignition_enabled", true))


func advance(delta: float, throttle_input: float, reaction_torque: float) -> float:
	if parameters == null or delta <= 0.0:
		return output_torque

	last_throttle = clampf(throttle_input, 0.0, 1.0)
	var angle_span := rpm * RPM_TO_DEGREES_PER_SECOND * delta
	var steps := clampi(
		int(ceil(angle_span / MAX_SUBSTEP_DEGREES)),
		1,
		MAX_SUBSTEPS
	)
	var step_delta := delta / float(steps)
	var torque_sum := 0.0

	for _step_index in range(steps):
		var angle_step := maxf(rpm, 0.0) * RPM_TO_DEGREES_PER_SECOND * step_delta
		var cylinder_torque := 0.0

		for cylinder_index in range(cylinder_states.size()):
			var phase_before := get_cylinder_phase(cylinder_index)
			var phase_after := fposmod(
				phase_before + angle_step,
				CYCLE_DEGREES
			)
			var result := _advance_cylinder(
				cylinder_states[cylinder_index],
				phase_before,
				phase_after,
				angle_step,
				step_delta
			)
			cylinder_states[cylinder_index] = result.state
			cylinder_torque += result.torque

		var friction_factor := 0.15 + 0.85 * clampf(
			rpm / maxf(parameters.max_rpm, 1.0),
			0.0,
			1.0
		)
		var friction_torque := parameters.friction_torque_nm * friction_factor
		var step_torque := cylinder_torque - friction_torque
		step_torque = clampf(
			step_torque,
			-parameters.max_torque_nm * 0.5,
			parameters.max_torque_nm
		)
		torque_sum += step_torque

		var net_torque := step_torque + reaction_torque
		rpm = clampf(
			rpm +
			net_torque /
			maxf(parameters.inertia_kg_m2, 0.001) *
			RPM_PER_RADIAN_PER_SECOND *
			step_delta,
			0.0,
			parameters.max_rpm
		)
		crank_angle_deg = fposmod(
			crank_angle_deg + angle_step,
			CYCLE_DEGREES
		)

	output_torque = torque_sum / float(steps)
	var smoothing := 1.0 - exp(-delta / 0.18)
	mean_output_torque = lerpf(
		mean_output_torque,
		output_torque,
		smoothing
	)
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
	if cylinder_index < 0 or cylinder_index >= cylinder_states.size():
		return 0.0
	return float(cylinder_states[cylinder_index].pressure_pa) / 1000.0


func get_cylinder_temperature_k(cylinder_index: int) -> float:
	if cylinder_index < 0 or cylinder_index >= cylinder_states.size():
		return parameters.intake_temperature_k
	return float(cylinder_states[cylinder_index].temperature_k)


func get_cylinder_combustion_intensity(cylinder_index: int) -> float:
	if cylinder_index < 0 or cylinder_index >= cylinder_states.size():
		return 0.0
	return float(cylinder_states[cylinder_index].flame_intensity)


func get_cylinder_smoke_intensity(cylinder_index: int) -> float:
	if cylinder_index < 0 or cylinder_index >= cylinder_states.size():
		return 0.0
	return float(cylinder_states[cylinder_index].smoke_intensity)


func get_cylinder_burned_fraction(cylinder_index: int) -> float:
	if cylinder_index < 0 or cylinder_index >= cylinder_states.size():
		return 0.0
	return float(cylinder_states[cylinder_index].burned_fraction)


func get_cylinder_heat_release_kw(cylinder_index: int) -> float:
	if cylinder_index < 0 or cylinder_index >= cylinder_states.size():
		return 0.0
	return float(cylinder_states[cylinder_index].heat_release_w) / 1000.0


func get_cylinder_stage(cylinder_index: int) -> String:
	var phase := get_cylinder_phase(cylinder_index)
	if phase < 180.0:
		return "POWER"
	if phase < 360.0:
		return "EXHAUST"
	if phase < 540.0:
		return "INTAKE"
	return "COMPRESSION"


func get_piston_displacement(phase_deg: float) -> float:
	var stroke := parameters.stroke_mm / 1000.0
	var crank_radius := stroke * 0.5
	var rod_length := crank_radius * parameters.connecting_rod_ratio
	var theta := deg_to_rad(fposmod(phase_deg, 360.0))
	var sine := sin(theta)
	return (
		crank_radius * (1.0 - cos(theta)) +
		rod_length -
		sqrt(maxf(
			rod_length * rod_length -
			crank_radius * crank_radius * sine * sine,
			0.000000001
		))
	)


func get_cylinder_volume_m3(phase_deg: float) -> float:
	var bore := parameters.bore_mm / 1000.0
	var area := PI * bore * bore * 0.25
	var swept_volume := area * parameters.stroke_mm / 1000.0
	var clearance_volume := swept_volume / maxf(
		parameters.compression_ratio - 1.0,
		0.1
	)
	return clearance_volume + area * get_piston_displacement(phase_deg)


func _build_firing_offsets() -> void:
	cylinder_firing_offsets.clear()
	var count := maxi(parameters.cylinder_count, 1)
	cylinder_firing_offsets.resize(count)
	var valid_order := parameters.firing_order.size() == count
	var seen: Dictionary = {}

	if valid_order:
		for number in parameters.firing_order:
			if number < 1 or number > count or seen.has(number):
				valid_order = false
				break
			seen[number] = true

	if valid_order:
		for event_index in range(count):
			var cylinder_index: int = parameters.firing_order[event_index] - 1
			cylinder_firing_offsets[cylinder_index] = (
				float(event_index) * CYCLE_DEGREES / float(count)
			)
	else:
		for cylinder_index in range(count):
			cylinder_firing_offsets[cylinder_index] = (
				float(cylinder_index) * CYCLE_DEGREES / float(count)
			)


func _build_initial_cylinder_states() -> void:
	cylinder_states.clear()
	for cylinder_index in range(parameters.cylinder_count):
		var phase := get_cylinder_phase(cylinder_index)
		var volume := get_cylinder_volume_m3(phase)
		var intake_pressure := _get_intake_pressure_pa(0.6)
		var pressure := intake_pressure
		var temperature := parameters.intake_temperature_k
		var gamma := _get_gamma(temperature, 0.0)
		var bdc_volume := get_cylinder_volume_m3(180.0)

		if phase < 180.0:
			pressure = 6500000.0 * pow(
				get_cylinder_volume_m3(0.0) / maxf(volume, 0.000000001),
				gamma
			)
			temperature = 2100.0 * pow(
				get_cylinder_volume_m3(0.0) / maxf(volume, 0.000000001),
				gamma - 1.0
			)
		elif phase < 360.0:
			pressure = parameters.exhaust_pressure_kpa * 1000.0
			temperature = 850.0
		elif phase < 540.0:
			pressure = intake_pressure
			temperature = parameters.intake_temperature_k
		else:
			var compression_ratio := bdc_volume / maxf(volume, 0.000000001)
			pressure = intake_pressure * pow(compression_ratio, gamma)
			temperature = parameters.intake_temperature_k * pow(
				compression_ratio,
				gamma - 1.0
			)

		var mass := pressure * volume / (
			AIR_GAS_CONSTANT * maxf(temperature, 1.0)
		)
		var fuel_mass := 0.0
		if (
			parameters.fuel_type == EngineParameters.FuelType.PETROL and
			(phase >= 540.0 or phase < 35.0)
		):
			fuel_mass = mass / maxf(parameters.stoichiometric_afr, 1.0)

		cylinder_states.append({
			"mass_kg": maxf(mass, SMALL_MASS_KG),
			"fuel_mass_kg": fuel_mass,
			"air_mass_cycle_kg": mass,
			"temperature_k": clampf(temperature, 180.0, 3500.0),
			"pressure_pa": clampf(pressure, 20000.0, 20000000.0),
			"burned_fraction": 0.0,
			"flame_intensity": 0.0,
			"smoke_intensity": 0.0,
			"heat_release_w": 0.0,
			"indicated_work_j": 0.0,
			"ignition_enabled": true,
		})


func _advance_cylinder(
	state: Dictionary,
	phase_before: float,
	phase_after: float,
	angle_step: float,
	delta: float
) -> Dictionary:
	var volume_before := get_cylinder_volume_m3(phase_before)
	var volume_after := get_cylinder_volume_m3(phase_after)
	var volume_mid := (volume_before + volume_after) * 0.5
	var old_mass: float = maxf(state.mass_kg, SMALL_MASS_KG)
	var old_temperature: float = clampf(state.temperature_k, 180.0, 3500.0)
	var old_pressure: float = clampf(state.pressure_pa, 20000.0, 20000000.0)
	var old_fuel_mass: float = maxf(state.fuel_mass_kg, 0.0)
	var old_burned_fraction: float = float(state.burned_fraction)
	var cv_old := _get_cv(old_temperature, old_burned_fraction)
	var internal_energy := old_mass * cv_old * old_temperature
	var intake_pressure := _get_intake_pressure_pa(last_throttle)
	var exhaust_pressure := parameters.exhaust_pressure_kpa * 1000.0
	var intake_temperature := parameters.intake_temperature_k
	var exhaust_temperature := 850.0

	if phase_before < 360.0 and phase_after >= 360.0:
		state.air_mass_cycle_kg = 0.0
		state.fuel_mass_kg = 0.0
		state.burned_fraction = 0.0
		state.indicated_work_j = 0.0
		old_fuel_mass = 0.0
		old_burned_fraction = 0.0

	var intake_lift := _get_valve_lift(
		phase_before,
		parameters.intake_valve_open_deg,
		parameters.intake_valve_close_deg
	)
	var exhaust_lift := _get_valve_lift(
		phase_before,
		parameters.exhaust_valve_open_deg,
		parameters.exhaust_valve_close_deg
	)
	var intake_in_mass := 0.0
	var intake_out_mass := 0.0
	var exhaust_in_mass := 0.0
	var exhaust_out_mass := 0.0

	if intake_lift > 0.0:
		var intake_area := (
			PI *
			parameters.intake_valve_diameter_mm / 1000.0 *
			intake_lift
		)
		var intake_source_pressure := maxf(intake_pressure, old_pressure)
		var intake_sink_pressure := minf(intake_pressure, old_pressure)
		var intake_source_temperature := intake_temperature
		if old_pressure > intake_pressure:
			intake_source_temperature = old_temperature
		var intake_flow := _orifice_mass_flow(
			intake_area,
			intake_source_pressure,
			intake_sink_pressure,
			intake_source_temperature,
			AIR_GAS_CONSTANT,
			1.4
		)
		if intake_pressure >= old_pressure:
			intake_in_mass = intake_flow * delta
		else:
			intake_out_mass = intake_flow * delta

	if exhaust_lift > 0.0:
		var exhaust_area := (
			PI *
			parameters.exhaust_valve_diameter_mm / 1000.0 *
			exhaust_lift
		)
		var exhaust_source_pressure := maxf(old_pressure, exhaust_pressure)
		var exhaust_sink_pressure := minf(old_pressure, exhaust_pressure)
		var exhaust_source_temperature := old_temperature
		if exhaust_pressure > old_pressure:
			exhaust_source_temperature = exhaust_temperature
		var exhaust_flow := _orifice_mass_flow(
			exhaust_area,
			exhaust_source_pressure,
			exhaust_sink_pressure,
			exhaust_source_temperature,
			AIR_GAS_CONSTANT,
			_get_gamma(exhaust_source_temperature, old_burned_fraction)
		)
		if old_pressure >= exhaust_pressure:
			exhaust_out_mass = exhaust_flow * delta
		else:
			exhaust_in_mass = exhaust_flow * delta

	var fuel_in_mass := 0.0
	var diesel_injection_mass := 0.0
	if parameters.fuel_type == EngineParameters.FuelType.PETROL:
		fuel_in_mass = (
			intake_in_mass /
			maxf(parameters.stoichiometric_afr, 1.0)
		)
	else:
		var injection_before := _get_injection_progress(phase_before)
		var injection_after := _get_injection_progress(phase_after)
		var injection_delta := maxf(injection_after - injection_before, 0.0)
		var target_fuel_mass := (
			float(state.air_mass_cycle_kg) /
			maxf(parameters.diesel_full_load_afr, 1.0) *
			last_throttle
		)
		var remaining_injected_fuel := maxf(
			target_fuel_mass - old_fuel_mass,
			0.0
		)
		diesel_injection_mass = minf(
			remaining_injected_fuel,
			target_fuel_mass * injection_delta
		)

	var total_mass_out := minf(
		intake_out_mass + exhaust_out_mass,
		old_mass * 0.5
	)
	var unburned_fuel_out := minf(
		old_fuel_mass,
		old_fuel_mass * total_mass_out / old_mass
	)
	var fuel_available := maxf(
		old_fuel_mass -
		unburned_fuel_out +
		fuel_in_mass +
		diesel_injection_mass,
		0.0
	)

	var burn_before := _get_burn_progress(phase_before)
	var burn_after := _get_burn_progress(phase_after)
	var burn_delta := maxf(burn_after - burn_before, 0.0)
	if not bool(state.get("ignition_enabled", true)):
		burn_delta = 0.0
	var burn_remaining_fraction := maxf(1.0 - burn_before, 0.001)
	var burned_fuel_mass := minf(
		fuel_available,
		fuel_available * burn_delta / burn_remaining_fraction
	)
	var heat_release := (
		burned_fuel_mass *
		parameters.lower_heating_value_mj_per_kg *
		1000000.0 *
		parameters.combustion_efficiency
	)
	var new_fuel_mass := maxf(
		fuel_available - burned_fuel_mass,
		0.0
	)

	var total_mass_in := (
		intake_in_mass +
		exhaust_in_mass +
		fuel_in_mass +
		diesel_injection_mass
	)
	var new_mass := maxf(
		old_mass + total_mass_in - total_mass_out,
		SMALL_MASS_KG
	)
	var cp_old := cv_old + AIR_GAS_CONSTANT
	var intake_enthalpy := (
		intake_in_mass * 1005.0 * intake_temperature +
		exhaust_in_mass * cp_old * exhaust_temperature +
		(fuel_in_mass + diesel_injection_mass) *
		(1200.0 * intake_temperature)
	)
	var exhaust_enthalpy := total_mass_out * cp_old * old_temperature
	var heat_loss := _calculate_wall_heat_loss(
		old_pressure,
		old_temperature,
		volume_mid,
		delta,
		old_burned_fraction
	)
	var volume_change := volume_after - volume_before
	var preliminary_work := old_pressure * volume_change
	var new_internal_energy := (
		internal_energy +
		heat_release +
		intake_enthalpy -
		exhaust_enthalpy -
		heat_loss -
		preliminary_work
	)
	new_internal_energy = maxf(new_internal_energy, new_mass * 718.0 * 180.0)
	var preliminary_temperature := new_internal_energy / (
		new_mass * maxf(cv_old, 1.0)
	)
	var new_burned_fraction := clampf(
		old_burned_fraction + burn_delta,
		0.0,
		1.0
	)
	var cv_new := _get_cv(preliminary_temperature, new_burned_fraction)
	var new_temperature := clampf(
		new_internal_energy / (new_mass * cv_new),
		180.0,
		3500.0
	)
	var new_pressure := new_mass * AIR_GAS_CONSTANT * new_temperature / maxf(
		volume_after,
		0.0000000001
	)
	new_pressure = clampf(new_pressure, 20000.0, 20000000.0)
	var average_pressure := (old_pressure + new_pressure) * 0.5
	var corrected_work := average_pressure * volume_change
	new_internal_energy -= corrected_work - preliminary_work
	new_temperature = clampf(
		new_internal_energy /
		(new_mass * maxf(_get_cv(new_temperature, new_burned_fraction), 1.0)),
		180.0,
		3500.0
	)
	new_pressure = clampf(
		new_mass * AIR_GAS_CONSTANT * new_temperature / maxf(volume_after, 0.0000000001),
		20000.0,
		20000000.0
	)

	state.mass_kg = new_mass
	state.fuel_mass_kg = new_fuel_mass
	state.air_mass_cycle_kg = float(state.air_mass_cycle_kg) + intake_in_mass
	state.temperature_k = new_temperature
	state.pressure_pa = new_pressure
	state.burned_fraction = new_burned_fraction
	state.heat_release_w = heat_release / maxf(delta, 0.000001)
	state.flame_intensity = clampf(
		burn_delta / 0.045,
		0.0,
		1.0
	)
	var fuel_smoke_factor := 0.18
	if parameters.fuel_type == EngineParameters.FuelType.DIESEL:
		fuel_smoke_factor = 0.9
	state.smoke_intensity = clampf(
		state.flame_intensity * fuel_smoke_factor +
		(0.08 if phase_before > 180.0 and phase_before < 360.0 else 0.0),
		0.0,
		1.0
	)
	state.indicated_work_j = float(state.indicated_work_j) + corrected_work

	var angle_radians := deg_to_rad(maxf(angle_step, 0.0001))
	var torque := corrected_work / angle_radians
	return {
		"state": state,
		"torque": torque,
	}


func _get_intake_pressure_pa(throttle: float) -> float:
	var manifold_pressure := parameters.intake_pressure_kpa * 1000.0
	if parameters.fuel_type == EngineParameters.FuelType.PETROL:
		manifold_pressure *= lerpf(
			0.18,
			1.0,
			pow(clampf(throttle, 0.0, 1.0), 0.72)
		)
	return manifold_pressure


func _get_valve_lift(phase: float, open_angle: float, close_angle: float) -> float:
	if close_angle <= open_angle or phase < open_angle or phase > close_angle:
		return 0.0
	var position := (phase - open_angle) / (close_angle - open_angle)
	var lift_profile := pow(maxf(sin(PI * position), 0.0), 0.7)
	return (
		parameters.max_valve_lift_mm / 1000.0 *
		lift_profile
	)


func _orifice_mass_flow(
	area: float,
	pressure_upstream: float,
	pressure_downstream: float,
	temperature: float,
	gas_constant: float,
	gamma: float
) -> float:
	if area <= 0.0 or pressure_upstream <= pressure_downstream:
		return 0.0
	var upstream := maxf(pressure_upstream, 1.0)
	var downstream_ratio := clampf(
		pressure_downstream / upstream,
		0.0,
		1.0
	)
	var critical_ratio := pow(
		2.0 / (gamma + 1.0),
		gamma / (gamma - 1.0)
	)
	var mass_flux := 0.0
	if downstream_ratio <= critical_ratio:
		mass_flux = (
			upstream /
			sqrt(maxf(gas_constant * temperature, 1.0)) *
			sqrt(gamma) *
			pow(
				2.0 / (gamma + 1.0),
				(gamma + 1.0) / (2.0 * (gamma - 1.0))
			)
		)
	else:
		var flow_term := (
			pow(downstream_ratio, 2.0 / gamma) -
			pow(downstream_ratio, (gamma + 1.0) / gamma)
		)
		mass_flux = (
			upstream /
			sqrt(maxf(gas_constant * temperature, 1.0)) *
			sqrt(maxf(
				2.0 * gamma / (gamma - 1.0) * flow_term,
				0.0
			))
		)
	return (
		area *
		parameters.valve_discharge_coefficient *
		maxf(mass_flux, 0.0)
	)


func _calculate_wall_heat_loss(
	pressure: float,
	temperature: float,
	volume: float,
	delta: float,
	burned_fraction: float
) -> float:
	var bore := parameters.bore_mm / 1000.0
	var stroke := parameters.stroke_mm / 1000.0
	var piston_speed := 2.0 * stroke * rpm / 60.0
	var pressure_difference := maxf(
		pressure - _get_intake_pressure_pa(last_throttle),
		0.0
	)
	var gas_velocity := (
		2.28 * piston_speed +
		0.00324 *
		(pressure_difference / 1000.0) *
		(temperature / maxf(parameters.intake_temperature_k, 1.0))
	)
	gas_velocity = clampf(gas_velocity, 0.3, 80.0)
	var heat_transfer_coefficient := (
		3.26 *
		pow(maxf(bore, 0.001), -0.2) *
		pow(maxf(pressure / 1000.0, 1.0), 0.8) *
		pow(maxf(temperature, 180.0), -0.55) *
		pow(gas_velocity, 0.8)
	)
	var piston_area := PI * bore * bore * 0.25
	var chamber_height := maxf(volume / maxf(piston_area, 0.000001), 0.001)
	var heat_transfer_area := (
		2.0 * piston_area +
		PI * bore * chamber_height
	)
	var wall_temperature := parameters.wall_temperature_k
	var wall_heat_loss := (
		heat_transfer_coefficient *
		heat_transfer_area *
		(temperature - wall_temperature) *
		delta
	)
	return clampf(
		wall_heat_loss,
		0.0,
		maxf(temperature * 700.0 * delta, 0.0)
	)


func _get_burn_progress(phase: float) -> float:
	var ignition_advance := parameters.ignition_advance_deg
	var duration := parameters.combustion_duration_deg
	var start_angle := CYCLE_DEGREES - ignition_advance

	if parameters.fuel_type == EngineParameters.FuelType.DIESEL:
		ignition_advance = maxf(
			parameters.injection_advance_deg - parameters.diesel_ignition_delay_deg,
			0.0
		)
		start_angle = CYCLE_DEGREES - ignition_advance
		duration = maxf(duration, 35.0)

	var elapsed := _get_window_elapsed(phase, start_angle, duration)
	if elapsed < 0.0:
		return 0.0
	var normalized := clampf(elapsed / maxf(duration, 0.001), 0.0, 1.0)
	if parameters.fuel_type == EngineParameters.FuelType.PETROL:
		return _wiebe(normalized, parameters.wiebe_a, parameters.wiebe_shape)

	var premixed_duration := maxf(duration * 0.18, 4.0)
	var premixed := (
		parameters.diesel_premixed_fraction *
		_wiebe(
			clampf(elapsed / premixed_duration, 0.0, 1.0),
			parameters.wiebe_a,
			parameters.wiebe_shape
		)
	)
	var diffusion := (
		(1.0 - parameters.diesel_premixed_fraction) *
		_wiebe(normalized, 3.0, 1.0)
	)
	return clampf(premixed + diffusion, 0.0, 1.0)


func _get_injection_progress(phase: float) -> float:
	var duration := parameters.diesel_injection_duration_deg
	var start_angle := (
		CYCLE_DEGREES -
		parameters.injection_advance_deg -
		duration
	)
	var elapsed := _get_window_elapsed(phase, start_angle, duration)
	if elapsed < 0.0:
		return 0.0
	var normalized := clampf(elapsed / maxf(duration, 0.001), 0.0, 1.0)
	return normalized * normalized * (3.0 - 2.0 * normalized)


func _get_window_elapsed(phase: float, start_angle: float, duration: float) -> float:
	if phase >= start_angle:
		var elapsed := phase - start_angle
		if elapsed <= duration:
			return elapsed
		return -1.0
	var wrapped_end := start_angle + duration - CYCLE_DEGREES
	if wrapped_end >= 0.0 and phase <= wrapped_end:
		return phase + CYCLE_DEGREES - start_angle
	return -1.0


func _wiebe(progress: float, coefficient: float, shape: float) -> float:
	return 1.0 - exp(
		-coefficient *
		pow(clampf(progress, 0.0, 1.0), shape + 1.0)
	)


func _get_cp(temperature: float, burned_fraction: float) -> float:
	return clampf(
		1005.0 +
		0.13 * (temperature - 300.0) +
		90.0 * burned_fraction,
		1005.0,
		1450.0
	)


func _get_cv(temperature: float, burned_fraction: float) -> float:
	return maxf(_get_cp(temperature, burned_fraction) - AIR_GAS_CONSTANT, 650.0)


func _get_gamma(temperature: float, burned_fraction: float) -> float:
	var cp := _get_cp(temperature, burned_fraction)
	var cv := maxf(cp - AIR_GAS_CONSTANT, 1.0)
	return cp / cv
