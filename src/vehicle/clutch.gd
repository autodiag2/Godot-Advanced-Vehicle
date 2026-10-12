class_name Clutch
extends Controller

@export var friction := 250.0

var _locked := false

func _init() -> void:
	TAG_NAME = "CLUTCH"

func is_locked() -> bool:
	return _locked

# result x reaction torque to apply on drivetrain
# result y reaction torque to apply on engine
func get_reaction_torques(
	engine_av: float,
	drivetrain_av: float,
	engine_torque: float,
	drivetrain_torque: float,
	inertia_engine: float,
	inertia_drivetrain: float,
	clutch_input: float,
	delta: float
) -> Vector2:
	assert(not is_nan(engine_torque))
	assert(not is_nan(drivetrain_av))
	assert(not is_nan(engine_av))
	assert(not is_nan(drivetrain_torque))
	assert(not is_nan(inertia_engine))
	assert(not is_nan(inertia_drivetrain))
	assert(inertia_engine > 0.0)
	assert(inertia_drivetrain > 0.0)
	assert(delta >= 0.0)
	assert(clutch_input >= 0.0 and clutch_input <= 1.0)

	debug_print("engine av=", engine_av, " T=", engine_torque, " I=", inertia_engine)
	debug_print("drivetrain av=", drivetrain_av, " T=", drivetrain_torque, " I=", inertia_drivetrain)

	if delta == 0.0:
		return Vector2.ZERO

	var relative_speed := engine_av - drivetrain_av
	var max_clutch_torque := friction * (1.0 - clutch_input)

	if max_clutch_torque <= 0.0:
		_locked = false
		return Vector2.ZERO

	var inverse_total_inertia := (
		1.0 / inertia_engine +
		1.0 / inertia_drivetrain
	)

	var torque_to_synchronize := (
		relative_speed / delta +
		engine_torque / inertia_engine -
		drivetrain_torque / inertia_drivetrain
	) / inverse_total_inertia

	var clutch_torque := clampf(
		torque_to_synchronize,
		-max_clutch_torque,
		max_clutch_torque
	)

	_locked = absf(torque_to_synchronize) <= max_clutch_torque

	var reaction_torques := Vector2(clutch_torque, -clutch_torque)

	debug_print(
		"clutch reaction(Tc)=", absf(clutch_torque),
		" on engine=", reaction_torques.y,
		" on gearbox=", reaction_torques.x,
		" relative speed=", relative_speed,
		" required torque=", torque_to_synchronize,
		" max torque=", max_clutch_torque,
		" locked=", _locked
	)

	return reaction_torques
