extends Button

func _ready():
	pressed.connect(_on_pressed)

func _on_pressed():
	var menu = get_parent().get_node("Menu")
	menu.visible = true
