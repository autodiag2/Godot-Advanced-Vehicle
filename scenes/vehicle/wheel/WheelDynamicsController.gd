class_name WheelDynamicsController

var wheel: WheelController
var suspension: SuspensionController

var surface_mu := 1.0

var lateral_velocity := 0.0
var longitudinal_velocity := 0.0

var suspension_load := 0.0
var rolling_resistance := 0.0

var force := Vector3.ZERO

func setup(
	wheel_param: WheelController,
	suspension_param: SuspensionController
) -> void:
	wheel = wheel_param
	suspension = suspension_param
	assert(wheel != null)
	assert(suspension != null)

func update(
	local_velocity: Vector3,
	normal_load: float,
	surface_friction: float,
	delta: float
) -> Vector3:
	surface_mu = surface_friction

	longitudinal_velocity = -local_velocity.z
	lateral_velocity = local_velocity.x

	var planar_velocity := Vector2(
		local_velocity.x,
		local_velocity.z
	).normalized()

	var lateral_slip := asin(
		clamp(
			-planar_velocity.x,
			-1.0,
			1.0
		)
	)

	wheel.update_slip(
		longitudinal_velocity,
		lateral_slip
	)

	suspension_load = maxf(normal_load, 0.0)

	force = wheel.update_force(
		suspension_load,
		surface_mu
	)

	rolling_resistance = wheel.tire.get_rolling_resistance(
		suspension_load,
		longitudinal_velocity
	)

	force.y += rolling_resistance

	return force
