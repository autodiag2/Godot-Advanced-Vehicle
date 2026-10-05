extends TouchScreenButton

enum State {
	OFF,
	CONTACT,
	ENGINE_ON
}

var state: State = State.OFF

var key_contact_on: Texture2D = preload("res://assets/ui/key_turn_on.png")

const OFF_COLOR := Color.RED
const CONTACT_COLOR := Color.YELLOW
const ENGINE_ON_COLOR := Color.GREEN
const TRANSITION_DURATION := 0.25

var color_tween: Tween


func _ready() -> void:
	texture_normal = key_contact_on

	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;

uniform vec4 key_color : source_color;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);

	// Keep black background black.
	// Replace white foreground with the state color.
	COLOR = vec4(key_color.rgb * tex.rgb, tex.a);
}
"""

	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("key_color", _get_state_color())
	self.material = material

	pressed.connect(_on_pressed)


func _get_state_color() -> Color:
	match state:
		State.OFF:
			return OFF_COLOR
		State.CONTACT:
			return CONTACT_COLOR
		State.ENGINE_ON:
			return ENGINE_ON_COLOR

	return OFF_COLOR


func _set_state(new_state: State) -> void:
	state = new_state

	var material := self.material as ShaderMaterial
	if not material:
		return

	if color_tween:
		color_tween.kill()

	color_tween = create_tween()
	color_tween.set_trans(Tween.TRANS_SINE)
	color_tween.set_ease(Tween.EASE_IN_OUT)

	var current_color: Color = material.get_shader_parameter("key_color")
	var target_color := _get_state_color()

	color_tween.tween_method(
		func(color: Color) -> void:
			material.set_shader_parameter("key_color", color),
		current_color,
		target_color,
		TRANSITION_DURATION
	)


func _on_pressed() -> void:
	var car := get_tree().current_scene.find_child(
		"Vehicle",
		true,
		false
	) as BaseCar

	if not car:
		return

	match state:
		State.OFF:
			_set_state(State.CONTACT)

		State.CONTACT:
			car.start()
			_set_state(State.ENGINE_ON)

		State.ENGINE_ON:
			car.stop()
			_set_state(State.OFF)
