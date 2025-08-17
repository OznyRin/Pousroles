extends Control
class_name SceneManagerPanel
##
## Gestionnaire de scènes (UI + signaux)
##

# — Signaux vers l’hôte (TableGame) —
signal create_scene_requested
signal activate_scene_requested(scene_id: String)
signal rename_scene_requested(scene_id: String, new_name: String)
signal delete_scene_requested(scene_id: String)
signal move_user_requested(user_id: String, scene_id: String)
signal move_gm_requested(scene_id: String)
signal refresh_requested

# --- Modèle courant ---
var _model: Dictionary = {} # voir format ci-dessous
var _selected_scene_id: String = ""

# --- UI refs ---
var _scenes_list: VBoxContainer
var _right: VBoxContainer
var _name_edit: LineEdit
var _btn_activate: Button
var _btn_delete: Button
var _btn_move_gm: Button
var _players_box: VBoxContainer

func _ready() -> void:
	var root := HSplitContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	add_child(root)

	# Colonne gauche (liste scènes)
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(260, 320)
	left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(left)

	var topbar := HBoxContainer.new()
	left.add_child(topbar)

	var title := Label.new()
	title.text = "Scènes"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	topbar.add_child(title)

	var btn_new := Button.new()
	btn_new.text = "+ Nouvelle"
	btn_new.tooltip_text = "Créer une nouvelle scène"
	btn_new.focus_mode = Control.FOCUS_NONE
	btn_new.pressed.connect(func(): emit_signal("create_scene_requested"))
	topbar.add_child(btn_new)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(scroll)

	_scenes_list = VBoxContainer.new()
	_scenes_list.add_theme_constant_override("separation", 4)
	scroll.add_child(_scenes_list)

	# Colonne droite (détails)
	_right = VBoxContainer.new()
	_right.custom_minimum_size = Vector2(380, 320)
	_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_right.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	root.add_child(_right)

	var h := HBoxContainer.new()
	_right.add_child(h)

	var lbl := Label.new()
	lbl.text = "Nom :"
	h.add_child(lbl)

	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "Nom de la scène"
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_edit.text_submitted.connect(func(t: String): _emit_rename(t))
	h.add_child(_name_edit)

	var btn_rename := Button.new()
	btn_rename.text = "Renommer"
	btn_rename.focus_mode = Control.FOCUS_NONE
	btn_rename.pressed.connect(func(): _emit_rename(_name_edit.text))
	h.add_child(btn_rename)

	var actions := HBoxContainer.new()
	_right.add_child(actions)

	_btn_activate = Button.new()
	_btn_activate.text = "Activer"
	_btn_activate.focus_mode = Control.FOCUS_NONE
	_btn_activate.pressed.connect(func():
		if _selected_scene_id != "":
			emit_signal("activate_scene_requested", _selected_scene_id)
	)
	actions.add_child(_btn_activate)

	_btn_move_gm = Button.new()
	_btn_move_gm.text = "Déplacer le MJ ici"
	_btn_move_gm.focus_mode = Control.FOCUS_NONE
	_btn_move_gm.pressed.connect(func():
		if _selected_scene_id != "":
			emit_signal("move_gm_requested", _selected_scene_id)
	)
	actions.add_child(_btn_move_gm)

	_btn_delete = Button.new()
	_btn_delete.text = "Supprimer"
	_btn_delete.focus_mode = Control.FOCUS_NONE
	_btn_delete.pressed.connect(func():
		if _selected_scene_id != "":
			emit_signal("delete_scene_requested", _selected_scene_id)
	)
	actions.add_child(_btn_delete)

	var sep := HSeparator.new()
	_right.add_child(sep)

	var players_title := Label.new()
	players_title.text = "Joueurs :"
	_right.add_child(players_title)

	var scroll_p := ScrollContainer.new()
	scroll_p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_p.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_right.add_child(scroll_p)

	_players_box = VBoxContainer.new()
	_players_box.add_theme_constant_override("separation", 2)
	scroll_p.add_child(_players_box)

	var refresh_line := HBoxContainer.new()
	_right.add_child(refresh_line)
	var btn_refresh := Button.new()
	btn_refresh.text = "↻ Actualiser"
	btn_refresh.pressed.connect(func(): emit_signal("refresh_requested"))
	refresh_line.add_child(btn_refresh)

	_set_details_enabled(false)

