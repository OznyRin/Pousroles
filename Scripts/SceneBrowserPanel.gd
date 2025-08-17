extends Control
class_name SceneBrowserPanel

signal activate_scene_requested(scene_id: String)
signal move_user_requested(user_id: String, scene_id: String)
signal move_gm_requested(scene_id: String)

var _active_id: String = ""
var _scenes: Array = []  # [{id,name,thumb_path,players:[{id,name,scene_id,is_gm}],gm_here:bool}]

var _root: VBoxContainer = null
var _scroll: ScrollContainer = null
var _list: VBoxContainer = null

func _ready() -> void:
	_ensure_built()

# -- construit l’UI si besoin (utile si set_model() est appelé avant _ready)
func _ensure_built() -> void:
	if _list != null and is_instance_valid(_list):
		return

	# racine
	if _root == null or not is_instance_valid(_root):
		_root = VBoxContainer.new()
		_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
		add_child(_root)

	# scroll
	if _scroll == null or not is_instance_valid(_scroll):
		_scroll = ScrollContainer.new()
		_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		_root.add_child(_scroll)

	# liste
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 8)
	_scroll.add_child(_list)

func set_model(model: Dictionary) -> void:
	_ensure_built()
	_active_id = String(model.get("active", ""))
	var arr_v: Variant = model.get("scenes", [])
	var arr: Array = []
	if arr_v is Array:
		arr = arr_v
	_scenes = arr
	_rebuild()

func _clear() -> void:
	_ensure_built()
	for c in _list.get_children():
		c.queue_free()

func _rebuild() -> void:
	_ensure_built()
	_clear()
	for s_v in _scenes:
		if typeof(s_v) != TYPE_DICTIONARY:
			continue
		var s: Dictionary = s_v
		var id: String = String(s.get("id", ""))
		if id == "":
			continue
		var name: String = String(s.get("name", id))
		var players: Array = []
		var p_v: Variant = s.get("players", [])
		if p_v is Array:
			players = p_v
		var gm_here: bool = bool(s.get("gm_here", false))
		var thumb: String = String(s.get("thumb_path", ""))
		_list.add_child(_make_card(id, name, thumb, players, gm_here))

func _make_card(id: String, name: String, thumb_path: String, players: Array, gm_here: bool) -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.25)
	sb.corner_radius_top_left = 6; sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6; sb.corner_radius_bottom_right = 6
	panel.add_theme_stylebox_override("panel", sb)

	var card := VBoxContainer.new()
	card.add_theme_constant_override("separation", 6)
	panel.add_child(card)

	# Ligne titre + actions
	var top := HBoxContainer.new()
	top.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_child(top)

	var title := Label.new()
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if id == _active_id:
		title.text = "★ " + name
	else:
		title.text = name
	top.add_child(title)

	var btn_act := Button.new()
	btn_act.text = "Activer"
	btn_act.disabled = (id == _active_id)
	btn_act.pressed.connect(func(): activate_scene_requested.emit(id))
	top.add_child(btn_act)

	var btn_mj := Button.new()
	if gm_here:
		btn_mj.text = "MJ ici"
		btn_mj.disabled = true
	else:
		btn_mj.text = "MJ →"
		btn_mj.disabled = false
	btn_mj.pressed.connect(func(): move_gm_requested.emit(id))
	top.add_child(btn_mj)

	# (facultatif) prévisualisation
	if thumb_path != "" and FileAccess.file_exists(thumb_path):
		var preview := TextureRect.new()
		preview.custom_minimum_size = Vector2(240, 120)
		preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var img := Image.new()
		if img.load(thumb_path) == OK:
			preview.texture = ImageTexture.create_from_image(img)
		card.add_child(preview)

	# Ligne joueurs
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	card.add_child(row)

	var lbl := Label.new()
	lbl.text = "Joueurs :"
	row.add_child(lbl)

	for p_v in players:
		if typeof(p_v) != TYPE_DICTIONARY:
			continue
		var p: Dictionary = p_v
		var uid: String = String(p.get("id", ""))
		var uname: String = String(p.get("name", uid))
		var here: bool = String(p.get("scene_id", "")) == id

		var b := Button.new()
		if here:
			b.text = uname
			b.disabled = true
		else:
			b.text = uname + " →"
			b.disabled = false
		b.pressed.connect(func(): move_user_requested.emit(uid, id))
		row.add_child(b)

	return panel
