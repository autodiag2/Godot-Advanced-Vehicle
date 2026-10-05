class_name WheelDisc
extends RefCounted

var effective_radius: float = 0.0
var clamping: float = 0.0 # [0;1]

var inner_pad := WheelPad.new()
var outer_pad := WheelPad.new()

func brake(clamping_arg: float) -> void:
	assert(0.0 <= clamping_arg)
	assert(clamping_arg <= 1.0)
	clamping = clamping_arg

func get_braking_factor() -> float:
	var braking_factor := (
		inner_pad.calculate_braking_factor(clamping) +
		outer_pad.calculate_braking_factor(clamping)
	) / 2.0

	return braking_factor

func update_usage(
	brake_torque: float,
	spin: float,
	delta: float
) -> void:
	inner_pad.update_usage(
		brake_torque * 0.5,
		spin,
		delta
	)

	outer_pad.update_usage(
		brake_torque * 0.5,
		spin,
		delta
	)
