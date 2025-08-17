extends Control
signal spawn_media_requested(path: String)

const THUMB := 128

var image_path: String = ""

var _tex: TextureRect
var _lbl: Label

func setup(path: String) -> void:
	image_path = path

	# La tuile a une taille FIXE (pas d'expansion possible).
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	custom_minimum_size = Vector2(THUMB, THUMB + 18)
	size = custom_minimum_size
	size_flags_horizontal = 0
	size_flags_vertical = 0
	mouse_filter = Control.MOUSE_FILTER_STOP

	var root := VBoxContainer.new()
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	root.size_flags_horizontal = 0
	root.size_flags_vertical = 0
	add_child(root)

	_tex = TextureRect.new()
	_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_tex.custom_minimum_size = Vector2(THUMB, THUMB)
	_tex.size = Vector2(THUMB, THUMB)
	_tex.size_flags_horizontal = 0
	_tex.size_flags_vertical = 0
	root.add_child(_tex)

	_lbl = Label.new()
	_lbl.text = _basename(path)
	_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl.clip_text = true
	_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	_lbl.custom_minimum_size = Vector2(THUMB, 16)
	_lbl.size_flags_horizontal = 0
	_lbl.size_flags_vertical = 0
	root.add_child(_lbl)

	var img := Image.new()
	if img.load(path) == OK:
		_tex.texture = ImageTexture.create_from_image(img)

func _basename(p: String) -> String:
	var s := p
	var a := s.rfind("/")
	var b := s.rfind("\\")
	if b > a: a = b
	if a >= 0: s = s.substr(a + 1)
	var dot := s.rfind(".")
	if dot > 0: s = s.substr(0, dot)
	return s

# -------- Interaction --------

func _gui_input(ev: InputEvent) -> void:
	var mb := ev as InputEventMouseButton
	if mb and mb.button_index == MOUSE_BUTTON_LEFT and mb.double_click and not mb.pressed:
		spawn_media_requested.emit(image_path)

func get_drag_data(_at: Vector2) -> Variant:
	var data := {"type": "media_path", "path": image_path}
	var prev := TextureRect.new()
	prev.texture = _tex.texture
	prev.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	prev.custom_minimum_size = Vector2(64, 64)
	set_drag_preview(prev)
	return data

func can_drop_data(_pos: Vector2, _data: Variant) -> bool:
	return false
