extends GutTest


var engine: EngineController
var parameters: CarParameters
var car: RigidBody3D
var starter: EngineStarterController
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
	starter = EngineStarterController.new()
	engine = EngineController.new()
	parameters = CarParameters.new()
	car = RigidBody3D.new()
	audio_player = AudioStreamPlayer.new()

	get_tree().current_scene.add_child(audio_player)

	parameters.fuel_tank_size = 50.0
	parameters.fuel_percentage = 50.0
	parameters.engine.moment = 0.2
	parameters.engine.max_rpm = 8000.0
	parameters.engine.rpm_idle = 800.0
	parameters.engine.max_torque = 200.0
	parameters.engine.brake_torque = 20.0

	parameters.engine.torque_curve = Curve.new()
	parameters.engine.torque_curve.add_point(
		Vector2(0.0, 1.0)
	)
	parameters.engine.torque_curve.add_point(
		Vector2(1.0, 1.0)
	)

	parameters.engine.throttle_model = Curve.new()
	parameters.engine.throttle_model.add_point(
		Vector2(0.0, 0.0)
	)
	parameters.engine.throttle_model.add_point(
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
		engine.fuel_tank.fuel_litres,
		25.0
	)

func test_bsfc_consumption_differs_at_3000_rpm_between_10_and_100_percent_load() -> void:
	parameters.engine.bsfc_map = load(
		"res://assets/vehicle/sport_car/petrol_bsfc.tres"
	)

	engine.initialize(
		parameters,
		car,
		starter,
		audio_player
	)

	engine.rpm = 3000.0
	engine.combustion_running = true

	var bsfc_10 := parameters.engine.bsfc_map.sample(
		3000.0,
		0.10
	)

	var bsfc_100 := parameters.engine.bsfc_map.sample(
		3000.0,
		1.0
	)

	assert_gt(
		bsfc_10,
		bsfc_100
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
		engine.limiter_torque,
		0.0
	)

	assert_eq(
		engine.reaction_torque,
		0.0
	)

func test_initialize_stores_audio_player() -> void:
	assert_eq(
		engine.audio_player,
		audio_player
	)

