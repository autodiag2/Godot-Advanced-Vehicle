class_name SuspensionController

var spring_length := 0.2
var spring_stiffness := 45.0
var bump := 3.5
var rebound := 4.0
var anti_roll := 0.0

var current_length := 0.2

var load_mm := 0.0
var previous_load_mm := 0.0
var speed_mm_per_second := 0.0
var load_newton := 0.0


func setup(
	length: float,
	stiffness: float,
	bump_value: float,
	rebound_value: float,
	anti_roll_value: float
) -> void:
	spring_length = length
	spring_stiffness = stiffness
	bump = bump_value
	rebound = rebound_value
	anti_roll = anti_roll_value
	current_length = spring_length
	load_mm = 0.0
	previous_load_mm = 0.0
	speed_mm_per_second = 0.0
	load_newton = 0.0


func update(
	length: float,
	opposite_compression: float,
	delta: float
) -> float:
	current_length = length

	load_mm = (
		spring_length -
		current_length
	) * 1000.0

	if delta > 0.0:
		speed_mm_per_second = (
			load_mm -
			previous_load_mm
		) / delta
	else:
		speed_mm_per_second = 0.0

	previous_load_mm = load_mm

	load_newton = load_mm * spring_stiffness

	if speed_mm_per_second >= 0.0:
		load_newton += speed_mm_per_second * bump
	else:
		load_newton += speed_mm_per_second * rebound

	load_newton += anti_roll * (
		load_mm -
		opposite_compression
	)

	load_newton = maxf(load_newton, 0.0)

	return load_newton
