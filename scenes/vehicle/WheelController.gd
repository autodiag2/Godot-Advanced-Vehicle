class_name WheelController

var tire: TireModel

var mass := 15.0
var inertia := 0.0
var ackermann := 0.15

var spin := 0.0

var slip := Vector2.ZERO
var force := Vector3.ZERO

var speed_threshold := 0.1


func setup(
	tire_arg: TireModel,
	mass_arg: float,
	ackermann_arg: float
) -> void:
	assert(tire_arg != null)
	assert(mass_arg > 0.0)
	assert(tire_arg.radius > 0.0)

	tire = tire_arg
	mass = mass_arg
	ackermann = ackermann_arg
	inertia = 0.5 * mass * pow(tire.radius, 2)

	spin = 0.0
	slip = Vector2.ZERO
	force = Vector3.ZERO


func update_slip(
	z_vel: float,
	lateral_slip: float
) -> void:
	assert(speed_threshold > 0.0)

	slip.x = lateral_slip

	var slip_speed := maxf(
		abs(z_vel),
		speed_threshold
	)

	slip.y = (
		z_vel -
		spin * tire.radius
	) / slip_speed


func update_force(
	normal_load: float,
	surface_mu: float
) -> Vector3:
	assert(tire != null)

	force = tire.update_forces(
		slip,
		normal_load,
		surface_mu
	)

	return force


func apply_torque(
	drive_torque: float,
	brake_torque: float,
	drive_inertia: float,
	z_vel: float,
	delta: float
) -> float:
	assert(tire != null)
	assert(brake_torque >= 0.0)
	assert(drive_inertia >= 0.0)

	if delta <= 0.0:
		return 0.0

	var total_inertia := inertia + drive_inertia

	assert(total_inertia > 0.0)

	var previous_spin := spin
	var net_torque := force.y * tire.radius
	net_torque += drive_torque

	if (
		abs(spin) < 5.0 and
		brake_torque > 0.0 and
		brake_torque >= abs(net_torque)
	):
		spin = 0.0
	else:
		if is_zero_approx(drive_torque):
			var target_spin := 0.0

			if abs(z_vel) >= speed_threshold:
				target_spin = z_vel / tire.radius

			var spin_error := target_spin - spin
			net_torque += spin_error * total_inertia / delta

		var brake_direction: float = sign(spin)

		if brake_direction == 0.0:
			brake_direction = sign(net_torque)

		net_torque -= brake_torque * brake_direction

		var spin_delta := (
			delta *
			net_torque /
			total_inertia
		)

		var next_spin := spin + spin_delta

		if (
			spin != 0.0 and
			sign(next_spin) != sign(spin)
		):
			spin = 0.0
		else:
			spin = next_spin

	if is_zero_approx(drive_torque):
		return 0.0

	return (
		(spin - previous_spin) *
		total_inertia /
		(drive_torque * delta)
	)


func get_reaction_torque() -> float:
	return force.y * tire.radius


func set_spin(value: float) -> void:
	spin = value


func get_spin() -> float:
	return spin


func steer(input: float, max_steer: float) -> float:
	var correction := (
		1.0 -
		cos(abs(input) * 0.5 * PI)
	) * ackermann

	return max_steer * (
		input +
		sign(input) * correction
	)
