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
	tire = tire_arg
	mass = mass_arg
	ackermann = ackermann_arg
	inertia = 0.5 * mass * pow(tire.radius, 2)


func update_slip(
	z_vel: float,
	lateral_slip: float
) -> void:
	slip.x = lateral_slip

	if abs(z_vel) >= speed_threshold:
		slip.y = (
			z_vel -
			spin * tire.radius
		) / abs(z_vel)
	else:
		slip.y = 0.0


func update_force(
	normal_load: float,
	surface_mu: float
) -> Vector3:
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
	var previous_spin := spin
	var net_torque := force.y * tire.radius
	net_torque += drive_torque

	if abs(spin) < 5 and brake_torque > abs(net_torque):
		spin = 0.0
	else:
		if drive_torque == 0.0:
			var target_spin := 0.0

			if abs(z_vel) >= speed_threshold:
				target_spin = z_vel / tire.radius

			var spin_error := target_spin - spin
			net_torque += spin_error * inertia / delta

		net_torque -= brake_torque * sign(spin)

		spin += (
			delta *
			net_torque /
			(inertia + drive_inertia)
		)

	if drive_torque * delta == 0:
		return 0.5

	return (
		(spin - previous_spin) *
		(inertia + drive_inertia) /
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
