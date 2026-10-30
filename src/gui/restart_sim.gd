extends Button

var worldSim: WorldSim

func _ready():
	pressed.connect(_on_pressed)

@warning_ignore("shadowed_variable")
func onInitWorldSim(worldSim: WorldSim):
	self.worldSim = worldSim

func _on_pressed():
	self.worldSim.reload()
	var menu = get_tree().root.find_child("Menu", true, false)
	if menu != null:
		menu.visible = false
