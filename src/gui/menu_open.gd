extends TouchScreenButton

func _ready() -> void:
	pressed.connect(_on_pressed)

func _on_pressed() -> void:
	var menu = get_tree().root.find_child("Menu", true, false)
	if menu:
		menu.visible = true
