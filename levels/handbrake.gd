extends TouchScreenButton


func _ready() -> void:
	pressed.connect(_on_pressed)
	released.connect(_on_released)


func _on_pressed() -> void:
	Input.action_press("Handbrake")


func _on_released() -> void:
	Input.action_release("Handbrake")
