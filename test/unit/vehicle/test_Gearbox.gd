extends GutTest

class TestDifferential extends Differential:
	var last_input_torque: float = 0.0

	func apply_torque(torque: float, delta: float) -> float:
		last_input_torque = torque
		return torque


var gearbox: Gearbox
var differential: TestDifferential
var drivetrain_parameters: DriveTrainParameters
var car_parameters: CarParameters
var wheel_bl: WheelCorner
var wheel_br: WheelCorner
var wheel_fl: WheelCorner
var wheel_fr: WheelCorner


func before_each() -> void:
	car_parameters = CarParameters.new()
	drivetrain_parameters = DriveTrainParameters.new()
	drivetrain_parameters.drivetype = DriveTrainParameters.DRIVE_TYPE.RWD
	drivetrain_parameters.gearbox.gear_inertia = 0.2
	drivetrain_parameters.gearbox.gear_ratios = [2.0]
	drivetrain_parameters.gearbox.reverse_ratio = 2.0

	wheel_bl = WheelCorner.new()
	wheel_br = WheelCorner.new()
	wheel_fl = WheelCorner.new()
	wheel_fr = WheelCorner.new()

	wheel_bl.set_params(car_parameters.wheel_params_bl.duplicate(true))
	wheel_br.set_params(car_parameters.wheel_params_br.duplicate(true))
	wheel_fl.set_params(car_parameters.wheel_params_fl.duplicate(true))
	wheel_fr.set_params(car_parameters.wheel_params_fr.duplicate(true))

	differential = TestDifferential.new()
	differential.wheel_bl = wheel_bl
	differential.wheel_br = wheel_br
	differential.wheel_fl = wheel_fl
	differential.wheel_fr = wheel_fr

	gearbox = Gearbox.new()
	gearbox.setup(drivetrain_parameters, differential)

func after_each():
	wheel_bl.free()
	wheel_br.free()
	wheel_fl.free()
	wheel_fr.free()

func test_neutral_input_shaft_accelerates_from_torque_and_inertia() -> void:
	gearbox.params.gear_inertia = 0.5
	gearbox.set_gear(0)

	var returned_torque := gearbox.apply_torque(10.0, 0.1)

	assert_almost_eq(gearbox.input_av, 2.0, 0.000001)
	assert_almost_eq(returned_torque, 10.0, 0.000001)


func test_gearbox_inertia_reduces_transmitted_torque_during_acceleration() -> void:
	gearbox.set_gear(1)
	gearbox.input_av = 0.0
	wheel_bl.set_spin(0.5)
	wheel_br.set_spin(0.5)

	var returned_torque := gearbox.apply_torque(10.0, 0.1)

	assert_almost_eq(gearbox.input_av, 1.0, 0.000001)
	assert_almost_eq(differential.last_input_torque, 16.0, 0.000001)
	assert_almost_eq(returned_torque, 8.0, 0.000001)


func test_gearbox_inertia_consumes_no_torque_at_constant_speed() -> void:
	gearbox.set_gear(1)
	wheel_bl.set_spin(5.0)
	wheel_br.set_spin(5.0)
	gearbox.input_av = 10.0

	var returned_torque := gearbox.apply_torque(100.0, 0.1)

	assert_almost_eq(gearbox.input_av, 10.0, 0.000001)
	assert_almost_eq(differential.last_input_torque, 200.0, 0.000001)
	assert_almost_eq(returned_torque, 100.0, 0.000001)
