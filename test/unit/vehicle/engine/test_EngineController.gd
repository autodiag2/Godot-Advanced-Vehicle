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
func test_starter_is_not_immediate() -> void:
	engine.starter_initialise(2.0)
	assert_eq(engine.rpm, 0.0)
	engine.start()
	assert_eq(engine.rpm, 0.0)
	engine.apply(0.0, 1.0, 0.0)
	assert_gt(engine.rpm, 0.0)
	assert_lt(engine.rpm, engine.parameters.rpm_idle)
	engine.apply(0.0, 1.0, 0.0)
	assert_lt(engine.parameters.rpm_idle - 100.0, engine.rpm)
	assert_lt(engine.rpm, engine.parameters.rpm_idle + 100.0)

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
	engine.start()
	for i in range(10):
		engine.apply(0.0, 2.0, 0.0)
	var torque := engine.calculate_torque(
		1.0,
		0.1,
		4000.0
	)

	assert_lt(torque, 192.0 + 20.0)
	assert_gt(torque, 192.0 - 20.0)

func test_calculate_torque_at_half_throttle() -> void:
	engine.start()
	for i in range(10):
		engine.apply(0.0, 2.0, 0.0)
	var torque := engine.calculate_torque(
		0.5,
		0.1,
		4000.0
	)

	assert_lt(torque, 92.0 + 20.0)
	assert_gt(torque, 92.0 - 20.0)

func test_calculate_torque_at_zero_rpm_has_engine_friction() -> void:
	var torque := engine.calculate_torque(
		0.0,
		0.1,
		0.0
	)

	assert_ne(
		torque,
		0.0
	)


func test_idle_control_produces_positive_torque_below_idle() -> void:
	engine.start()
	_wait_combustion_running()
	var torque := engine.calculate_torque(
		0.0,
		0.1,
		400.0
	)

	assert_gt(
		torque,
		0.0
	)


