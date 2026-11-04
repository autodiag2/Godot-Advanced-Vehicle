class_name SpeedControlVisualizer
extends Window

@onready var speed_label: Label = $Frame/Content/Controls/SpeedValue
@onready var speed_slider: HSlider = $Frame/Content/Controls/SpeedSlider


func _ready() -> void:
	title = "Simulation Speed"
	min_size = Vector2i(390, 210)
	size = Vector2i(480, 245)
	always_on_top = true
	transient = true
	exclusive = false
	popup_window = false
	borderless = true
	unresizable = false
	speed_slider.value = Engine.time_scale
	speed_slider.value_changed.connect(_on_speed_changed)
	$Frame/Content/Controls/ResetButton.pressed.connect(_on_reset_speed)
	$Frame/Content/Heading/CloseButton.pressed.connect(_on_close)
	close_requested.connect(_on_close)
	$ResizeGrip.gui_input.connect(_on_resize_grip_input)
	$Frame/Content/Heading.gui_input.connect(_on_heading_input)


func present() -> void:
	if not visible:
		var available_size := get_tree().root.size
		var mobile_layout := OS.has_feature("mobile") or available_size.x < 760
		var target_size := Vector2i(
			maxi(300, mini(480, int(float(available_size.x) * 0.96))),
			maxi(200, mini(245, int(float(available_size.y) * 0.9)))
		)
		min_size = Vector2i(
			mini(390, target_size.x),
			mini(210, target_size.y)
		)
		size = target_size
		unresizable = mobile_layout
		$ResizeGrip.visible = not mobile_layout
		popup_centered()
	grab_focus()


func _process(_delta: float) -> void:
	speed_label.text = "%.2fx" % Engine.time_scale
	if absf(speed_slider.value - Engine.time_scale) > 0.005:
		speed_slider.set_value_no_signal(Engine.time_scale)


func _on_speed_changed(value: float) -> void:
	Engine.time_scale = clampf(value, 0.01, 1.0)


func _on_reset_speed() -> void:
	Engine.time_scale = 1.0
	speed_slider.set_value_no_signal(1.0)


func _on_close() -> void:
	hide()


func _on_heading_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		start_drag()
	elif event is InputEventScreenTouch and event.pressed:
		start_drag()


func _on_resize_grip_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		start_resize(DisplayServer.WINDOW_EDGE_BOTTOM_RIGHT)
	elif event is InputEventScreenTouch and event.pressed:
		start_resize(DisplayServer.WINDOW_EDGE_BOTTOM_RIGHT)