func test_stop_stops_engine() -> void:
	engine.rpm = 2000.0
	engine.output_torque = 100.0
	engine.limiter_torque = 10.0
	engine.reaction_torque = 5.0
	engine.combustion_running = true

	engine.stop()

	assert_eq(
		engine.rpm,
		0.0
	)

	assert_eq(
		engine.output_torque,
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

	assert_eq(
		engine.calculate_combusion_torque(1.0),
		0.0
	)

	assert_false(
		engine.combustion_running
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
	engine.combustion_running = true
	var torque := engine.calculate_torque(
		1.0,
		4000.0
	)

	assert_float_eq(
		torque,
		192.0
	)

func test_calculate_torque_at_zero_throttle() -> void:
	var torque := engine.calculate_torque(
		0.0,
		4000.0
	)

	assert_float_eq(
		torque,
		-8.0
	)

func test_calculate_torque_at_half_throttle() -> void:
	engine.combustion_running = true
	var torque := engine.calculate_torque(
		0.5,
		4000.0
	)

	assert_float_eq(
		torque,
		92.0
	)

func test_calculate_torque_at_zero_rpm_has_engine_friction() -> void:
	var torque := engine.calculate_torque(
		0.0,
		0.0
	)

	assert_ne(
		torque,
		0.0
	)


func test_idle_control_produces_positive_torque_below_idle() -> void:
	var torque := engine.calculate_torque(
		0.0,
		400.0
	)

	assert_gt(
		torque,
		0.0
	)


func test_idle_control_is_zero_at_idle() -> void:
	var torque := engine.calculate_torque(
		0.0,
		parameters.engine.rpm_idle
	)

	assert_eq(
		torque,
		-4.16
	)


func test_update_accelerates_engine() -> void:
	engine.rpm = 1000.0
	engine.reaction_torque = 0.0
	engine.combustion_running = true

	var initial_angular_velocity := engine.angular_velocity

	engine.apply(
		1.0,
		0.1
	)

	assert_gt(
		engine.angular_velocity,
		initial_angular_velocity
	)


func test_update_uses_reaction_torque() -> void:
	engine.rpm = 3000.0
	engine.reaction_torque = 100.0

	var initial_angular_velocity := engine.angular_velocity

	engine.apply(
		1.0,
		0.1
	)

	assert_lt(
		engine.angular_velocity,
		initial_angular_velocity +
		(
			190.0 *
			0.1 /
			parameters.engine.moment
		)
	)


func test_update_can_stall_engine() -> void:
	engine.rpm = 1000.0
	engine.reaction_torque = 10000.0

	engine.apply(
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
	engine.reaction_torque = 10000.0

	engine.apply(
		0.0,
		0.01
	)

	assert_lt(
		engine.rpm,
		parameters.engine.rpm_idle
	)


func test_limiter_prevents_rpm_above_maximum() -> void:
	engine.rpm = 7900.0
	engine.reaction_torque = -10000.0

	engine.apply(
		1.0,
		0.1
	)

	assert_eq(
		engine.rpm,
		parameters.engine.max_rpm
	)

func test_torque_for_clutch() -> void:
	engine.start()
	for i in range(100):
		engine.apply(0.0, 0.2, 0.0)
	assert_gt(engine.rpm, parameters.engine.rpm_idle - 100.0)
	assert_lt(engine.rpm, parameters.engine.rpm_idle + 100.0)
	
	var clutch_seen_torque := engine.calculate_torque(1.0)
	assert_lt(0.0, clutch_seen_torque)

func test_limiter_generates_opposing_torque() -> void:
	engine.rpm = 7900.0
	engine.reaction_torque = -10000.0

	engine.apply(
		1.0,
		0.1
	)

	assert_gt(
		engine.limiter_torque,
		0.0
	)


func test_limiter_keeps_rotational_state_consistent() -> void:
	engine.rpm = 7900.0
	engine.reaction_torque = 10000.0

	engine.apply(
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

	engine.apply(
		1.0,
		0.1
	)

	assert_float_eq(
		engine.output_torque,
		180.3975
	)

func test_update_zero_delta_does_not_change_angular_velocity() -> void:
	engine.rpm = 3000.0

	var initial_angular_velocity := engine.angular_velocity

	engine.apply(
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
	engine.combustion_running = true
	
	var initial_fuel := engine.fuel_tank.fuel_litres

	engine.consume_fuel(
		1.0,
		1.0
	)

	assert_lt(
		engine.fuel_tank.fuel_litres,
		initial_fuel
	)


func test_consume_fuel_reduces_vehicle_mass() -> void:
	engine.rpm = 3000.0
	engine.output_torque = 100.0
	engine.combustion_running = true
	
	var initial_mass := car.mass

	engine.consume_fuel(
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
	engine.combustion_running = true

	var initial_fuel := engine.fuel_tank.fuel_litres
	var initial_mass := car.mass

	engine.consume_fuel(
		1.0,
		1.0
	)

	var fuel_consumed := initial_fuel - engine.fuel_tank.fuel_litres
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
	engine.combustion_running = true

	var initial_fuel := engine.fuel_tank.fuel_litres

	engine.consume_fuel(
		0.0,
		1.0
	)

	assert_eq(
		engine.fuel_tank.fuel_litres,
		initial_fuel
	)


func test_fuel_consumption_cannot_go_below_zero() -> void:
	engine.rpm = 8000.0
	engine.output_torque = 1000000.0
	engine.fuel_tank.fuel_litres = 0.001
	engine.combustion_running = true

	engine.consume_fuel(
		1.0,
		100.0
	)

	assert_eq(
		engine.fuel_tank.fuel_litres,
		0.0
	)


func test_update_sound_starts_engine_sound() -> void:
	parameters.engine.sound = AudioStreamGenerator.new()
	engine.initialize(parameters, car, starter, audio_player)
	engine.rpm = parameters.engine.rpm_idle
	engine.update_sound()

	assert_true(
		audio_player.playing
	)

func test_idle_fuel_consumption_uses_idle_fuel_rate() -> void:
	parameters.engine.idle_fuel_rate = 0.8

	engine.initialize(
		parameters,
		car,
		starter,
		audio_player
	)

	engine.rpm = parameters.engine.rpm_idle
	engine.combustion_running = true
	engine.output_torque = 0.0

	var fuel_before := engine.fuel_tank.fuel_litres

	engine.consume_fuel(
		0.0,
		3600.0
	)

	var fuel_consumed := fuel_before - engine.fuel_tank.fuel_litres

	assert_almost_eq(
		fuel_consumed,
		parameters.engine.idle_fuel_rate,
		0.000001
	)

func test_no_load_fuel_consumption_increases_with_rpm() -> void:
	parameters.engine.idle_fuel_rate = 0.8

	engine.initialize(
		parameters,
		car,
		starter,
		audio_player
	)

	engine.combustion_running = true
	engine.output_torque = 0.0

	engine.rpm = 2000.0

	var fuel_before_2000 := engine.fuel_tank.fuel_litres

	engine.consume_fuel(
		1.0,
		1.0
	)

	var consumption_2000 := (
		fuel_before_2000 -
		engine.fuel_tank.fuel_litres
	)

	engine.fuel_tank.fuel_litres = fuel_before_2000
	engine.rpm = 6000.0
	engine.combustion_running = true

	var fuel_before_6000 := engine.fuel_tank.fuel_litres

	engine.consume_fuel(
		1.0,
		1.0
	)

	var consumption_6000 := (
		fuel_before_6000 -
		engine.fuel_tank.fuel_litres
	)

	assert_gt(
		consumption_6000,
		consumption_2000
	)

func test_update_sound_sets_pitch_from_rpm() -> void:
	parameters.engine.sound = AudioStreamGenerator.new()
	engine.initialize(parameters, car, starter, audio_player)
	engine.rpm = 2000.0

	engine.update_sound()

	assert_float_eq(
		audio_player.pitch_scale,
		2.0
	)


func test_update_sound_plays_below_idle() -> void:
	parameters.engine.sound = AudioStreamGenerator.new()
	engine.initialize(parameters, car, starter, audio_player)
	engine.rpm = parameters.engine.rpm_idle

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
	parameters.engine.sound = AudioStreamGenerator.new()
	engine.initialize(parameters, car, starter, audio_player)
	engine.rpm = parameters.engine.max_rpm - 1.0

	engine.update_sound()

	assert_true(
		audio_player.playing
	)

	engine.rpm = parameters.engine.max_rpm

	engine.update_sound()

	assert_true(
		audio_player.playing
	)


func test_stop_sound() -> void:
	parameters.engine.sound = AudioStreamGenerator.new()
	engine.initialize(parameters, car, starter, audio_player)
	engine.rpm = parameters.engine.rpm_idle

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

	engine.apply(
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

	engine.apply(
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

	engine.apply(
		0.0,
		0.001
	)

	assert_true(
		starter.active
	)

func test_starter_stops_when_engine_becomes_self_sustaining() -> void:
	engine.rpm = parameters.engine.rpm_idle
	assert_gt(
		engine.fuel_tank.fuel_litres,
		0.0
	)
	engine.start()
	assert_true(
		starter.active
	)
	for i in range(10):
		engine.apply(
			0.0,
			0.1
		)
	assert_false(
		starter.active
	)
	assert_true(engine.combustion_running)
	
func test_at_rest_engine_stays_around_idle():
	var idl_rpm := 800.0
	engine.parameters.rpm_idle = idl_rpm
	engine.start()
	for i in range(10):
		engine.apply(0.0, 0.1)
	assert_lt(engine.rpm, idl_rpm)

func test_engine_produces_no_combustion_torque_without_fuel() -> void:
	engine.rpm = parameters.engine.rpm_idle
	engine.fuel_tank.fuel_litres = 0.0

	engine.apply(
		1.0,
		0.0
	)

	assert_lte(
		engine.output_torque,
		0.0
	)

func test_running_engine_stalls_when_fuel_is_exhausted() -> void:
	engine.rpm = parameters.engine.rpm_idle
	engine.combustion_running = true
	engine.fuel_tank.fuel_litres = 0.0

	engine.apply(
		0.0,
		1.0
	)

	assert_false(
		engine.combustion_running
	)

func test_no_fuel_is_consumed_when_combustion_is_not_running() -> void:
	engine.initialize(
		parameters,
		car,
		starter,
		audio_player
	)

	engine.combustion_running = false
	engine.rpm = 3000.0
	engine.output_torque = 0.0

	var initial_fuel := engine.fuel_tank.fuel_litres
	var initial_mass := car.mass

	engine.consume_fuel(
		1.0,
		1.0
	)

	assert_eq(
		engine.fuel_tank.fuel_litres,
		initial_fuel
	)

	assert_eq(
		car.mass,
		initial_mass
	)


func test_fuel_cut_when_drivetrain_connected_and_throttle_closed() -> void:
	engine.initialize(
		parameters,
		car,
		starter,
		audio_player
	)

	engine.combustion_running = true
	engine.drivetrain_connected = true
	engine.rpm = parameters.engine.rpm_idle * 2.0
	engine.output_torque = 0.0

	var initial_fuel := engine.fuel_tank.fuel_litres

	engine.consume_fuel(
		0.0,
		1.0
	)

	assert_eq(
		engine.fuel_tank.fuel_litres,
		initial_fuel
	)


func test_closed_throttle_neutral_does_not_use_fuel_cut() -> void:
	engine.initialize(
		parameters,
		car,
		starter,
		audio_player
	)

	engine.combustion_running = true
	engine.drivetrain_connected = false
	engine.rpm = parameters.engine.rpm_idle * 2.0
	engine.output_torque = 0.0

	var initial_fuel := engine.fuel_tank.fuel_litres

	engine.consume_fuel(
		0.0,
		1.0
	)

	assert_lt(
		engine.fuel_tank.fuel_litres,
		initial_fuel
	)

func test_idle_to_normal_fuel_consumption_is_continuous() -> void:
	parameters.engine.idle_fuel_rate = 0.8

	engine.initialize(
		parameters,
		car,
		starter,
		audio_player
	)

	engine.combustion_running = true
	engine.output_torque = 0.0

	var blend_end := (
		parameters.engine.rpm_idle *
		(1.0 + EngineController.IDLE_BLEND_RPM_FACTOR)
	)

	engine.rpm = parameters.engine.rpm_idle

	var fuel_before_idle := engine.fuel_tank.fuel_litres

	engine.consume_fuel(
		0.0,
		1.0
	)

	var consumption_idle := (
		fuel_before_idle -
		engine.fuel_tank.fuel_litres
	)

	engine.fuel_tank.fuel_litres = fuel_before_idle
	engine.rpm = blend_end

	engine.consume_fuel(
		0.0,
		1.0
	)

	var consumption_blend_end := (
		fuel_before_idle -
		engine.fuel_tank.fuel_litres
	)

	assert_gt(
		consumption_idle,
		0.0
	)

	assert_gt(
		consumption_blend_end,
		0.0
	)


func test_set_drivetrain_connected_updates_state() -> void:
	engine.set_drivetrain_connected(true)

	assert_true(engine.drivetrain_connected)

	engine.set_drivetrain_connected(false)

	assert_false(engine.drivetrain_connected)


func test_update_applies_positive_reaction_torque() -> void:
	engine.rpm = 3000.0
	engine.combustion_running = true
	engine.reaction_torque = 100.0

	var initial_angular_velocity := engine.angular_velocity

	engine.apply(
		1.0,
		0.1
	)

	assert_gt(
		engine.angular_velocity,
		initial_angular_velocity
	)


func test_update_applies_negative_reaction_torque() -> void:
	engine.rpm = 3000.0
	engine.combustion_running = true
	engine.reaction_torque = 1000.0

	var initial_angular_velocity := engine.angular_velocity

	engine.apply(
		1.0,
		0.1
	)

	assert_lt(
		engine.angular_velocity,
		initial_angular_velocity
	)


func test_update_does_not_make_engine_spin_negative() -> void:
	engine.rpm = 100.0
	engine.reaction_torque = 10000.0

	engine.apply(
		0.0,
		0.1
	)

	assert_eq(
		engine.angular_velocity,
		0.0
	)


func test_update_limits_angular_velocity_to_zero_when_torque_is_negative() -> void:
	engine.rpm = 1.0
	engine.reaction_torque = 10000.0

	engine.apply(
		0.0,
		0.1
	)

	assert_gte(
		engine.angular_velocity,
		0.0
	)


func test_combustion_becomes_running_when_starter_reaches_idle() -> void:
	engine.rpm = parameters.engine.rpm_idle
	starter.start()

	engine.apply(
		0.0,
		0.001
	)

	assert_true(
		engine.combustion_running
	)


func test_combustion_does_not_start_below_idle_from_starter() -> void:
	engine.rpm = parameters.engine.rpm_idle * 0.5
	starter.start()

	engine.apply(
		0.0,
		0.001
	)

	assert_false(
		engine.combustion_running
	)


func test_running_engine_stops_combustion_when_rpm_reaches_zero() -> void:
	engine.rpm = 100.0
	engine.combustion_running = true
	engine.reaction_torque = 10000.0

	engine.apply(
		0.0,
		0.1
	)

	assert_eq(
		engine.rpm,
		0.0
	)

	assert_false(
		engine.combustion_running
	)


func test_throttle_has_no_combustion_torque_when_combustion_is_disabled() -> void:
	engine.rpm = parameters.engine.rpm_idle

	var torque := engine.calculate_torque(
		1.0,
		engine.rpm,
		false
	)

	assert_lt(
		torque,
		0.0
	)


func test_idle_control_increases_as_rpm_falls_below_idle() -> void:
	var torque_at_700 := engine.calculate_torque(
		0.0,
		700.0,
		true
	)

	var torque_at_400 := engine.calculate_torque(
		0.0,
		400.0,
		true
	)

	assert_gt(
		torque_at_400,
		torque_at_700
	)


func test_engine_friction_increases_with_rpm() -> void:
	var friction_at_idle := engine.calculate_friction_torque(
		parameters.engine.rpm_idle
	)

	var friction_at_high_rpm := engine.calculate_friction_torque(
		parameters.engine.max_rpm
	)

	assert_gt(
		friction_at_high_rpm,
		friction_at_idle
	)


func test_engine_friction_is_non_negative() -> void:
	var friction := engine.calculate_friction_torque(
		parameters.engine.max_rpm
	)

	assert_gte(
		friction,
		0.0
	)


func test_update_consumes_no_fuel_when_delta_is_zero() -> void:
	engine.rpm = 3000.0
	engine.combustion_running = true

	var initial_fuel := engine.fuel_tank.fuel_litres

	engine.apply(
		1.0,
		0.0
	)

	assert_eq(
		engine.fuel_tank.fuel_litres,
		initial_fuel
	)


func test_fuel_exhaustion_stops_engine_and_resets_rpm() -> void:
	engine.rpm = 3000.0
	engine.combustion_running = true
	engine.fuel_tank.fuel_litres = 0.000001

	engine.apply(
		1.0,
		1.0
	)

	assert_eq(
		engine.fuel_tank.fuel_litres,
		0.0
	)

	assert_eq(
		engine.rpm,
		0.0
	)

	assert_false(
		engine.combustion_running
	)


func test_engine_load_is_zero_without_combustion_torque() -> void:
	engine.rpm = 3000.0
	engine.combustion_running = false

	assert_eq(
		engine.calculate_engine_load(0.0),
		0.0
	)

func test_engine_load_is_clamped_to_one() -> void:
	engine.rpm = 3000.0
	engine.combustion_running = true

	assert_eq(
		engine.calculate_engine_load(1.0),
		1.0
	)


func test_engine_load_increases_with_combustion_torque() -> void:
	engine.rpm = 3000.0
	engine.combustion_running = true

	var low_load := engine.calculate_engine_load(0.25)
	var high_load := engine.calculate_engine_load(0.75)

	assert_gt(
		high_load,
		low_load
	)

func test_update_output_torque_is_zero_when_fuel_is_exhausted() -> void:
	engine.rpm = parameters.engine.rpm_idle
	engine.fuel_tank.fuel_litres = 0.0
	engine.combustion_running = true

	engine.apply(
		1.0,
		0.0
	)

	assert_float_eq(
		engine.output_torque,
		-engine.calculate_friction_torque(engine.rpm)
	)


func test_update_sound_stops_when_rpm_is_zero() -> void:
	parameters.engine.sound = AudioStreamGenerator.new()
	engine.initialize(parameters, car, starter, audio_player)

	engine.rpm = parameters.engine.rpm_idle
	engine.update_sound()

	assert_true(audio_player.playing)

	engine.rpm = 0.0
	engine.update_sound()

	assert_false(audio_player.playing)

func test_engine_inertia_affects_angular_acceleration() -> void:
	engine.rpm = 3000.0
	engine.combustion_running = true
	engine.reaction_torque = 0.0

	var initial_angular_velocity := engine.angular_velocity

	engine.apply(
		1.0,
		0.1
	)

	var acceleration := (
		engine.angular_velocity -
		initial_angular_velocity
	) / 0.1

	parameters.engine.moment *= 2.0
	engine.rpm = 3000.0
	engine.reaction_torque = 0.0

	initial_angular_velocity = engine.angular_velocity

	engine.apply(
		1.0,
		0.1
	)

	var doubled_inertia_acceleration := (
		engine.angular_velocity -
		initial_angular_velocity
	) / 0.1

	assert_gt(
		acceleration,
		doubled_inertia_acceleration
	)

	assert_almost_eq(
		acceleration,
		doubled_inertia_acceleration * 2.0,
		acceleration * 0.05
	)

func test_combustion_torque_is_zero_when_combustion_is_disabled() -> void:
	engine.rpm = 3000.0

	assert_eq(
		engine.calculate_combusion_torque(1.0),
		0.0
	)


func test_combustion_torque_increases_with_throttle() -> void:
	engine.rpm = 3000.0
	engine.combustion_running = true

	var low_torque := engine.calculate_combusion_torque(0.25)
	var high_torque := engine.calculate_combusion_torque(0.75)

	assert_gt(
		high_torque,
		low_torque
	)

func test_engine_torque() -> void:
	var delta := 0.01
	engine.reaction_torque = 0.0
	assert_float_eq(engine.rpm, 0.0)
	engine.apply(0.0, delta)
	assert_float_eq(engine.rpm, 0.0)
	engine.start()
	engine.apply(0.0, delta)
	var speed := engine.rpm
	assert_gt(speed, 0.0)
	engine.apply(1.0, delta)
	var speed2 := engine.rpm
	assert_gt(speed2, speed)
	assert_lt(speed2, engine.parameters.max_rpm)

func test_combustion_torque_is_zero_when_fuel_is_empty() -> void:
	engine.rpm = 3000.0
	engine.combustion_running = true
	engine.fuel_tank.fuel_litres = 0.0

	assert_eq(
		engine.calculate_combusion_torque(1.0),
		0.0
	)


func test_combustion_torque_reaches_max_torque_at_full_throttle() -> void:
	engine.rpm = 4000.0
	engine.combustion_running = true

	assert_float_eq(
		engine.calculate_combusion_torque(1.0),
		parameters.engine.max_torque
	)


func test_engine_load_is_zero_at_zero_throttle() -> void:
	engine.rpm = 3000.0
	engine.combustion_running = true

	assert_eq(
		engine.calculate_engine_load(0.0),
		0.0
	)


func test_engine_load_is_one_at_full_throttle() -> void:
	engine.rpm = 3000.0
	engine.combustion_running = true

	assert_eq(
		engine.calculate_engine_load(1.0),
		1.0
	)


func test_fuel_consumption_increases_with_engine_load() -> void:
	parameters.engine.bsfc_map = load(
		"res://assets/vehicle/sport_car/petrol_bsfc.tres"
	)

	engine.initialize(
		parameters,
		car,
		starter,
		audio_player
	)

	engine.rpm = 3000.0
	engine.combustion_running = true

	var fuel_before_low_load := engine.fuel_tank.fuel_litres
	engine.output_torque = engine.calculate_torque(
		0.25,
		3000.0
	)

	engine.consume_fuel(
		0.25,
		1.0
	)

	var consumption_low_load := (
		fuel_before_low_load -
		engine.fuel_tank.fuel_litres
	)

	engine.fuel_tank.fuel_litres = fuel_before_low_load

	var fuel_before_high_load := engine.fuel_tank.fuel_litres
	engine.output_torque = engine.calculate_torque(
		0.75,
		3000.0
	)

	engine.consume_fuel(
		0.75,
		1.0
	)

	var consumption_high_load := (
		fuel_before_high_load -
		engine.fuel_tank.fuel_litres
	)

	assert_gt(
		consumption_high_load,
		consumption_low_load
	)


func test_fuel_cut_does_not_activate_below_fuel_cut_rpm() -> void:
	engine.combustion_running = true
	engine.drivetrain_connected = true
	engine.rpm = parameters.engine.rpm_idle
	engine.output_torque = 0.0

	var initial_fuel := engine.fuel_tank.fuel_litres

	engine.consume_fuel(
		0.0,
		1.0
	)

	assert_lt(
		engine.fuel_tank.fuel_litres,
		initial_fuel
	)


func test_fuel_cut_does_not_activate_with_open_throttle() -> void:
	engine.combustion_running = true
	engine.drivetrain_connected = true
	engine.rpm = parameters.engine.rpm_idle * 2.0
	engine.output_torque = 0.0

	var initial_fuel := engine.fuel_tank.fuel_litres

	engine.consume_fuel(
		0.1,
		1.0
	)

	assert_lt(
		engine.fuel_tank.fuel_litres,
		initial_fuel
	)


func test_fuel_cut_activates_above_fuel_cut_rpm() -> void:
	engine.combustion_running = true
	engine.drivetrain_connected = true
	engine.rpm = (
		parameters.engine.rpm_idle *
		EngineController.FUEL_CUT_RPM_FACTOR
	) + 1.0
	engine.output_torque = 0.0

	var initial_fuel := engine.fuel_tank.fuel_litres

	engine.consume_fuel(
		0.0,
		1.0
	)

	assert_eq(
		engine.fuel_tank.fuel_litres,
		initial_fuel
	)


func test_engine_load_is_clamped_to_zero_for_negative_combustion_torque() -> void:
	engine.rpm = 3000.0
	engine.combustion_running = false

	assert_eq(
		engine.calculate_engine_load(0.0),
		0.0
	)


func test_reaction_torque_can_overcome_combustion_torque() -> void:
	engine.rpm = 3000.0
	engine.combustion_running = true
	engine.reaction_torque = 1000.0

	var initial_angular_velocity := engine.angular_velocity

	engine.apply(
		1.0,
		0.1
	)

	assert_lt(
		engine.angular_velocity,
		initial_angular_velocity
	)


func test_zero_reaction_torque_does_not_change_torque_calculation() -> void:
	engine.rpm = 3000.0
	engine.combustion_running = true
	engine.reaction_torque = 0.0

	var expected_torque := engine.calculate_torque(
		1.0,
		3000.0
	)

	engine.apply(
		1.0,
		0.0
	)

	assert_float_eq(
		engine.output_torque,
		expected_torque
	)
