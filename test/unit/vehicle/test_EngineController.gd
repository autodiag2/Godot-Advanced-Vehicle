extends GutTest


var engine: EngineController
var parameters: CarParameters
var car: RigidBody3D
var starter: EngineStarterController = EngineStarterController.new()
var audio_player: AudioStreamPlayer


func assert_float_eq(
	one: float,
	two: float,
	threshold: float = 0.000001
) -> void:
	assert_almost_eq(
		one,
		two,
		threshold
	)


func before_each() -> void:
	engine = EngineController.new()
	parameters = CarParameters.new()
	car = RigidBody3D.new()
	audio_player = AudioStreamPlayer.new()

	get_tree().current_scene.add_child(audio_player)

	parameters.fuel_tank_size = 50.0
	parameters.fuel_percentage = 50.0
	parameters.engine_moment = 0.2
	parameters.max_engine_rpm = 8000.0
	parameters.rpm_idle = 800.0
	parameters.max_torque = 200.0
	parameters.engine_brake = 20.0

	parameters.torque_curve = Curve.new()
	parameters.torque_curve.add_point(
		Vector2(0.0, 1.0)
	)
	parameters.torque_curve.add_point(
		Vector2(1.0, 1.0)
	)

	parameters.throttle_model = Curve.new()
	parameters.throttle_model.add_point(
		Vector2(0.0, 0.0)
	)
	parameters.throttle_model.add_point(
		Vector2(1.0, 1.0)
	)

	engine.initialize(
		parameters,
		car,
		starter,
		audio_player
	)


func after_each() -> void:
	car.free()
	audio_player.queue_free()


func test_initialize_sets_fuel() -> void:
	assert_float_eq(
		engine.fuel_litres,
		25.0
	)

func test_bsfc_consumption_differs_at_3000_rpm_between_10_and_100_percent_load() -> void:
	parameters.engine_bsfc_map = load(
		"res://assets/vehicle/sport_car/petrol_bsfc.tres"
	)

	engine.initialize(
		parameters,
		car,
		starter,
		audio_player
	)

	engine.rpm = 3000.0

	engine.combustion_torque = (
		parameters.max_torque *
		0.10
	)
	engine.output_torque = engine.combustion_torque

	var fuel_before_10 := engine.fuel_litres

	engine.consume_fuel(
		car,
		1.0,
		1.0
	)

	var consumption_10 := fuel_before_10 - engine.fuel_litres
	var mechanical_power_10 := (
		engine.output_torque *
		engine.angular_velocity /
		EngineController.WATTS_PER_KILOWATT
	)
	var normalized_consumption_10 := (
		consumption_10 /
		mechanical_power_10
	)

	engine.fuel_litres = fuel_before_10
	engine.rpm = 3000.0

	engine.combustion_torque = (
		parameters.max_torque *
		1.0
	)
	engine.output_torque = engine.combustion_torque

	var fuel_before_100 := engine.fuel_litres

	engine.consume_fuel(
		car,
		1.0,
		1.0
	)

	var consumption_100 := fuel_before_100 - engine.fuel_litres
	var mechanical_power_100 := (
		engine.output_torque *
		engine.angular_velocity /
		EngineController.WATTS_PER_KILOWATT
	)
	var normalized_consumption_100 := (
		consumption_100 /
		mechanical_power_100
	)

	assert_gt(
		normalized_consumption_10,
		normalized_consumption_100
	)

func test_initialize_adds_fuel_mass() -> void:
	var expected_mass := (
		1.0 +
		25.0 *
		EngineController.PETROL_KG_PER_LITRE
	)

	assert_float_eq(
		car.mass,
		expected_mass
	)


func test_initialize_resets_rotational_state() -> void:
	engine.angular_velocity = 100.0
	engine.output_torque = 100.0
	engine.net_torque = 100.0
	engine.limiter_torque = 100.0
	engine.reaction_torque = 100.0

	engine.initialize(
		parameters,
		car,
		starter,
		audio_player
	)

	assert_eq(
		engine.angular_velocity,
		0.0
	)

	assert_eq(
		engine.output_torque,
		0.0
	)

	assert_eq(
		engine.net_torque,
		0.0
	)

	assert_eq(
		engine.limiter_torque,
		0.0
	)

	assert_eq(
		engine.reaction_torque,
		0.0
	)


