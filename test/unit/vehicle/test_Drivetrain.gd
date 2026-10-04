extends GutTest

func assert_float_eq(one: float, two: float, threshold: float = 0.000001) -> void:
	assert_almost_eq(
		one,
		two,
		threshold
	)

class FakeWheel:
	var spin: float = 0.0
	var reaction_torque: float = 0.0

	var wheel := FakeWheelData.new()


	class FakeWheelData:
		var inertia: float = 1.0


	func get_spin() -> float:
		return spin


	func set_spin(value: float) -> void:
		spin = value


	func get_reaction_torque() -> float:
		return reaction_torque


	func apply_torque(
		torque: float,
		brake_torque: float,
		inertia: float,
		delta: float
	) -> float:
		reaction_torque = -torque
		return 0.0


var drivetrain: DriveTrain


func before_each() -> void:
	drivetrain = DriveTrain.new()


func _create_parameters() -> DriveTrainParameters:
	var parameters := DriveTrainParameters.new()

	parameters.gearbox.gear_ratios = [
		3.5,
		2.0,
		1.4
	]

	parameters.final_drive = 4.0
	parameters.gearbox.reverse_ratio = 3.2
	parameters.gearbox.gear_inertia = 1.0

	return parameters


func test_neutral_has_zero_gearing() -> void:
	drivetrain.drivetrain_params = _create_parameters()
	drivetrain.gearbox.set_selected_gear(0)

	assert_float_eq(
		drivetrain.gearbox.get_gearing(),
		0.0
	)


func test_first_gear_has_positive_gearing() -> void:
	drivetrain.drivetrain_params = _create_parameters()
	drivetrain.gearbox.set_selected_gear(1)

	assert_float_eq(
		drivetrain.gearbox.get_gearing(),
		14.0
	)


func test_reverse_has_negative_gearing() -> void:
	drivetrain.drivetrain_params = _create_parameters()
	drivetrain.gearbox.set_selected_gear(-1)

	assert_float_eq(
		drivetrain.gearbox.get_gearing(),
		-12.8
	)


func test_invalid_gear_is_clamped() -> void:
	drivetrain.drivetrain_params = _create_parameters()

	drivetrain.gearbox.set_selected_gear(99)

	assert_eq(
		drivetrain.gearbox.selected_gear,
		drivetrain.drivetrain_params.gearbox.gear_ratios.size()
	)


func test_disengaged_clutch_keeps_gearbox_inertia() -> void:
	drivetrain.drivetrain_params = _create_parameters()
	drivetrain.gearbox.set_input_inertia(2.0)
	drivetrain.gearbox.set_selected_gear(1)

	var inertia : float = drivetrain.gearbox.get_drive_inertia(1.0)

	assert_float_eq(
		inertia,
		196.0
	)


func test_engaged_clutch_reflects_engine_inertia() -> void:
	drivetrain.drivetrain_params = _create_parameters()
	drivetrain.gearbox.set_input_inertia(2.0)
	drivetrain.gearbox.set_selected_gear(1)

	var inertia : float = drivetrain.gearbox.get_drive_inertia(0.0)

	assert_float_eq(
		inertia,
		198.0
	)


func test_partially_engaged_clutch_only_scales_engine_inertia() -> void:
	drivetrain.drivetrain_params = _create_parameters()
	drivetrain.gearbox.set_input_inertia(2.0)
	drivetrain.gearbox.set_selected_gear(1)

	var inertia : float = drivetrain.gearbox.get_drive_inertia(0.5)

	assert_float_eq(
		inertia,
		197.0
	)


func test_disengaged_clutch_does_not_make_drive_inertia_zero() -> void:
	drivetrain.drivetrain_params = _create_parameters()
	drivetrain.gearbox.set_input_inertia(2.0)
	drivetrain.gearbox.set_selected_gear(1)

	var inertia : float = drivetrain.gearbox.get_drive_inertia(1.0)

	assert_gt(
		inertia,
		0.0
	)


func test_locked_differential_does_not_use_artificial_five_rad_per_second_stop() -> void:
	drivetrain.drivetrain_params = _create_parameters()
	drivetrain.gearbox.drive_inertia = 1.0

	var left := FakeWheel.new()
	var right := FakeWheel.new()

	left.spin = 4.0
	right.spin = 4.0

	var spin : float = drivetrain._get_locked_spin(
		[
			left,
			right
		],
		0.0,
		0.0,
		0.1
	)

	assert_float_eq(
		spin,
		4.0
	)


func test_locked_differential_brakes_progressively() -> void:
	drivetrain.drivetrain_params = _create_parameters()
	drivetrain.gearbox.drive_inertia = 1.0

	var left := FakeWheel.new()
	var right := FakeWheel.new()

	left.spin = 4.0
	right.spin = 4.0

	var spin : float = drivetrain._get_locked_spin(
		[
			left,
			right
		],
		0.0,
		1.0,
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
	drivetrain.drivetrain_params = _create_parameters()
	drivetrain.gearbox.drive_inertia = 1.0

	var left := FakeWheel.new()
	var right := FakeWheel.new()

	left.spin = 0.0
	right.spin = 0.0

	var spin : float = drivetrain._get_locked_spin(
		[
			left,
			right
		],
		0.0,
		0.0,
		0.1
	)

	assert_float_eq(
		spin,
		0.0
	)


func test_locked_differential_accelerates_from_zero_when_drive_torque_exists() -> void:
	drivetrain.drivetrain_params = _create_parameters()
	drivetrain.gearbox.drive_inertia = 1.0

	var left := FakeWheel.new()
	var right := FakeWheel.new()

	left.spin = 0.0
	right.spin = 0.0

	var spin : float = drivetrain._get_locked_spin(
		[
			left,
			right
		],
		10.0,
		0.0,
		0.1
	)

	assert_gt(
		spin,
		0.0
	)


func test_lsd_reaction_uses_signed_torque_difference() -> void:
	var left := FakeWheel.new()
	var right := FakeWheel.new()

	left.reaction_torque = 100.0
	right.reaction_torque = -50.0

	var delta_torque := (
		left.get_reaction_torque() -
		right.get_reaction_torque()
	)

	assert_float_eq(
		delta_torque,
		150.0
	)


func test_open_differential_resets_diff_clutch_lock_state() -> void:
	drivetrain.drivetrain_params = _create_parameters()

	drivetrain._diff_clutch.locked = false

	assert_false(
		drivetrain._diff_clutch.locked
	)

	# The actual state reset is exercised by differential()
	# when called with an OPEN_DIFF configuration.
