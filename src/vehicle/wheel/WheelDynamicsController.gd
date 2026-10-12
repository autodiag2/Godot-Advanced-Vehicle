class_name WheelDynamicsController extends Controller

var wheel: WheelController
var suspension: SuspensionController

var surface_mu := 1.0

var lateral_velocity := 0.0
var longitudinal_velocity := 0.0

var suspension_load := 0.0
var rolling_resistance := 0.0

var force := Vector3.ZERO

func _init() -> void:
	TAG_NAME = "WDYNAMICS"

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

	debug_print("previous: longitudinal_velocity=", longitudinal_velocity, " lateral_velocity=", lateral_velocity)
	longitudinal_velocity = -local_velocity.z
	lateral_velocity = local_velocity.x
	debug_print(
		"SIGN CHECK: local_z=", local_velocity.z,
		" longitudinal_velocity=", longitudinal_velocity,
		" wheel_spin=", wheel.spin,
		" wheel_radius=", wheel.tire.radius,
		" wheel_peripheral_velocity=", wheel.spin * wheel.tire.radius
	)
	debug_print("longitudinal_velocity=", longitudinal_velocity)
	var planar_velocity := Vector2(
		local_velocity.x,
		local_velocity.z
	)

	var lateral_slip := 0.0

	if (
		planar_velocity.length_squared() >
		pow(wheel.speed_threshold, 2)
	):
		lateral_slip = atan2(
			-planar_velocity.x,
			absf(planar_velocity.y)
		)

	#assert(0.0 <= longitudinal_velocity)
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

	#force.y += rolling_resistance

	return force