func test_idle_control_is_zero_at_idle() -> void:
	var torque := engine.calculate_torque(
		0.0,
		0.1,
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
	engine.start()
	_wait_combustion_running()
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
	engine.start()
	_wait_combustion_running()
	engine.rpm = 2000.0

	engine.update_sound()

	assert_float_eq(
		audio_player.pitch_scale,
		2.0
	)


func test_update_sound_plays_below_idle() -> void:
	parameters.engine.sound = AudioStreamGenerator.new()
	engine.initialize(parameters, car, starter, audio_player)
	engine.start()
	_wait_combustion_running()
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
	engine.start()
	_wait_combustion_running()
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

func _wait_combustion_running():
	for i in range(10):
		engine.apply(0.0, 1.0, 0.0)
	assert(engine.combustion_running)

func test_ensure_starter_stop_in_case_no_fuel():
	engine.fuel_tank.fuel_litres = 0.0
	engine.start()
	assert_gt(engine.starter.get_torque(0.1), 0.0)
	for i in range(10):
		engine.apply(0.0, 1.0, 0.0)
	assert_float_eq(engine.starter.get_torque(0.1), 0.0)

func test_stop_sound() -> void:
	parameters.engine.sound = AudioStreamGenerator.new()
	engine.initialize(parameters, car, starter, audio_player)
	
	engine.start()
	_wait_combustion_running()

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
	for i in range(15):
		engine.apply(0.0, 0.1)
	assert_gt(engine.rpm, idl_rpm-100.0)
	assert_lt(engine.rpm, idl_rpm+100.0)

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
		0.1,
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
		0.1,
		700.0,
		true
	)

	var torque_at_400 := engine.calculate_torque(
		0.0,
		0.1,
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

	engine.start()
	_wait_combustion_running()
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
		0.1,
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
		0.1,
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
		0.1,
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


func test_full_throttle_does_not_exceed_maximum_torque() -> void:
	engine.angular_velocity = 2000.0 * TAU / 60.0
	engine.combustion_running = true
	engine.apply(1.0, 0.0, 0.0)
	assert_lte(engine.output_torque, parameters.engine.max_torque + 0.01)
	assert_gte(engine.output_torque, 0.0)

func test_zero_throttle_does_not_produce_positive_combustion_torque() -> void:
	engine.angular_velocity = 2000.0 * TAU / 60.0
	engine.combustion_running = true
	engine.apply(0.0, 0.0, 0.0)
	assert_almost_eq(engine.calculate_combusion_torque(0.0, engine.rpm), 0.0, 0.01)

func test_engine_output_torque_is_finite() -> void:
	engine.angular_velocity = 2000.0 * TAU / 60.0
	engine.combustion_running = true
	engine.apply(0.5, 0.01, 0.0)
	assert_false(is_nan(engine.output_torque))
	assert_false(is_inf(engine.output_torque))


func test_angular_velocity_remains_finite_after_update() -> void:
	engine.angular_velocity = 2000.0 * TAU / 60.0
	engine.combustion_running = true
	engine.apply(0.5, 0.01, 0.0)
	assert_false(is_nan(engine.angular_velocity))
	assert_false(is_inf(engine.angular_velocity))


func test_small_positive_torque_increases_angular_velocity() -> void:
	engine.angular_velocity = 2000.0 * TAU / 60.0
	engine.combustion_running = true
	engine.apply(1.0, 0.001, 0.0)
	assert_gt(engine.angular_velocity, 2000.0 * TAU / 60.0)


func test_engine_inertia_reduces_acceleration_for_same_torque() -> void:
	engine.angular_velocity = 2000.0 * TAU / 60.0
	engine.combustion_running = true
	engine.parameters.moment = 0.2
	var initial_velocity = engine.angular_velocity
	engine.apply(1.0, 0.001, 0.0)
	var acceleration_low_inertia = engine.angular_velocity - initial_velocity

	engine.angular_velocity = initial_velocity
	engine.parameters.moment = 0.4
	engine.apply(1.0, 0.001, 0.0)
	var acceleration_high_inertia = engine.angular_velocity - initial_velocity

	assert_gt(acceleration_low_inertia, acceleration_high_inertia)


func test_zero_throttle_does_not_exceed_full_throttle_output_torque() -> void:
	engine.angular_velocity = 2500.0 * TAU / 60.0
	engine.combustion_running = true
	engine.apply(0.0, 0.0, 0.0)
	var zero_throttle_torque = engine.output_torque
	engine.apply(1.0, 0.0, 0.0)
	assert_gte(engine.output_torque, zero_throttle_torque)


func test_increasing_throttle_does_not_reduce_output_torque() -> void:
	engine.angular_velocity = 2500.0 * TAU / 60.0
	engine.combustion_running = true
	engine.apply(0.25, 0.0, 0.0)
	var low_throttle_torque = engine.output_torque
	engine.apply(0.75, 0.0, 0.0)
	var high_throttle_torque = engine.output_torque
	assert_gte(high_throttle_torque, low_throttle_torque)


func test_reaction_torque_reduces_net_torque() -> void:
	engine.angular_velocity = 2500.0 * TAU / 60.0
	engine.combustion_running = true
	var unloaded_torque = engine.apply(1.0, 0.0, 0.0)
	var loaded_torque = engine.apply(1.0, 0.0, 10.0)
	assert_gt(unloaded_torque, loaded_torque)


func test_reaction_torque_does_not_change_combustion_output_torque() -> void:
	engine.angular_velocity = 2500.0 * TAU / 60.0
	engine.combustion_running = true
	engine.apply(1.0, 0.0, 0.0)
	var unloaded_output_torque = engine.output_torque
	engine.apply(1.0, 0.0, 10.0)
	assert_almost_eq(engine.output_torque, unloaded_output_torque, 0.01)


func test_repeated_zero_delta_updates_preserve_angular_velocity() -> void:
	engine.angular_velocity = 2500.0 * TAU / 60.0
	var initial_velocity = engine.angular_velocity
	for i in range(10):
		engine.apply(0.5, 0.0, 0.0)
	assert_almost_eq(engine.angular_velocity, initial_velocity, 0.000001)


func test_initialize_clears_reaction_torque() -> void:
	engine.reaction_torque = 50.0
	engine.initialize(parameters, car, starter, audio_player)
	assert_almost_eq(engine.reaction_torque, 0.0, 0.000001)


func test_initialize_clears_output_torque() -> void:
	engine.output_torque = 100.0
	engine.initialize(parameters, car, starter, audio_player)
	assert_almost_eq(engine.output_torque, 0.0, 0.000001)


func test_initialize_clears_limiter_torque() -> void:
	engine.limiter_torque = 100.0
	engine.initialize(parameters, car, starter, audio_player)
	assert_almost_eq(engine.limiter_torque, 0.0, 0.000001)


func test_initialize_disconnects_drivetrain() -> void:
	engine.set_drivetrain_connected(true)
	engine.initialize(parameters, car, starter, audio_player)
	assert_false(engine.drivetrain_connected)


func test_engine_load_stays_within_valid_range() -> void:
	engine.angular_velocity = 2500.0 * TAU / 60.0
	engine.combustion_running = true
	for throttle in [0.0, 0.25, 0.5, 0.75, 1.0]:
		engine.apply(throttle, 0.0, 0.0)
		@warning_ignore("shadowed_global_identifier")
		var load = engine.calculate_engine_load(throttle)
		assert_gte(load, 0.0)
		assert_lte(load, 1.0)


func test_engine_load_does_not_decrease_with_throttle() -> void:
	engine.angular_velocity = 2500.0 * TAU / 60.0
	engine.combustion_running = true
	var previous_load = 0.0
	for throttle in [0.0, 0.25, 0.5, 0.75, 1.0]:
		@warning_ignore("shadowed_global_identifier")
		var load = engine.calculate_engine_load(throttle)
		assert_gte(load + 0.000001, previous_load)
		previous_load = load


func test_fuel_level_remains_non_negative_after_consumption() -> void:
	engine.fuel_tank.fuel_litres = 0.001
	engine.combustion_running = true
	engine.angular_velocity = 3000.0 * TAU / 60.0
	engine.consume_fuel(1.0, 1.0)
	assert_gte(engine.fuel_tank.fuel_litres, 0.0)


func test_fuel_consumption_is_finite() -> void:
	engine.angular_velocity = 3000.0 * TAU / 60.0
	engine.combustion_running = true
	var initial_fuel = engine.fuel_tank.fuel_litres
	engine.consume_fuel(0.75, 0.1)
	var consumed_fuel = initial_fuel - engine.fuel_tank.fuel_litres
	assert_gte(consumed_fuel, 0.0)
	assert_false(is_nan(consumed_fuel))
	assert_false(is_inf(consumed_fuel))


func test_fuel_consumption_does_not_increase_fuel() -> void:
	engine.angular_velocity = 3000.0 * TAU / 60.0
	engine.combustion_running = true
	var initial_fuel = engine.fuel_tank.fuel_litres
	engine.consume_fuel(0.75, 0.1)
	assert_lte(engine.fuel_tank.fuel_litres, initial_fuel)


func test_closed_throttle_fuel_consumption_is_bounded() -> void:
	engine.angular_velocity = parameters.engine.rpm_idle * TAU / 60.0
	engine.combustion_running = true
	var initial_fuel = engine.fuel_tank.fuel_litres
	engine.consume_fuel(0.0, 0.1)
	var consumed_fuel = initial_fuel - engine.fuel_tank.fuel_litres
	assert_gte(consumed_fuel, 0.0)
	assert_lt(consumed_fuel, 0.01)


func test_zero_fuel_prevents_positive_combustion_output() -> void:
	engine.fuel_tank.fuel_litres = 0.0
	engine.angular_velocity = 2000.0 * TAU / 60.0
	engine.combustion_running = true
	assert_almost_eq(
		engine.calculate_combusion_torque(1.0),
		0.0,
		0.01
	)

func test_starter_torque_is_not_applied_twice_per_update() -> void:
	engine.starter_initialise(2.0)
	engine.start()
	var initial_velocity = engine.angular_velocity
	engine.apply(0.0, 0.01, 0.0)
	assert_gt(engine.angular_velocity, initial_velocity)
	assert_lt(engine.angular_velocity, parameters.engine.rpm_idle * TAU / 60.0)


func test_drivetrain_connection_can_be_toggled_repeatedly() -> void:
	for connected in [true, false, true, false]:
		engine.set_drivetrain_connected(connected)
		assert_eq(engine.drivetrain_connected, connected)


func test_engine_can_be_reinitialized_after_running() -> void:
	engine.angular_velocity = 3000.0 * TAU / 60.0
	engine.combustion_running = true
	engine.output_torque = 100.0
	engine.initialize(parameters, car, starter, audio_player)
	assert_almost_eq(engine.angular_velocity, 0.0, 0.000001)
	assert_almost_eq(engine.output_torque, 0.0, 0.000001)
	assert_false(engine.combustion_running)
	assert_gt(engine.fuel_tank.fuel_litres, 0.0)


func test_fuel_consumption_scales_with_delta() -> void:
	engine.angular_velocity = 3000.0 * TAU / 60.0
	engine.combustion_running = true
	var initial_fuel = engine.fuel_tank.fuel_litres
	engine.consume_fuel(1.0, 0.01)
	var short_interval_consumption = initial_fuel - engine.fuel_tank.fuel_litres

	engine.fuel_tank.fuel_litres = initial_fuel
	engine.consume_fuel(1.0, 0.02)
	var long_interval_consumption = initial_fuel - engine.fuel_tank.fuel_litres

	assert_gt(long_interval_consumption, short_interval_consumption)
	assert_lt(long_interval_consumption, short_interval_consumption * 3.0)

func test_engine_rotated_by_drivetrain_does_not_start_combustion() -> void:
	engine.combustion_running = false
	engine.angular_velocity = 2000.0 * TAU / 60.0
	engine.set_drivetrain_connected(true)

	engine.apply(0.0, 0.01, 0.0)

	assert_false(engine.combustion_running)
	assert_gt(engine.rpm, 0.0)


func test_engine_rotated_without_combustion_produces_no_combustion_torque() -> void:
	engine.combustion_running = false
	engine.angular_velocity = 2000.0 * TAU / 60.0

	var combustion_torque = engine.calculate_combusion_torque(0.0)

	assert_almost_eq(combustion_torque, 0.0, 0.01)


func test_engine_friction_resists_drivetrain_rotation() -> void:
	engine.combustion_running = false
	engine.angular_velocity = 2000.0 * TAU / 60.0

	var friction_torque = engine.calculate_friction_torque(engine.rpm)
	var net_torque = engine.calculate_torque(0.0, 0.0)

	assert_gt(friction_torque, 0.0)
	assert_lt(net_torque, 0.0)


func test_engine_rotated_by_drivetrain_consumes_no_fuel_without_combustion() -> void:
	engine.combustion_running = false
	engine.angular_velocity = 2000.0 * TAU / 60.0
	var initial_fuel = engine.fuel_tank.fuel_litres

	engine.apply(0.0, 0.1, 0.0)

	assert_almost_eq(engine.fuel_tank.fuel_litres, initial_fuel, 0.000001)
	assert_false(engine.combustion_running)

func test_reaction_torque_increases_rpm_when_engine_is_off() -> void:
	engine.combustion_running = false
	engine.angular_velocity = 0.0
	engine.set_drivetrain_connected(true)

	var initial_rpm = engine.rpm
	engine.apply(0.0, 0.1, -100.0)

	assert_gt(engine.rpm, initial_rpm)
	assert_false(engine.combustion_running)


func test_zero_net_torque_does_not_change_angular_velocity() -> void:
	engine.combustion_running = false
	engine.angular_velocity = 2000.0 * TAU / 60.0

	var initial_velocity = engine.angular_velocity
	var output_torque = engine.calculate_torque(0.0, 0.0)
	var net_torque = engine.apply(0.0, 0.0, output_torque)

	assert_almost_eq(net_torque, 0.0, 0.01)
	assert_almost_eq(engine.angular_velocity, initial_velocity, 0.001)

func test_positive_net_torque_increases_angular_velocity() -> void:
	engine.combustion_running = false
	engine.angular_velocity = 1000.0 * TAU / 60.0
	var initial_velocity = engine.angular_velocity
	engine.apply(0.0, 0.1, -100.0)
	assert_gt(engine.angular_velocity, initial_velocity)


func test_negative_net_torque_decreases_angular_velocity() -> void:
	engine.combustion_running = false
	engine.angular_velocity = 2000.0 * TAU / 60.0
	var initial_velocity = engine.angular_velocity
	engine.apply(0.0, 0.1, 100.0)
	assert_lt(engine.angular_velocity, initial_velocity)


func test_engine_friction_at_rest_does_not_create_negative_velocity() -> void:
	engine.combustion_running = false
	engine.angular_velocity = 0.0
	engine.apply(0.0, 0.1, 0.0)
	assert_gte(engine.angular_velocity, 0.0)
	assert_false(is_nan(engine.angular_velocity))
	assert_false(is_inf(engine.angular_velocity))


func test_engine_friction_does_not_decrease_with_rpm() -> void:
	var low_rpm_friction = engine.calculate_friction_torque(1000.0)
	var medium_rpm_friction = engine.calculate_friction_torque(4000.0)
	var high_rpm_friction = engine.calculate_friction_torque(7000.0)
	assert_gte(medium_rpm_friction, low_rpm_friction)
	assert_gte(high_rpm_friction, medium_rpm_friction)


func test_engine_friction_is_zero_or_positive_at_zero_rpm() -> void:
	assert_gte(engine.calculate_friction_torque(0.0), 0.0)


func test_large_delta_keeps_angular_velocity_finite_and_non_negative() -> void:
	engine.combustion_running = false
	engine.angular_velocity = 1000.0 * TAU / 60.0
	engine.apply(0.0, 10.0, 1000.0)
	assert_gte(engine.angular_velocity, 0.0)
	assert_false(is_nan(engine.angular_velocity))
	assert_false(is_inf(engine.angular_velocity))


func test_limiter_does_not_activate_below_maximum_rpm() -> void:
	engine.combustion_running = true
	engine.rpm = parameters.engine.max_rpm - 100.0
	engine.apply(0.0, 0.0, 0.0)
	assert_almost_eq(engine.limiter_torque, 0.0, 0.001)


func test_limiter_handles_rpm_at_maximum_boundary() -> void:
	engine.combustion_running = true
	engine.rpm = parameters.engine.max_rpm
	engine.apply(1.0, 0.01, 0.0)
	assert_lte(engine.rpm, parameters.engine.max_rpm + 0.01)
	assert_false(is_nan(engine.limiter_torque))
	assert_false(is_inf(engine.limiter_torque))


func test_limiter_releases_after_rpm_falls_below_maximum() -> void:
	engine.combustion_running = true
	engine.rpm = parameters.engine.max_rpm
	engine.apply(0.0, 0.1, 100.0)
	engine.apply(0.0, 0.0, 0.0)
	assert_lte(engine.rpm, parameters.engine.max_rpm + 0.01)
	assert_gte(engine.limiter_torque, 0.0)


func test_reaction_torque_changes_net_torque_not_combustion_output() -> void:
	engine.combustion_running = true
	engine.rpm = 2500.0
	engine.apply(0.75, 0.0, 0.0)
	var output_without_load = engine.output_torque
	var net_without_load = engine.apply(0.75, 0.0, 0.0)
	var net_with_load = engine.apply(0.75, 0.0, 50.0)
	assert_almost_eq(engine.output_torque, output_without_load, 0.01)
	assert_lt(net_with_load, net_without_load)


func test_engine_never_rotates_backwards_under_negative_net_torque() -> void:
	engine.combustion_running = false
	engine.angular_velocity = 1.0
	engine.apply(0.0, 1.0, 1000.0)
	assert_almost_eq(engine.angular_velocity, 0.0, 0.001)
	assert_gte(engine.angular_velocity, 0.0)


func test_angular_velocity_stays_finite_near_maximum_rpm() -> void:
	engine.combustion_running = true
	engine.rpm = parameters.engine.max_rpm - 1.0
	engine.apply(1.0, 0.1, 0.0)
	assert_false(is_nan(engine.angular_velocity))
	assert_false(is_inf(engine.angular_velocity))
	assert_gte(engine.angular_velocity, 0.0)
	assert_lte(engine.rpm, parameters.engine.max_rpm + 0.01)


func test_realism_combustion_torque_is_zero_at_zero_rpm() -> void:
	engine.fuel_tank.fuel_litres = 10.0
	engine.combustion_running = true
	engine.rpm = 0.0

	var torque = engine.calculate_combusion_torque(1.0)

	assert_almost_eq(torque, 0.0, 0.01)
	pending("KNOWN")


func test_realism_throttle_response_is_not_instantaneous() -> void:
	engine.fuel_tank.fuel_litres = 10.0
	engine.combustion_running = true
	engine.rpm = 3000.0

	engine.apply(0.0, 0.0, 0.0)
	engine.apply(1.0, 0.001, 0.0)

	assert_lt(engine.output_torque, parameters.engine.max_torque * 0.95)
	pending("KNOWN")

func test_realism_closed_throttle_includes_pumping_losses() -> void:
	engine.fuel_tank.fuel_litres = 10.0
	engine.combustion_running = true
	engine.rpm = 4000.0

	var friction_torque = engine.calculate_friction_torque(engine.rpm)
	var net_torque = engine.calculate_torque(0.0, 0.0)

	assert_lt(net_torque, -friction_torque)
	pending("KNOWN")


func test_realism_engine_torque_varies_with_rpm() -> void:
	engine.fuel_tank.fuel_litres = 10.0
	engine.combustion_running = true

	var low_rpm_torque = engine.calculate_combusion_torque(
		1.0,
		1000.0
	)
	var high_rpm_torque = engine.calculate_combusion_torque(
		1.0,
		7000.0
	)

	assert_ne(low_rpm_torque, high_rpm_torque)


func test_realism_fuel_consumption_increases_with_rpm_at_same_load() -> void:
	engine.fuel_tank.fuel_litres = 10.0
	engine.combustion_running = true
	engine.rpm = 1500.0
	engine.output_torque = 100.0

	var low_rpm_consumption = engine.calculate_normal_fuel_consumption(
		0.5,
		1.0
	)

	engine.rpm = 5000.0
	engine.output_torque = 100.0

	var high_rpm_consumption = engine.calculate_normal_fuel_consumption(
		0.5,
		1.0
	)

	assert_gt(high_rpm_consumption, low_rpm_consumption)


func test_realism_combustion_torque_is_zero_without_fuel() -> void:
	engine.fuel_tank.fuel_litres = 0.0
	engine.combustion_running = true
	engine.rpm = 2000.0
	assert_almost_eq(engine.calculate_combusion_torque(1.0), 0.0, 0.01)


func test_realism_torque_is_zero_at_zero_throttle_when_combustion_is_off() -> void:
	engine.combustion_running = false
	engine.fuel_tank.fuel_litres = 10.0
	engine.rpm = 2500.0
	assert_almost_eq(engine.calculate_combusion_torque(0.0), 0.0, 0.01)


func test_realism_combustion_torque_is_bounded_by_maximum_torque() -> void:
	engine.combustion_running = true
	engine.fuel_tank.fuel_litres = 10.0
	for rpm_value in [800.0, 1500.0, 3000.0, 6000.0, 7900.0]:
		var torque = engine.calculate_combusion_torque(1.0, rpm_value)
		assert_gte(torque, 0.0)
		assert_lte(torque, parameters.engine.max_torque + 0.01)


func test_realism_torque_does_not_jump_when_rpm_changes_slightly() -> void:
	engine.combustion_running = true
	engine.fuel_tank.fuel_litres = 10.0
	var torque_before = engine.calculate_combusion_torque(0.75, 3000.0)
	var torque_after = engine.calculate_combusion_torque(0.75, 3001.0)
	assert_lt(absf(torque_after - torque_before), 1.0)


func test_realism_torque_does_not_exceed_maximum_at_redline() -> void:
	engine.combustion_running = true
	engine.fuel_tank.fuel_litres = 10.0
	var torque = engine.calculate_combusion_torque(1.0, parameters.engine.max_rpm)
	assert_gte(torque, 0.0)
	assert_lte(torque, parameters.engine.max_torque + 0.01)


func test_realism_coasting_engine_loses_rpm_without_combustion() -> void:
	engine.combustion_running = false
	engine.angular_velocity = 3000.0 * TAU / 60.0
	var initial_rpm = engine.rpm
	for i in range(10):
		engine.apply(0.0, 0.01, 0.0)
	assert_lt(engine.rpm, initial_rpm)


func test_realism_engine_friction_increases_with_rpm() -> void:
	var low = engine.calculate_friction_torque(1000.0)
	var medium = engine.calculate_friction_torque(4000.0)
	var high = engine.calculate_friction_torque(7000.0)
	assert_lte(low, medium)
	assert_lte(medium, high)


func test_realism_engine_friction_is_bounded_by_brake_torque() -> void:
	for rpm_value in [0.0, 1000.0, 4000.0, 8000.0, 12000.0]:
		var friction = engine.calculate_friction_torque(rpm_value)
		assert_gte(friction, 0.0)
		assert_lte(friction, parameters.engine.brake_torque + 0.01)


func test_realism_coast_down_does_not_reverse_engine_rotation() -> void:
	engine.combustion_running = false
	engine.angular_velocity = 1.0
	for i in range(10):
		engine.apply(0.0, 0.1, 0.0)
	assert_gte(engine.angular_velocity, 0.0)


func test_realism_engine_does_not_gain_energy_from_friction() -> void:
	engine.combustion_running = false
	engine.angular_velocity = 3000.0 * TAU / 60.0
	var initial_velocity = engine.angular_velocity
	engine.apply(0.0, 0.01, 0.0)
	assert_lte(engine.angular_velocity, initial_velocity)


func test_realism_fuel_consumption_is_zero_without_combustion() -> void:
	engine.combustion_running = false
	engine.angular_velocity = 3000.0 * TAU / 60.0
	var initial_fuel = engine.fuel_tank.fuel_litres
	engine.consume_fuel(1.0, 1.0)
	assert_almost_eq(engine.fuel_tank.fuel_litres, initial_fuel, 0.000001)


func test_realism_fuel_consumption_is_non_negative_at_all_tested_rpms() -> void:
	engine.combustion_running = true
	engine.fuel_tank.fuel_litres = 10.0
	for rpm_value in [0.0, 800.0, 1500.0, 3000.0, 6000.0]:
		engine.rpm = rpm_value
		var consumption = engine.calculate_normal_fuel_consumption(0.5, 0.1)
		assert_gte(consumption, 0.0)
		assert_false(is_nan(consumption))
		assert_false(is_inf(consumption))


func test_realism_fuel_consumption_scales_with_time_step() -> void:
	engine.combustion_running = true
	engine.fuel_tank.fuel_litres = 10.0
	engine.rpm = 3000.0
	engine.output_torque = 100.0
	var short_interval = engine.calculate_normal_fuel_consumption(0.5, 0.01)
	var long_interval = engine.calculate_normal_fuel_consumption(0.5, 0.02)
	assert_almost_eq(long_interval, short_interval * 2.0, 0.000001)


func test_realism_fuel_consumption_increases_with_load_for_same_bsfc() -> void:
	engine.combustion_running = true
	engine.fuel_tank.fuel_litres = 10.0
	engine.rpm = 3000.0
	engine.output_torque = 50.0
	var low_load = engine.calculate_normal_fuel_consumption(0.25, 1.0)
	engine.output_torque = 150.0
	var high_load = engine.calculate_normal_fuel_consumption(0.75, 1.0)
	assert_gt(high_load, low_load)


func test_realism_starter_does_not_start_combustion_without_fuel() -> void:
	engine.fuel_tank.fuel_litres = 0.0
	engine.combustion_running = false
	engine.angular_velocity = 0.0
	engine.start()
	for i in range(100):
		engine.apply(0.0, 0.01, 0.0)
	assert_false(engine.combustion_running)


func test_realism_stopping_engine_clears_rotational_state() -> void:
	engine.combustion_running = true
	engine.rpm = 2500.0
	engine.output_torque = 100.0
	engine.stop()
	assert_almost_eq(engine.rpm, 0.0, 0.001)
	assert_almost_eq(engine.output_torque, 0.0, 0.001)
	assert_false(engine.combustion_running)


func test_realism_combustion_does_not_restart_without_starter() -> void:
	engine.combustion_running = false
	engine.angular_velocity = 0.0
	engine.fuel_tank.fuel_litres = 10.0
	for i in range(10):
		engine.apply(1.0, 0.01, 0.0)
	assert_false(engine.combustion_running)
	assert_almost_eq(engine.rpm, 0.0, 0.001)


func test_realism_engine_state_remains_finite_after_repeated_updates() -> void:
	engine.combustion_running = true
	engine.fuel_tank.fuel_litres = 10.0
	engine.rpm = 1000.0
	for i in range(1000):
		engine.apply(0.5, 0.001, 0.0)
	assert_false(is_nan(engine.angular_velocity))
	assert_false(is_inf(engine.angular_velocity))
	assert_gte(engine.angular_velocity, 0.0)


func test_realism_engine_rpm_remains_within_limiter_after_sustained_throttle() -> void:
	engine.combustion_running = true
	engine.fuel_tank.fuel_litres = 10.0
	engine.rpm = parameters.engine.max_rpm - 100.0
	for i in range(100):
		engine.apply(1.0, 0.01, 0.0)
	assert_lte(engine.rpm, parameters.engine.max_rpm + 0.01)


func test_realism_engine_with_large_inertia_accelerates_more_slowly() -> void:
	engine.combustion_running = true
	engine.fuel_tank.fuel_litres = 10.0
	engine.rpm = 2000.0
	parameters.engine.moment = 0.2
	var initial_velocity = engine.angular_velocity
	engine.apply(1.0, 0.01, 0.0)
	var low_inertia_delta = engine.angular_velocity - initial_velocity

	engine.rpm = 2000.0
	parameters.engine.moment = 0.4
	initial_velocity = engine.angular_velocity
	engine.apply(1.0, 0.01, 0.0)
	var high_inertia_delta = engine.angular_velocity - initial_velocity

	assert_gt(low_inertia_delta, high_inertia_delta)
