extends Control
class_name ResizeHandle

@export var target: Control
@export var min_size: Vector2 = Vector2(360, 240)

var _dragging: bool = false
var _start_size: Vector2 = Vector2.ZERO
var _start_mouse: Vector2 = Vector2.ZERO

func _ready() -> void:
	visible = true
	size = Vector2(26, 26)

	# La poignée seule capture la souris (pas tout le panneau)
	mouse_filter = Control.MOUSE_FILTER_STOP

	# Coin bas-droit et ne s’étire pas
	set_anchors_preset(PRESET_BOTTOM_RIGHT, true)
	size_flags_horizontal = 0
	size_flags_vertical = 0

func _gui_input(event: InputEvent) -> void:
	var t: Control = (target if target != null else get_parent() as Control)
	if t == null:
		return

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_dragging = true
				_start_mouse = get_global_mouse_position()
				_start_size = t.size
				accept_event()
			else:
				_dragging = false
				accept_event()

	elif event is InputEventMouseMotion and _dragging:
		var delta: Vector2 = get_global_mouse_position() - _start_mouse
		var w: float = max(min_size.x, _start_size.x + delta.x)
		var h: float = max(min_size.y, _start_size.y + delta.y)
		t.custom_minimum_size = Vector2(w, h)
		t.size = Vector2(w, h)
		accept_event()

func _draw() -> void:
	# petit fond
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.25))
	# chevrons
	for i in 4:
		var off: float = 4.0 * i + 4.0
		draw_line(Vector2(size.x - off, size.y), Vector2(size.x, size.y - off), Color(1, 1, 1, 0.9), 1.0)
