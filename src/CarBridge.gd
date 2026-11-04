extends Node

var bridge = null
var engine_running_seconds: float = 0.0


func _ready():

	var wrapper = Engine.get_singleton(
		"JavaClassWrapper"
	)

	if wrapper == null:
		print("JavaClassWrapper not found")
		return

	bridge = wrapper.wrap(
		"com.github.autodiag2.elm327emu.sim.CarBridge"
	)

	if bridge == null:
		print("Failed to wrap Kotlin CarBridge")
		return


func _process(delta):

	if bridge == null:
		return

	var car = get_tree().get_first_node_in_group(
		"player_car"
	)

	if car == null:
		return

	var engine = car.engine_controller
	var engine_parameters = engine.engine_parameters
	var throttle := engine.effective_throttle
	var engine_load := engine.calculate_engine_load(throttle)
	var engine_load_percent := engine_load * 100.0
	var reference_torque := maxf(
		engine_parameters.max_torque_nm,
		0.001
	)
	var throttle_percent := throttle * 100.0
	var fuel_tank_level := clampf(
		engine.fuel_litres /
		maxf(car.car_params.fuel_tank_size, 0.001) *
		100.0,
		0.0,
		100.0
	)

	var intake_manifold_pressure := engine_parameters.intake_pressure_kpa
	if engine_parameters.fuel_type == EngineParameters.FuelType.PETROL:
		intake_manifold_pressure *= lerpf(
			0.18,
			1.0,
			pow(clampf(throttle, 0.0, 1.0), 0.72)
		)

	var timing_advance := 0.0
	var commanded_equivalence_ratio := 1.0
	var fuel_injection_timing := 0.0
	if engine_parameters.fuel_type == EngineParameters.FuelType.PETROL:
		timing_advance = engine_parameters.ignition_advance_deg
	else:
		commanded_equivalence_ratio = (
			engine_parameters.stoichiometric_afr /
			maxf(engine_parameters.diesel_full_load_afr, 1.0) *
			throttle
		)
		fuel_injection_timing = engine_parameters.injection_advance_deg

	var fuel_rate_lph := _get_engine_fuel_rate_lph(
		engine,
		engine_load
	)
	var cylinder_fuel_rate := 0.0
	var firing_events_per_hour := (
		engine.rpm *
		30.0 *
		engine_parameters.get_cylinder_count()
	)
	if firing_events_per_hour > 0.0:
		cylinder_fuel_rate = (
			fuel_rate_lph *
			engine_parameters.fuel_density_kg_per_litre *
			1000000.0 /
			firing_events_per_hour
		)

	var driver_demand_torque := engine.calculate_torque(
		engine.rpm,
		throttle,
		car.car_params
	)
	var actual_engine_load_percent := (
		maxf(engine.output_torque, 0.0) /
		reference_torque *
		100.0
	)
	var friction_factor := 0.15 + 0.85 * clampf(
		engine.rpm / maxf(engine_parameters.max_rpm, 1.0),
		0.0,
		1.0
	)
	var friction_percent_torque := (
		-engine_parameters.friction_torque_nm *
		friction_factor /
		reference_torque *
		100.0
	)

	if engine.rpm > 0.0 and engine.fuel_litres > 0.0:
		engine_running_seconds += delta
	else:
		engine_running_seconds = 0.0

	bridge.setSignal(
		"SAEJ1979.engine_spark_or_compression",
		1.0 if engine_parameters.fuel_type == EngineParameters.FuelType.DIESEL else 0.0
	)

	bridge.setSignal(
		"SAEJ1979.engine_load",
		engine_load_percent
	)

	bridge.setSignal(
		"SAEJ1979.intake_manifold_pressure",
		intake_manifold_pressure
	)

	bridge.setSignal(
		"SAEJ1979.engine_speed",
		engine.rpm
	)

	bridge.setSignal(
		"SAEJ1979.vehicle_speed",
		car.getSpeedKmH()
	)

	bridge.setSignal(
		"SAEJ1979.timing_advance_cycle_1",
		timing_advance
	)

	bridge.setSignal(
		"SAEJ1979.intake_air_temperature",
		engine_parameters.intake_temperature_k - 273.15
	)

	bridge.setSignal(
		"SAEJ1979.throttle_position",
		throttle_percent
	)

	bridge.setSignal(
		"SAEJ1979.seconds_since_engine_start",
		engine_running_seconds
	)

	bridge.setSignal(
		"SAEJ1979.fuel_tank_level_input",
		fuel_tank_level
	)

	bridge.setSignal(
		"SAEJ1979.absolute_engine_load",
		actual_engine_load_percent
	)

	bridge.setSignal(
		"SAEJ1979.commanded_air_fuel_equivalence_ratio",
		commanded_equivalence_ratio
	)

	bridge.setSignal(
		"SAEJ1979.relative_throttle_position",
		throttle_percent
	)

	bridge.setSignal(
		"SAEJ1979.relative_accelerator_pedal_position",
		throttle_percent
	)

	bridge.setSignal(
		"SAEJ1979.max_intake_manifold_absolute_pressure",
		engine_parameters.intake_pressure_kpa
	)

	bridge.setSignal(
		"SAEJ1979.fuel_injection_timing",
		fuel_injection_timing
	)

	bridge.setSignal(
		"SAEJ1979.engine_fuel_rate",
		fuel_rate_lph
	)

	bridge.setSignal(
		"SAEJ1979.driver_demand_engine_percent_torque",
		driver_demand_torque / reference_torque * 100.0
	)

	bridge.setSignal(
		"SAEJ1979.actual_engine_percent_torque",
		engine.output_torque / reference_torque * 100.0
	)

	bridge.setSignal(
		"SAEJ1979.engine_reference_torque",
		reference_torque
	)

	bridge.setSignal(
		"SAEJ1979.engine_friction_percent_torque",
		friction_percent_torque
	)

	bridge.setSignal(
		"SAEJ1979.cylinder_fuel_rate",
		cylinder_fuel_rate
	)

	var psi := 30.0
	bridge.setTpmsSensor(
		"fl",
		psi,
		car.wheel_fl.tire_model.tire_temp
	)
	bridge.setTpmsSensor(
		"fr",
		psi,
		car.wheel_fl.tire_model.tire_temp
	)
	bridge.setTpmsSensor(
		"rl",
		psi,
		car.wheel_bl.tire_model.tire_temp
	)
	bridge.setTpmsSensor(
		"rr",
		psi,
		car.wheel_br.tire_model.tire_temp
	)


func _get_engine_fuel_rate_lph(engine, engine_load: float) -> float:
	if engine.rpm <= 0.0:
		return 0.0

	var bsfc := engine.bsfc_map.sample(
		engine.rpm,
		maxf(engine_load, 0.10)
	)
	return (
		bsfc *
		maxf(engine.simulator.mean_output_torque, 0.0) *
		engine.rpm /
		(
			engine.engine_parameters.fuel_density_kg_per_litre *
			9549.0 *
			1000.0
		)
	)
