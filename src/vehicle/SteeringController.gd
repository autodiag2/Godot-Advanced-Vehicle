class_name SteeringController
extends RefCounted

var steering_angle: float = 0.0

func update(
	target_steering: float,
	steering_speed: float,
	delta: float
) -> void:
	if target_steering < steering_angle:
		steering_angle -= steering_speed * delta

		if target_steering > steering_angle:
			steering_angle = target_steering

	elif target_steering > steering_angle:
		steering_angle += steering_speed * delta

		if target_steering < steering_angle:
			steering_angle = target_steering

func apply_to_wheels(
	front_left_wheel: RaycastSuspension,
	front_right_wheel: RaycastSuspension,
	max_steering_angle: float
) -> void:
	front_left_wheel.steer(
		steering_angle,
		max_steering_angle
	)

	front_right_wheel.steer(
		steering_angle,
		max_steering_angle
	)
