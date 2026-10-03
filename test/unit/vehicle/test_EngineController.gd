extends GutTest


var engine: EngineController
var parameters: CarParameters
var car: RigidBody3D
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
	parameters.engine_bsfc = 250.0

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


func test_initialize_stores_audio_player() -> void:
	assert_eq(
		engine.engine_audio_player,
		audio_player
	)


func test_calculate_torque_at_zero_throttle() -> void:
	var torque := engine.calculate_torque(
		4000.0,
		0.0,
		parameters
	)

	assert_float_eq(
		torque,
		-10.0
	)


func test_calculate_torque_at_full_throttle() -> void:
	var torque := engine.calculate_torque(
		4000.0,
		1.0,
		parameters
	)

	assert_float_eq(
		torque,
		200.0
	)


func test_calculate_torque_at_half_throttle() -> void:
	var torque := engine.calculate_torque(
		4000.0,
		0.5,
		parameters
	)

	assert_float_eq(
		torque,
		95.0
	)


func test_calculate_torque_clamps_rpm_factor() -> void:
	var torque := engine.calculate_torque(
		10000.0,
		1.0,
		parameters
	)

	assert_float_eq(
		torque,
		200.0
	)


func test_update_accelerates_engine() -> void:
	engine.rpm = 1000.0
	engine.reaction_torque = 0.0

	engine.update(
		parameters,
		1.0,
		0.1
	)

	assert_gt(
		engine.rpm,
		1000.0
	)


func test_update_updates_angular_velocity() -> void:
	engine.rpm = 2000.0

	engine.update(
		parameters,
		0.0,
		0.0
	)

	assert_float_eq(
		engine.angular_velocity,
		engine.rpm /
		EngineController.RPM_PER_RADIAN_PER_SECOND
	)


func test_update_includes_reaction_torque() -> void:
	engine.rpm = 3000.0
	engine.reaction_torque = -100.0

	engine.update(
		parameters,
		1.0,
		0.1
	)

	var expected_rpm := (
		3000.0 +
		EngineController.RPM_PER_RADIAN_PER_SECOND *
		0.1 *
		100.0 /
		parameters.engine_moment
	)

	assert_float_eq(
		engine.rpm,
		expected_rpm,
		0.001
	)


func test_update_clamps_rpm_to_maximum() -> void:
	engine.rpm = 7900.0
	engine.reaction_torque = 10000.0

	engine.update(
		parameters,
		1.0,
		0.1
	)

	assert_eq(
		engine.rpm,
		parameters.max_engine_rpm
	)


func test_update_zeroes_output_torque_at_limiter() -> void:
	engine.rpm = 7900.0
	engine.reaction_torque = 10000.0

	engine.update(
		parameters,
		1.0,
		0.1
	)

	assert_eq(
		engine.output_torque,
		0.0
	)


func test_update_keeps_angular_velocity_consistent_at_limiter() -> void:
	engine.rpm = 7900.0
	engine.reaction_torque = 10000.0

	engine.update(
		parameters,
		1.0,
		0.1
	)

	assert_float_eq(
		engine.angular_velocity,
		engine.rpm /
		EngineController.RPM_PER_RADIAN_PER_SECOND
	)


func test_update_clamps_negative_rpm_to_zero() -> void:
	engine.rpm = 100.0
	engine.reaction_torque = -10000.0

	engine.update(
		parameters,
		0.0,
		0.1
	)

	assert_eq(
		engine.rpm,
		0.0
	)

	assert_eq(
		engine.angular_velocity,
		0.0
	)


func test_clamp_to_idle() -> void:
	engine.rpm = 400.0

	engine.clamp_to_idle(parameters)

	assert_eq(
		engine.rpm,
		parameters.rpm_idle
	)


func test_clamp_to_idle_does_not_reduce_rpm() -> void:
	engine.rpm = 1500.0

	engine.clamp_to_idle(parameters)

	assert_eq(
		engine.rpm,
		1500.0
	)


func test_consume_fuel_reduces_fuel() -> void:
	engine.output_torque = 100.0
	engine.rpm = 3000.0

	var initial_fuel := engine.fuel_litres

	engine.consume_fuel(
		parameters,
		car,
		1.0
	)

	assert_lt(
		engine.fuel_litres,
		initial_fuel
	)


func test_consume_fuel_reduces_vehicle_mass() -> void:
	engine.output_torque = 100.0
	engine.rpm = 3000.0

	var initial_mass := car.mass

	engine.consume_fuel(
		parameters,
		car,
		1.0
	)

	assert_lt(
		car.mass,
		initial_mass
	)


func test_zero_output_torque_does_not_consume_fuel() -> void:
	engine.output_torque = 0.0
	engine.rpm = 3000.0

	var initial_fuel := engine.fuel_litres
	var initial_mass := car.mass

	engine.consume_fuel(
		parameters,
		car,
		1.0
	)

	assert_eq(
		engine.fuel_litres,
		initial_fuel
	)

	assert_eq(
		car.mass,
		initial_mass
	)


func test_fuel_consumption_cannot_go_below_zero() -> void:
	engine.output_torque = 1000000.0
	engine.rpm = 8000.0
	engine.fuel_litres = 0.001

	engine.consume_fuel(
		parameters,
		car,
		100.0
	)

	assert_eq(
		engine.fuel_litres,
		0.0
	)


func test_update_sound_starts_engine_sound() -> void:
	parameters.engine_sound = AudioStreamGenerator.new()
	engine.rpm = parameters.rpm_idle

	engine.update_sound(parameters)

	assert_true(
		audio_player.playing
	)


func test_update_sound_sets_pitch_from_rpm() -> void:
	parameters.engine_sound = AudioStreamGenerator.new()
	engine.rpm = 2000.0

	engine.update_sound(parameters)

	assert_float_eq(
		audio_player.pitch_scale,
		2.0
	)


func test_update_sound_stops_below_idle() -> void:
	parameters.engine_sound = AudioStreamGenerator.new()
	engine.rpm = parameters.rpm_idle

	engine.update_sound(parameters)

	assert_true(
		audio_player.playing
	)

	engine.rpm = 500.0

	engine.update_sound(parameters)

	assert_false(
		audio_player.playing
	)


func test_update_sound_stops_at_maximum_rpm() -> void:
	parameters.engine_sound = AudioStreamGenerator.new()
	engine.rpm = parameters.max_engine_rpm - 1.0

	engine.update_sound(parameters)

	assert_true(
		audio_player.playing
	)

	engine.rpm = parameters.max_engine_rpm

	engine.update_sound(parameters)

	assert_false(
		audio_player.playing
	)


func test_stop_sound() -> void:
	parameters.engine_sound = AudioStreamGenerator.new()
	engine.rpm = parameters.rpm_idle

	engine.update_sound(parameters)

	assert_true(
		audio_player.playing
	)

	engine.stop_sound()

	assert_false(
		audio_player.playing
	)
