extends Node

var bridge = null

func _ready():
	print("CarBridge _ready")

	var wrapper = Engine.get_singleton(
        "JavaClassWrapper"
	)

	if wrapper == null:
		print("JavaClassWrapper not found")
		return

	print("JavaClassWrapper found")

	bridge = wrapper.wrap(
        "com.github.autodiag2.elm327emu.sim.CarBridge"
	)

	if bridge == null:
		print("Failed to wrap Kotlin CarBridge")
		return

	print("Kotlin CarBridge wrapped successfully")

func _process(_delta):
	print("CarBridge _process")

	if bridge == null:
		print("bridge is null")
		return

	var car = get_tree().get_first_node_in_group(
        "player_car"
	)

	if car == null:
		print("player_car not found")
		return

	print("Current RPM: ", car.rpm)

	bridge.setRpm(car.rpm)

	print("RPM sent to Kotlin")