func test_initialize_stores_audio_player() -> void:
	assert_eq(
		engine.engine_audio_player,
		audio_player
	)


func test_rpm_is_derived_from_angular_velocity() -> void:
	engine.angular_velocity = 100.0

	assert_float_eq(
		engine.rpm,
		100.0 *
		EngineController.RPM_PER_RADIAN_PER_SECOND
	)


func test_rpm_setter_updates_angular_velocity() -> void:
	engine.rpm = 3000.0

	assert_float_eq(
		engine.angular_velocity,
		3000.0 /
		EngineController.RPM_PER_RADIAN_PER_SECOND
	)


func test_rpm_and_angular_velocity_are_consistent() -> void:
	engine.rpm = 3000.0

	assert_float_eq(
		engine.rpm,
		engine.angular_velocity *
		EngineController.RPM_PER_RADIAN_PER_SECOND
	)


func test_calculate_torque_at_full_throttle() -> void:
	var torque := engine.calculate_torque(
		4000.0,
		1.0
	)

	assert_float_eq(
		torque,
		190.0
	)


func test_calculate_torque_at_zero_throttle() -> void:
	var torque := engine.calculate_torque(
		4000.0,
		0.0
	)

	assert_float_eq(
		torque,
		-10.0
	)


func test_calculate_torque_at_half_throttle() -> void:
	var torque := engine.calculate_torque(
		4000.0,
		0.5
	)

	assert_float_eq(
		torque,
		90.0
	)


func test_calculate_torque_at_zero_rpm_has_no_engine_friction() -> void:
	var torque := engine.calculate_torque(
		0.0,
		0.0
	)

	assert_eq(
		torque,
		0.0
	)


func test_idle_control_produces_positive_torque_below_idle() -> void:
	var torque := engine.calculate_torque(
		400.0,
		0.0
	)

	assert_gt(
		torque,
		0.0
	)


func test_idle_control_is_zero_at_idle() -> void:
	var torque := engine.calculate_torque(
		parameters.rpm_idle,
		0.0
	)

	assert_eq(
		torque,
		-parameters.engine_brake *
		parameters.rpm_idle /
		parameters.max_engine_rpm
	)


func test_update_accelerates_engine() -> void:
	engine.rpm = 1000.0
	engine.reaction_torque = 0.0
	engine.combustion_running = true

	var initial_angular_velocity := engine.angular_velocity

	engine.update(
		car,
		1.0,
		0.1
	)

	assert_gt(
		engine.angular_velocity,
		initial_angular_velocity
	)


func test_update_uses_reaction_torque() -> void:
	engine.rpm = 3000.0
	engine.reaction_torque = -100.0

	var initial_angular_velocity := engine.angular_velocity

	engine.update(
		car,
		1.0,
		0.1
	)

	assert_lt(
		engine.angular_velocity,
		initial_angular_velocity +
		(
			190.0 *
			0.1 /
			parameters.engine_moment
		)
	)


func test_update_can_stall_engine() -> void:
	engine.rpm = 1000.0
	engine.reaction_torque = -10000.0

	engine.update(
		car,
		0.0,
		0.1
	)

	assert_eq(
		engine.angular_velocity,
		0.0
	)

	assert_eq(
		engine.rpm,
		0.0
	)


func test_update_does_not_force_engine_to_idle() -> void:
	engine.rpm = 400.0
	engine.reaction_torque = -10000.0

	engine.update(
		car,
		0.0,
		0.01
	)

	assert_lt(
		engine.rpm,
		parameters.rpm_idle
	)


func test_limiter_prevents_rpm_above_maximum() -> void:
	engine.rpm = 7900.0
	engine.reaction_torque = 10000.0

	engine.update(
		car,
		1.0,
		0.1
	)

	assert_eq(
		engine.rpm,
		parameters.max_engine_rpm
	)


