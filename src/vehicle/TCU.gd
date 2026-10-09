class_name TCU extends RefCounted

var 	engine: EngineController
var gearbox: Gearbox
var wheel_fl: RaycastSuspension
var wheel_fr: RaycastSuspension
var wheel_bl: RaycastSuspension
var wheel_br: RaycastSuspension

var parameters: CarParameters
var shift_time := 700.0 # ms

func link(
	parameters_arg: CarParameters,
	engine_arg: EngineController,
	gearbox_arg: Gearbox,
	wheel_fl_arg: RaycastSuspension,
	wheel_fr_arg: RaycastSuspension,
	wheel_bl_arg: RaycastSuspension,
	wheel_br_arg: RaycastSuspension
) -> void:
	assert(parameters_arg != null)
	parameters = parameters_arg
	engine = engine_arg
	wheel_fl = wheel_fl_arg
	wheel_fr = wheel_fr_arg
	wheel_bl = wheel_bl_arg
	wheel_br = wheel_br_arg
	self.gearbox = gearbox_arg
	gearbox.add_listener(self)

var last_shift_time := 0

func onGearboxGearChange(new_gear: int):
	last_shift_time = Time.get_ticks_msec()

func update(
	throttle_input: float,
	brake_input: float,
	longitudinal_speed: float,
	delta: float
) -> void:

	if not parameters.drivetrain.gearbox.automatic:
		return

	var average_front_wheel_speed: float =  (
		(
			wheel_fl.wheel.spin +
			wheel_fr.wheel.spin
		) * 0.5
	)

	var average_rear_wheel_speed: float = (
		(
			wheel_bl.wheel.spin +
			wheel_br.wheel.spin
		) * 0.5
	)

	var driven_wheel_speed := average_front_wheel_speed

	if (
		parameters.drivetrain.drivetype ==
		parameters.drivetrain.DRIVE_TYPE.RWD
	):
		driven_wheel_speed = average_rear_wheel_speed

	elif (
		parameters.drivetrain.drivetype ==
		parameters.drivetrain.DRIVE_TYPE.AWD
	):
		driven_wheel_speed = (
			average_front_wheel_speed +
			average_rear_wheel_speed
		) * 0.5
	var next_gear_rpm := 0.0
	var previous_gear_rpm := 0.0

	var next_gear := gearbox.selected_gear + 1
	var previous_gear := gearbox.selected_gear - 1

	if (
		next_gear > 0 &&
		next_gear <=
		parameters.drivetrain.gearbox.gear_ratios.size()
	):
		next_gear_rpm = (
			parameters.drivetrain.gearbox.gear_ratios[
				next_gear - 1
			] *
			parameters.drivetrain.final_drive *
			absf(driven_wheel_speed) *
			EngineController.RPM_PER_RADIAN_PER_SECOND
		)

	if (
		previous_gear > 0 &&
		previous_gear <=
		parameters.drivetrain.gearbox.gear_ratios.size()
	):
		previous_gear_rpm = (
			parameters.drivetrain.gearbox.gear_ratios[
				previous_gear - 1
			] *
			parameters.drivetrain.final_drive *
			absf(driven_wheel_speed) *
			EngineController.RPM_PER_RADIAN_PER_SECOND
		)

	var next_gear_torque := (
		engine.calculate_torque(
			throttle_input,
			next_gear_rpm
		)
	)

	var previous_gear_torque := (
		engine.calculate_torque(
			throttle_input,
			previous_gear_rpm
		)
	)

	var reversing = false
	var cur_torque := engine.output_torque

	if gearbox.selected_gear == -1:
		reversing = true

	if (
		gearbox.selected_gear > 0 &&
		next_gear_torque > cur_torque
	):
		if engine.rpm > 0.85 * engine.max_rpm:
			if Time.get_ticks_msec() - last_shift_time > shift_time:
				gearbox.shift_up()

	if (
		gearbox.selected_gear > 1 &&
		engine.rpm < 0.5 * engine.max_rpm &&
		previous_gear_torque > cur_torque
	):
		if Time.get_ticks_msec() - last_shift_time > shift_time:
			gearbox.shift_down()

	if abs(gearbox.selected_gear) <= 1 and abs(longitudinal_speed) < 3.0 and brake_input > 0.2:
		if not reversing:
			if Time.get_ticks_msec() - last_shift_time > shift_time:
				gearbox.shift_down()
		else:
			if Time.get_ticks_msec() - last_shift_time > shift_time:
				gearbox.shift_up()
