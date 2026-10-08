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
var wheel_bl : RaycastSuspension
var wheel_br : RaycastSuspension
var wheel_fl : RaycastSuspension
var wheel_fr : RaycastSuspension
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
	wheel_fl = RaycastSuspension.new()
	wheel_fl.set_params(car_params.wheel_params_fl)
	wheel_fr = RaycastSuspension.new()
	wheel_fr.set_params(car_params.wheel_params_fr)
	wheel_bl = RaycastSuspension.new()
	wheel_bl.set_params(car_params.wheel_params_bl)
	wheel_br = RaycastSuspension.new()
	wheel_br.set_params(car_params.wheel_params_br)
	powertrain.initialize(car_params, engine, 
		wheel_fl, 
		wheel_fr, 
		wheel_bl, 
		wheel_br
	)
	drivetrain.setup(parameters, powertrain)

func after_each() -> void:
	wheel_bl.free()
	wheel_br.free()
	wheel_fl.free()
	wheel_fr.free()
	car_view.free()
	engine_audio.free()

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

func test_full_throttle_does_not_immediately_reach_max_rpm() -> void:
	powertrain.engine.start()
	drivetrain.gearbox.set_gear(1)
	
	var max_rpm : float = powertrain.engine.parameters.max_rpm

	powertrain.apply(
		1.0,
		0.0,
		0.016
	)

	assert_true(powertrain.engine.rpm != 0.0)
	assert_lt(
		powertrain.engine.rpm,
		max_rpm,
		"Full throttle must not immediately reach max RPM"
	)

func test_disengaged_clutch_does_not_make_drive_inertia_zero() -> void:
	drivetrain.gearbox.set_input_inertia(2.0)
	drivetrain.gearbox.set_gear(1)

	var inertia : float = drivetrain.gearbox.get_drive_inertia(1.0)

	assert_gt(
		inertia,
		0.0
	)


func test_neutral_does_not_apply_drive_torque_to_wheels() -> void:


	drivetrain.gearbox.set_gear(0)

	var result := drivetrain.apply_torque(
		100.0,
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
		0.016
	)

	for wheel in wheels:
		assert_almost_eq(
			wheel.get_spin(),
			0.0,
			0.001,
			"Neutral must not accelerate driven wheels"
		)
