extends PanelContainer
class_name DraggablePanel

var _title_label: Label
var _close_btn: Button
var _content_holder: VBoxContainer

var _dragging := false
var _drag_offset := Vector2.ZERO

func set_title(t: String) -> void:
	if _title_label:
		_title_label.text = t

func set_content(n: Control) -> void:
	if _content_holder == null:
		return
	for c in _content_holder.get_children():
		c.queue_free()
	if n:
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		n.size_flags_vertical   = Control.SIZE_EXPAND_FILL
		_content_holder.add_child(n)

func _ready() -> void:
	custom_minimum_size = Vector2(280, 140)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_PASS

	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	add_child(root)

	var header := HBoxContainer.new()
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(header)

	_title_label = Label.new()
	_title_label.text = "Panel"
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title_label)

	_close_btn = Button.new()
	_close_btn.text = "×"
	_close_btn.focus_mode = Control.FOCUS_NONE
	_close_btn.custom_minimum_size = Vector2(24, 24)
	header.add_child(_close_btn)
	_close_btn.pressed.connect(func(): hide())

	_content_holder = VBoxContainer.new()
	_content_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_holder.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	root.add_child(_content_holder)

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0,0,0,0.6)
	sb.set_corner_radius_all(6)
	add_theme_stylebox_override("panel", sb)

func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb := ev as InputEventMouseButton
		if mb.pressed:
			# drag uniquement sur l’en-tête (≈ 28 px)
			if get_local_mouse_position().y <= 28.0:
				_dragging = true
				_drag_offset = get_global_mouse_position() - global_position
				accept_event()
		else:
			_dragging = false
	elif ev is InputEventMouseMotion and _dragging:
		global_position = get_global_mouse_position() - _drag_offset
		accept_event()
