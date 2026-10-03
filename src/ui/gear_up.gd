extends TouchScreenButton

func _ready() -> void:
	pressed.connect(_on_pressed)

func _on_pressed() -> void:
	var car := get_tree().current_scene.find_child(
		"Vehicle",
		true,
		false
	) as BaseCar

	if car:
		car.shift_up()
