class_name EngineStarterController
extends EngineController.Listener

var torque: float = 150.0
var active: bool = false

func start() -> void:
	active = true


func stop() -> void:
	active = false


func get_torque() -> float:
	if active:
		return torque

	return 0.0


func onCombustionSelfSustaining(engine: EngineController) -> void:
	stop()


func onStall(engine: EngineController) -> void:
	pass
