extends TouchScreenButton

enum State {
	OFF,
	CONTACT,
	ENGINE_ON
}

var state: State = State.OFF

var key_turn_on: Texture2D = preload("res://assets/ui/key_turn_on.png")
var key_contact_on: Texture2D = preload("res://assets/ui/key_contact_on.png")
var key_engine_on: Texture2D = preload("res://assets/ui/key_engine_on.png")


func _ready() -> void:
	texture_normal = key_turn_on
	pressed.connect(_on_pressed)

func _on_pressed() -> void:
	var car := get_tree().current_scene.find_child(
		"RigidBodyCar",
		true,
		false
	) as BaseCar

	if not car:
		return

	match state:
		State.OFF:
			state = State.CONTACT
			texture_normal = key_contact_on

		State.CONTACT:
			car.start()

			state = State.ENGINE_ON
			texture_normal = key_engine_on

		State.ENGINE_ON:
			car.stop()

			state = State.OFF
			texture_normal = key_turn_on
