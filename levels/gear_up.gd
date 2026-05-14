extends TouchScreenButton

@export var car: BaseCar

func _ready() -> void:
	pressed.connect(_on_pressed)


func _on_pressed() -> void:
	if car:
		car.shift_up()