func set_model(model: Dictionary) -> void:
	# Format attendu :
	# {
	#   "active": "sceneId",
	#   "scenes": [
	#       {"id":"scene1","name":"Ville","players":["u1","u2"],"gm_here":false},
	#       {"id":"scene2","name":"Donjon","players":[],"gm_here":true}
	#   ],
	#   "players": [
	#       {"id":"u1","name":"Alice","scene_id":"scene1","is_gm":false},
	#       {"id":"u2","name":"Bob","scene_id":"scene2","is_gm":false},
	#       {"id":"gm","name":"MJ","scene_id":"scene2","is_gm":true}
	#   ]
	# }
	_model = model.duplicate(true)
	_rebuild_scene_list()

func _rebuild_scene_list() -> void:
	for c in _scenes_list.get_children():
		c.queue_free()

	var active_id: String = _model.get("active", "")
	var scenes: Array = _model.get("scenes", [])
	for s in scenes:
		var id: String = s.get("id", "")
		var name: String = s.get("name", id)
		var players: Array = s.get("players", [])
		var gm_here: bool = s.get("gm_here", false)

		var btn := Button.new()
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.focus_mode = Control.FOCUS_NONE

		var suffix := ""
		if gm_here:
			suffix += "  [MJ]"
		suffix += "  (" + str(players.size()) + ")"

		btn.text = ("★ " if id == active_id else "") + name + suffix
		btn.pressed.connect(func():
			_selected_scene_id = id
			_refresh_details()
		)
		_scenes_list.add_child(btn)

	if _selected_scene_id == "" and active_id != "":
		_selected_scene_id = active_id
	_refresh_details()

func _refresh_details() -> void:
	if _selected_scene_id == "":
		_set_details_enabled(false)
		return

	_set_details_enabled(true)

	var scenes: Array = _model.get("scenes", [])
	var active_id: String = _model.get("active", "")
	var scene := {}
	for s in scenes:
		if s.get("id","") == _selected_scene_id:
			scene = s
			break

	var scene_name: String = scene.get("name", _selected_scene_id)
	_name_edit.text = scene_name

	_btn_activate.disabled = (_selected_scene_id == active_id)

	for c in _players_box.get_children(): c.queue_free()

	var players: Array = _model.get("players", [])
	for p in players:
		var uid: String = p.get("id","")
		var uname: String = p.get("name", uid)
		var cur_scene: String = p.get("scene_id","")
		var is_gm: bool = p.get("is_gm", false)

		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_players_box.add_child(row)

		var l := Label.new()
		l.text = ("(MJ) " if is_gm else "") + uname
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)

		if is_gm:
			var b := Button.new()
			b.text = ("Ici" if cur_scene == _selected_scene_id else "Déplacer le MJ")
			b.disabled = (cur_scene == _selected_scene_id)
			b.pressed.connect(func():
				emit_signal("move_gm_requested", _selected_scene_id)
			)
			row.add_child(b)
		else:
			var b2 := Button.new()
			b2.text = ("Ici" if cur_scene == _selected_scene_id else "Déplacer ici")
			b2.disabled = (cur_scene == _selected_scene_id)
			b2.pressed.connect(func():
				emit_signal("move_user_requested", uid, _selected_scene_id)
			)
			row.add_child(b2)

func _emit_rename(t: String) -> void:
	var nm := t.strip_edges()
	if nm != "" and _selected_scene_id != "":
		emit_signal("rename_scene_requested", _selected_scene_id, nm)

func _set_details_enabled(on: bool) -> void:
	_name_edit.editable = on
	_btn_activate.disabled = not on
	_btn_delete.disabled = not on
	_btn_move_gm.disabled = not on