func test_limiter_generates_opposing_torque() -> void:
	engine.rpm = 7900.0
	engine.reaction_torque = 10000.0

	engine.update(
		car,
		1.0,
		0.1
	)

	assert_lt(
		engine.limiter_torque,
		0.0
	)


func test_limiter_keeps_rotational_state_consistent() -> void:
	engine.rpm = 7900.0
	engine.reaction_torque = 10000.0

	engine.update(
		car,
		1.0,
		0.1
	)

	assert_float_eq(
		engine.rpm,
		engine.angular_velocity *
		EngineController.RPM_PER_RADIAN_PER_SECOND
	)


func test_limiter_does_not_modify_output_torque() -> void:
	engine.rpm = 7900.0
	engine.reaction_torque = 10000.0
	engine.combustion_running = true

	engine.update(
		car,
		1.0,
		0.1
	)

	assert_float_eq(
		engine.output_torque,
		180.25
	)

func test_update_zero_delta_does_not_change_angular_velocity() -> void:
	engine.rpm = 3000.0

	var initial_angular_velocity := engine.angular_velocity

	engine.update(
		car,
		1.0,
		0.0
	)

	assert_float_eq(
		engine.angular_velocity,
		initial_angular_velocity
	)

func test_consume_fuel_reduces_fuel() -> void:
	engine.rpm = 3000.0
	engine.output_torque = 100.0

	var initial_fuel := engine.fuel_litres

	engine.consume_fuel(
		car,
		1.0,
		1.0
	)

	assert_lt(
		engine.fuel_litres,
		initial_fuel
	)


func test_consume_fuel_reduces_vehicle_mass() -> void:
	engine.rpm = 3000.0
	engine.output_torque = 100.0

	var initial_mass := car.mass

	engine.consume_fuel(
		car,
		1.0,
		1.0
	)

	assert_lt(
		car.mass,
		initial_mass
	)

func test_zero_output_torque_consumes_fuel_based_on_engine_friction() -> void:
	engine.rpm = 3000.0
	engine.output_torque = 0.0
	engine.combustion_torque = 0.0

	var initial_fuel := engine.fuel_litres
	var initial_mass := car.mass

	engine.consume_fuel(
		car,
		1.0,
		1.0
	)

	var fuel_consumed := initial_fuel - engine.fuel_litres
	var mass_consumed := initial_mass - car.mass

	assert_gt(
		fuel_consumed,
		0.0
	)

	assert_gt(
		mass_consumed,
		0.0
	)

	assert_almost_eq(
		mass_consumed,
		fuel_consumed * EngineController.PETROL_KG_PER_LITRE,
		0.000001
	)

func test_zero_angular_velocity_does_not_consume_fuel() -> void:
	engine.angular_velocity = 0.0
	engine.output_torque = 100.0

	var initial_fuel := engine.fuel_litres

	engine.consume_fuel(
		car,
		0.0,
		1.0
	)

	assert_eq(
		engine.fuel_litres,
		initial_fuel
	)


func test_fuel_consumption_cannot_go_below_zero() -> void:
	engine.rpm = 8000.0
	engine.output_torque = 1000000.0
	engine.fuel_litres = 0.001

	engine.consume_fuel(
		car,
		1.0,
		100.0
	)

	assert_eq(
		engine.fuel_litres,
		0.0
	)


func test_update_sound_starts_engine_sound() -> void:
	parameters.engine_sound = AudioStreamGenerator.new()
	engine.initialize(parameters, car, starter, audio_player)
	engine.rpm = parameters.rpm_idle
	engine.update_sound()

	assert_true(
		audio_player.playing
	)

func test_idle_fuel_consumption_uses_idle_fuel_rate() -> void:
	parameters.engine_idle_fuel_rate = 0.8

	engine.initialize(
		parameters,
		car,
		starter,
		audio_player
	)

	engine.rpm = parameters.rpm_idle
	engine.combustion_running = true
	engine.output_torque = 0.0

	var fuel_before := engine.fuel_litres

	engine.consume_fuel(
		car,
		0.0,
		3600.0
	)

	var fuel_consumed := fuel_before - engine.fuel_litres

	assert_almost_eq(
		fuel_consumed,
		parameters.engine_idle_fuel_rate,
		0.000001
	)

