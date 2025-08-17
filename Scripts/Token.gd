extends Node2D

@onready var sprite := find_child("Sprite2D")

func _ready():
	set_process(true)

func _process(delta):
	if is_multiplayer_authority():
		var input = Vector2(
			Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left"),
			Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
		)
		if input.length() > 0:
			position += input.normalized() * 100 * delta
			rpc("update_position", position)  # ✅ Utiliser `rpc` ici

@rpc("any_peer", "unreliable")
func update_position(new_pos: Vector2):
	position = new_pos

func _unhandled_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		position = get_global_mouse_position()
