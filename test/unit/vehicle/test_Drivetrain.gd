extends GutTest

func assert_float_eq(one: float, two: float, threshold: float = 0.000001) -> void:
	assert_almost_eq(
		one,
		two,
		threshold
	)

var drivetrain: DriveTrain
var powertrain: PowertrainController
var car_view: RigidBody3D
var engine_audio: AudioStreamPlayer

func before_each() -> void:
	drivetrain = DriveTrain.new()
	var car_params := CarParameters.new()
	var parameters := DriveTrainParameters.new()

	parameters.gearbox.gear_ratios = [
		3.5,
		2.0,
		1.4
	]

	parameters.final_drive = 4.0
	parameters.gearbox.reverse_ratio = 3.2
	parameters.gearbox.gear_inertia = 1.0
	car_params.drivetrain = parameters
	car_view = RigidBody3D.new()
	engine_audio = AudioStreamPlayer.new()
	var engine_starter = EngineStarterController.new()
	var engine := EngineController.new()
	engine.initialize(car_params, car_view, engine_starter, engine_audio)
	powertrain = PowertrainController.new()
	var wheel_fl := RaycastSuspension.new()
	wheel_fl.set_params(car_params.wheel_params_fl)
	var wheel_fr := RaycastSuspension.new()
	wheel_fr.set_params(car_params.wheel_params_fr)
	var wheel_bl := RaycastSuspension.new()
	wheel_bl.set_params(car_params.wheel_params_bl)
	var wheel_br := RaycastSuspension.new()
	wheel_br.set_params(car_params.wheel_params_br)
	powertrain.initialize(car_params, engine, 
		wheel_fl, 
		wheel_fr, 
		wheel_bl, 
		wheel_br
	)
	drivetrain.setup(parameters, powertrain)

func after_each():
	powertrain.wheel_bl.queue_free()
	powertrain.wheel_br.queue_free()
	powertrain.wheel_fl.queue_free()
	powertrain.wheel_fr.queue_free()
	car_view.queue_free()
	engine_audio.queue_free()

func test_neutral_has_zero_gearing() -> void:
	drivetrain.gearbox.set_gear(0)

	assert_float_eq(
		drivetrain.gearbox.get_gearing(),
		0.0
	)


func test_first_gear_has_positive_gearing() -> void:
	drivetrain.gearbox.set_gear(1)

	assert_float_eq(
		drivetrain.gearbox.get_gearing(),
		14.0
	)


func test_reverse_has_negative_gearing() -> void:
	drivetrain.gearbox.set_gear(-1)

	assert_float_eq(
		drivetrain.gearbox.get_gearing(),
		-12.8
	)


func test_invalid_gear_is_clamped() -> void:
	drivetrain.gearbox.set_gear(99)

	assert_eq(
		drivetrain.gearbox.selected_gear,
		drivetrain.parameters.gearbox.gear_ratios.size()
	)


func test_disengaged_clutch_keeps_gearbox_inertia() -> void:
	drivetrain.gearbox.set_input_inertia(2.0)
	drivetrain.gearbox.set_gear(1)

	var inertia : float = drivetrain.gearbox.get_drive_inertia(1.0)

	assert_float_eq(
		inertia,
		196.0
	)


func test_engaged_clutch_reflects_engine_inertia() -> void:
	drivetrain.gearbox.set_input_inertia(2.0)
	drivetrain.gearbox.set_gear(1)

	var inertia : float = drivetrain.gearbox.get_drive_inertia(0.0)

	assert_float_eq(
		inertia,
		198.0
	)


func test_partially_engaged_clutch_only_scales_engine_inertia() -> void:
	drivetrain.gearbox.set_input_inertia(2.0)
	drivetrain.gearbox.set_gear(1)

	var inertia : float = drivetrain.gearbox.get_drive_inertia(0.5)

	assert_float_eq(
		inertia,
		197.0
	)


func test_disengaged_clutch_does_not_make_drive_inertia_zero() -> void:
	drivetrain.gearbox.set_input_inertia(2.0)
	drivetrain.gearbox.set_gear(1)

	var inertia : float = drivetrain.gearbox.get_drive_inertia(1.0)

	assert_gt(
		inertia,
		0.0
	)


func test_locked_differential_does_not_use_artificial_five_rad_per_second_stop() -> void:
	var left := FakeWheel.new()
	var right := FakeWheel.new()

	left.spin = 4.0
	right.spin = 4.0

	var spin: float = drivetrain.rear_differential._get_locked_spin(
		[
			left,
			right
		],
		0.0,
		1.0,
		0.1
	)

	assert_float_eq(
		spin,
		4.0
	)

func test_locked_differential_brakes_progressively() -> void:
	var left := FakeWheel.new()
	var right := FakeWheel.new()

	left.spin = 4.0
	right.spin = 4.0
	left.brake_torque = 1.0
	right.brake_torque = 1.0

	var spin: float = drivetrain.rear_differential._get_locked_spin(
		[
			left,
			right
		],
		0.0,
		0.1,
		0.1
	)

	assert_gt(
		spin,
		0.0
	)

	assert_lt(
		spin,
		4.0
	)


func test_locked_differential_preserves_zero_speed_without_torque() -> void:
	drivetrain.gearbox.drive_inertia = 1.0

	var left := FakeWheel.new()
	var right := FakeWheel.new()

	left.spin = 0.0
	right.spin = 0.0

	var spin : float = drivetrain.rear_differential._get_locked_spin(
		[
			left,
			right
		],
		0.0,
		0.1,
		0.1
	)

	assert_float_eq(
		spin,
		0.0
	)


func test_locked_differential_accelerates_from_zero_when_drive_torque_exists() -> void:
	drivetrain.gearbox.drive_inertia = 1.0

	var left := FakeWheel.new()
	var right := FakeWheel.new()

	left.spin = 0.0
	right.spin = 0.0

	var spin : float = drivetrain.rear_differential._get_locked_spin(
		[
			left,
			right
		],
		10.0,
		0.1,
		0.1
	)

	assert_gt(
		spin,
		0.0
	)


func test_neutral_does_not_apply_drive_torque_to_wheels() -> void:


	drivetrain.gearbox.set_gear(0)

	var result := drivetrain.apply_torque(
		100.0,
		1.0,
		0.016
	)

	assert_almost_eq(
		result,
		0.0,
		0.001,
		"Neutral must not transmit engine torque"
	)

func test_neutral_does_not_change_driven_wheel_spin() -> void:

	var wheels := [
		drivetrain.wheel_bl,
		drivetrain.wheel_br
	]

	for wheel in wheels:
		wheel.set_spin(0.0)

	drivetrain.gearbox.set_gear(0)

	drivetrain.apply_torque(
		100.0,
		1.0,
		0.016
	)

	for wheel in wheels:
		assert_almost_eq(
			wheel.get_spin(),
			0.0,
			0.001,
			"Neutral must not accelerate driven wheels"
		)