func test_no_load_fuel_consumption_increases_with_rpm() -> void:
	parameters.engine_idle_fuel_rate = 0.8

	engine.initialize(
		parameters,
		car,
		starter,
		audio_player
	)

	engine.combustion_running = true
	engine.output_torque = 0.0
	engine.combustion_torque = 0.0

	engine.rpm = 2000.0

	var fuel_before_2000 := engine.fuel_litres

	engine.consume_fuel(
		car,
		1.0,
		1.0
	)

	var consumption_2000 := (
		fuel_before_2000 -
		engine.fuel_litres
	)

	engine.fuel_litres = fuel_before_2000
	engine.rpm = 6000.0

	var fuel_before_6000 := engine.fuel_litres

	engine.consume_fuel(
		car,
		1.0,
		1.0
	)

	var consumption_6000 := (
		fuel_before_6000 -
		engine.fuel_litres
	)

	assert_gt(
		consumption_6000,
		consumption_2000
	)

func test_update_sound_sets_pitch_from_rpm() -> void:
	parameters.engine_sound = AudioStreamGenerator.new()
	engine.initialize(parameters, car, starter, audio_player)
	engine.rpm = 2000.0

	engine.update_sound()

	assert_float_eq(
		audio_player.pitch_scale,
		2.0
	)


func test_update_sound_plays_below_idle() -> void:
	parameters.engine_sound = AudioStreamGenerator.new()
	engine.initialize(parameters, car, starter, audio_player)
	engine.rpm = parameters.rpm_idle

	engine.update_sound()

	assert_true(
		audio_player.playing
	)

	engine.rpm = 500.0

	engine.update_sound()

	assert_true(
		audio_player.playing
	)


func test_update_sound_stops_at_maximum_rpm() -> void:
	parameters.engine_sound = AudioStreamGenerator.new()
	engine.initialize(parameters, car, starter, audio_player)
	engine.rpm = parameters.max_engine_rpm - 1.0

	engine.update_sound()

	assert_true(
		audio_player.playing
	)

	engine.rpm = parameters.max_engine_rpm

	engine.update_sound()

	assert_false(
		audio_player.playing
	)


func test_stop_sound() -> void:
	parameters.engine_sound = AudioStreamGenerator.new()
	engine.initialize(parameters, car, starter, audio_player)
	engine.rpm = parameters.rpm_idle

	engine.update_sound()

	assert_true(
		audio_player.playing
	)

	engine.stop_sound()

	assert_false(
		audio_player.playing
	)

func test_engine_does_not_start_from_zero_rpm_without_starter() -> void:
	engine.rpm = 0.0

	engine.update(
		car,
		1.0,
		0.1
	)

	assert_eq(
		engine.rpm,
		0.0
	)

func test_starter_increases_engine_rpm() -> void:
	engine.rpm = 0.0
	starter.start()

	engine.update(
		car,
		0.0,
		0.1
	)

	assert_gt(
		engine.rpm,
		0.0
	)

func test_starter_remains_active_below_idle() -> void:
	engine.rpm = 0.0
	starter.start()

	engine.update(
		car,
		0.0,
		0.001
	)

	assert_true(
		starter.active
	)

func test_starter_stops_when_engine_becomes_self_sustaining() -> void:
	engine.rpm = parameters.rpm_idle
	assert_gt(
		engine.fuel_litres,
		0.0
	)
	starter.start()
	assert_eq(
		engine.starter,
		starter
	)
	engine.update(
		car,
		0.0,
		0.001
	)

	assert_true(
		starter.active
	)
	
func test_engine_produces_no_combustion_torque_without_fuel() -> void:
	engine.rpm = parameters.rpm_idle
	engine.fuel_litres = 0.0

	engine.update(
		car,
		1.0,
		0.0
	)

	assert_lte(
		engine.output_torque,
		0.0
	)

func test_running_engine_stalls_when_fuel_is_exhausted() -> void:
	engine.rpm = parameters.rpm_idle
	engine.combustion_running = true
	engine.fuel_litres = 0.0

	engine.update(
		car,
		0.0,
		1.0
	)

	assert_false(
		engine.combustion_running
	)
