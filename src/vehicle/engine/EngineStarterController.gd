class_name EngineStarterController
extends EngineController.Listener

var torque: float = 5.0
var torque_ramp_rate: float = 1000.0
var target_torque: float = 0.0
var active: bool = false
var parent := Controller.new()

func _init() -> void:
	parent.TAG_NAME = "STARTER"

func start() -> void:
	active = true
	target_torque = torque


func stop() -> void:
	active = false
	target_torque = 0.0


func get_torque() -> float:

	var current_torque := target_torque if active else 0.0
	parent.debug_print("current_torque=", current_torque)
	return current_torque


func update(delta: float) -> void:
	assert(0.0 <= delta)

	var desired_torque := torque if active else 0.0
	target_torque = move_toward(
		target_torque,
		desired_torque,
		torque_ramp_rate * delta
	)


func onCombustionSelfSustaining(engine: EngineController) -> void:
	stop()


func onStall(engine: EngineController) -> void:
	pass
