extends Control

# ============ Managers ============
var account_manager: Node
var table_manager: Node

# ============ UI: Amis ============
var vbox_friends_root: Control
var scroll_friends: ScrollContainer
var vbox_friend_list: VBoxContainer
var hbox_add_friend: HBoxContainer
var line_add_friend: LineEdit
var btn_add_friend: Button

# ============ UI: Tables ============
var table_list_container: Control
var vbox_table_list: VBoxContainer
var btn_create_table: Button

# ============ UI: Titre / Divers ============
var label_welcome: Label
var btn_refresh: Button
var btn_back: Button
var btn_debug_storage: Button
var btn_show_session: Button

# ============ UI: Popups (Rename / Delete) ============
var popup_rename: PopupPanel
var lineedit_rename: LineEdit
var btn_rename_apply: Button
var btn_rename_cancel: Button

var popup_delete: PopupPanel
var label_delete_confirm: Label
var btn_delete_confirm: Button
var btn_delete_cancel: Button

# ============ State ============
var _selected_table_for_action: String = ""  # table_id

# Insère/replace "child" juste APRES "ref" dans "parent"
func _insert_below(parent: Node, ref: Node, child: Node) -> void:
	if parent == null or ref == null or child == null:
		return
	# si child n'est pas encore dans la scène -> l'ajouter
	if child.get_parent() == null:
		parent.add_child(child)
	# s'il est ailleurs -> reparenter
	elif child.get_parent() != parent:
		child.reparent(parent)
	# placer juste après ref
	var idx := parent.get_children().find(ref)
	if idx == -1:
		# fallback: fin de liste
		parent.move_child(child, parent.get_child_count() - 1)
	else:
		parent.move_child(child, idx + 1)

func _ready() -> void:
	account_manager = _find_am_autoload()
	table_manager   = _find_tm_autoload()

	# Boutons généraux
	label_welcome = _find_label_welcome()
	btn_refresh   = find_child("Button_Refresh", true, false) as Button
	btn_back      = find_child("Button_Back", true, false) as Button
	if btn_refresh != null:
		btn_refresh.pressed.connect(Callable(self, "_on_refresh_pressed"))
	if btn_back != null:
		btn_back.pressed.connect(Callable(self, "_on_back_pressed"))

	# Amis
	_ensure_friend_scroll_path()
	hbox_add_friend = null
	if vbox_friends_root != null:
		hbox_add_friend = vbox_friends_root.find_child("HBoxContainer", true, false) as HBoxContainer
	if hbox_add_friend != null:
		line_add_friend = hbox_add_friend.find_child("LineEdit_AddFriend", true, false) as LineEdit
		btn_add_friend  = hbox_add_friend.find_child("Button_AddFriend", true, false) as Button
		if btn_add_friend != null:
			btn_add_friend.pressed.connect(Callable(self, "_on_add_friend_pressed"))

	# Tables
	table_list_container = find_child("TableListContainer", true, false) as Control
	if table_list_container != null:
		vbox_table_list = table_list_container.find_child("VBox_TableList", true, false) as VBoxContainer
	btn_create_table = find_child("Button_CreateTable", true, false) as Button
	if btn_create_table != null:
		btn_create_table.pressed.connect(Callable(self, "_on_create_table_pressed"))

	# Popups
	_setup_or_create_popups()

	# Debug
	btn_debug_storage = find_child("Button_DebugStorage", true, false) as Button
	if btn_debug_storage == null:
		btn_debug_storage = Button.new()
		btn_debug_storage.name = "Button_DebugStorage"
		btn_debug_storage.text = "Debug Storage"
		if vbox_friends_root != null: vbox_friends_root.add_child(btn_debug_storage)
		else: add_child(btn_debug_storage)
	btn_debug_storage.pressed.connect(Callable(self, "_on_debug_storage_pressed"))

	btn_show_session = find_child("Button_ShowSession", true, false) as Button
	if btn_show_session == null:
		btn_show_session = Button.new()
		btn_show_session.name = "Button_ShowSession"
		btn_show_session.text = "Show Session"
		if vbox_friends_root != null: vbox_friends_root.add_child(btn_show_session)
		else: add_child(btn_show_session)
	btn_show_session.pressed.connect(Callable(self, "_on_show_session_pressed"))

	# Session + UI
	_ensure_current_user_loaded()
	_update_welcome_label_flexible()
	_refresh_friend_list()
	_refresh_table_list()
	_diagnose_session()
	
	_ensure_invited_block()

# -------------------------------------------------------------------
func _setup_or_create_popups() -> void:
	# RENAME
	popup_rename = find_child("PopupPanel_Rename", true, false) as PopupPanel
	if popup_rename == null:
		popup_rename = PopupPanel.new()
		popup_rename.name = "PopupPanel_Rename"
		var vb := VBoxContainer.new()
		vb.custom_minimum_size = Vector2(280, 0)
		lineedit_rename = LineEdit.new()
		lineedit_rename.name = "LineEdit_Rename"
		lineedit_rename.placeholder_text = "Nouveau nom de table"
		btn_rename_apply = Button.new()
		btn_rename_apply.name = "Button_Rename_Apply"
		btn_rename_apply.text = "Renommer"
		btn_rename_cancel = Button.new()
		btn_rename_cancel.name = "Button_Rename_Cancel"
		btn_rename_cancel.text = "Annuler"
		vb.add_child(lineedit_rename)
		vb.add_child(btn_rename_apply)
		vb.add_child(btn_rename_cancel)
		popup_rename.add_child(vb)
		add_child(popup_rename)
	else:
		lineedit_rename   = popup_rename.find_child("LineEdit_Rename", true, false) as LineEdit
		btn_rename_apply  = popup_rename.find_child("Button_Rename_Apply", true, false) as Button
		btn_rename_cancel = popup_rename.find_child("Button_Rename_Cancel", true, false) as Button
	if lineedit_rename != null:
		lineedit_rename.text_submitted.connect(Callable(self, "_on_rename_enter"))
	if btn_rename_apply != null:
		btn_rename_apply.pressed.connect(Callable(self, "_apply_rename_table"))
	if btn_rename_cancel != null:
		btn_rename_cancel.pressed.connect(Callable(self, "_close_rename_popup"))

	# DELETE
	popup_delete = find_child("PopupPanel_DeleteConfirm", true, false) as PopupPanel
	if popup_delete == null:
		popup_delete = PopupPanel.new()
		popup_delete.name = "PopupPanel_DeleteConfirm"
		var vb2 := VBoxContainer.new()
		vb2.custom_minimum_size = Vector2(300, 0)
		label_delete_confirm = Label.new()
		label_delete_confirm.name = "Label_DeleteConfirm"
		label_delete_confirm.text = "Supprimer cette table ?"
		btn_delete_confirm = Button.new()
		btn_delete_confirm.name = "Button_Delete_Confirm"
		btn_delete_confirm.text = "Confirmer"
		btn_delete_cancel = Button.new()
		btn_delete_cancel.name = "Button_Delete_Cancel"
		btn_delete_cancel.text = "Annuler"
		vb2.add_child(label_delete_confirm)
		vb2.add_child(btn_delete_confirm)
		vb2.add_child(btn_delete_cancel)
		popup_delete.add_child(vb2)
		add_child(popup_delete)
	else:
		label_delete_confirm = popup_delete.find_child("Label_DeleteConfirm", true, false) as Label
		btn_delete_confirm   = popup_delete.find_child("Button_Delete_Confirm", true, false) as Button
		btn_delete_cancel    = popup_delete.find_child("Button_Delete_Cancel", true, false) as Button
	if btn_delete_confirm != null:
		btn_delete_confirm.pressed.connect(Callable(self, "_confirm_delete_table"))
	if btn_delete_cancel != null:
		btn_delete_cancel.pressed.connect(Callable(self, "_close_delete_popup"))
# -------------------------------------------------------------------

# ======================= Helpers session/UI =======================
func _ensure_current_user_loaded() -> void:
	var uname: String = _get_current_username()
	if uname == "":
		return
	if account_manager != null and account_manager.has_method("get_user_data"):
		var v: Variant = account_manager.call("get_user_data", uname)
		var need_load: bool = (typeof(v) != TYPE_DICTIONARY) or ((v as Dictionary).is_empty())
		if need_load and account_manager.has_method("load_user"):
			account_manager.call("load_user", uname)

func _find_label_welcome() -> Label:
	var lbl := find_child("Label_Welcome", true, false) as Label
	if lbl != null:
		return lbl
	var stack: Array = [get_tree().get_current_scene()]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		if n is Label:
			var L: Label = n
			var t: String = L.text
			if t.find("<pseudo>") != -1 or t.to_lower().find("bienvenue") != -1:
				return L
	return null

func _update_welcome_label_flexible() -> void:
	var uname: String = _get_current_username()
	if label_welcome == null:
		label_welcome = _find_label_welcome()
	if label_welcome != null:
		if uname == "":
			label_welcome.text = "Bienvenue"
		else:
			if label_welcome.text.find("<pseudo>") != -1:
				label_welcome.text = label_welcome.text.replace("<pseudo>", uname)
			else:
				label_welcome.text = "Bienvenue " + uname
	if uname != "":
		var stack: Array = [get_tree().get_current_scene()]
		while not stack.is_empty():
			var n: Node = stack.pop_back()
			for c in n.get_children():
				stack.append(c)
			if n is Label:
				var L: Label = n
				if L.text.find("<pseudo>") != -1:
					L.text = L.text.replace("<pseudo>", uname)

# ======================= AMIS =======================
func _ensure_friend_scroll_path() -> void:
	vbox_friends_root = find_child("VBoxFriends", true, false) as Control
	if vbox_friends_root == null:
		return
	scroll_friends = vbox_friends_root.find_child("ScrollContainer", true, false) as ScrollContainer
	if scroll_friends == null:
		scroll_friends = ScrollContainer.new()
		scroll_friends.name = "ScrollContainer"
		scroll_friends.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll_friends.size_flags_vertical = Control.SIZE_EXPAND_FILL
		vbox_friends_root.add_child(scroll_friends)
	vbox_friend_list = scroll_friends.find_child("VBoxContainer_FriendList", true, false) as VBoxContainer
	if vbox_friend_list == null:
		vbox_friend_list = VBoxContainer.new()
		vbox_friend_list.name = "VBoxContainer_FriendList"
		vbox_friend_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vbox_friend_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll_friends.add_child(vbox_friend_list)

func _refresh_friend_list() -> void:
	_ensure_friend_scroll_path()
	if vbox_friend_list == null:
		return
	for c in vbox_friend_list.get_children():
		(c as Node).queue_free()

	var uname: String = _get_current_username()
	if uname == "":
		return
	var udata: Dictionary = _get_user_data(uname)
	if udata.is_empty():
		var row0 := HBoxContainer.new(); var lab0 := Label.new()
		lab0.text = "— aucun ami —"; row0.add_child(lab0); vbox_friend_list.add_child(row0)
		return

	var friends: Array = udata.get("friends", [])
	if friends.is_empty():
		var row := HBoxContainer.new(); var lab := Label.new()
		lab.text = "— aucun ami —"; row.add_child(lab); vbox_friend_list.add_child(row)
	else:
		for f in friends:
			var row2 := HBoxContainer.new()
			row2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var lab2 := Label.new()
			lab2.text = str(f)
			lab2.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			lab2.custom_minimum_size = Vector2(0, 22)
			row2.add_child(lab2)
			vbox_friend_list.add_child(row2)

func _on_add_friend_pressed() -> void:
	var uname: String = _get_current_username()
	if uname == "":
		return
	var friend_name: String = ""
	if line_add_friend != null:
		friend_name = line_add_friend.text.strip_edges()
	if friend_name == "":
		return
	if account_manager != null and account_manager.has_method("add_friend"):
		var ok: bool = bool(account_manager.call("add_friend", uname, friend_name))
		if ok and line_add_friend != null:
			line_add_friend.text = ""
	_refresh_friend_list()
	_diagnose_session()

# ======================= TABLES =======================
func _extract_table_id(item: Variant) -> String:
	if typeof(item) == TYPE_STRING:
		return str(item)
	if typeof(item) == TYPE_DICTIONARY:
		var d: Dictionary = item
		for k in ["table_id","id","uuid","uid","tid"]:
			if d.has(k):
				return str(d[k])
		if d.size() == 1:
			var vs: Array = d.values()
			if vs.size() == 1 and typeof(vs[0]) != TYPE_DICTIONARY:
				return str(vs[0])
	return ""

func _extract_table_name(item: Variant, fallback: String) -> String:
	if typeof(item) == TYPE_DICTIONARY:
		var d: Dictionary = item
		if d.has("table_name"): return str(d["table_name"])
		if d.has("name"): return str(d["name"])
		if d.size() == 1:
			var ks: Array = d.keys()
			if ks.size() == 1: return str(ks[0])
	return fallback

func _refresh_table_list() -> void:
	var uname := _get_current_username()
	if uname == "":
		return

	# (Optionnel) purges que nous avons ajoutées précédemment
	if account_manager != null and account_manager.has_method("purge_current_user_invalid_tables"):
		account_manager.call("purge_current_user_invalid_tables")
	if account_manager != null and account_manager.has_method("purge_current_user_non_member_tables"):
		account_manager.call("purge_current_user_non_member_tables")

	_ensure_table_blocks()

	var container := find_child("TableListContainer", true, false)
	if container == null:
		return
	var vbox_my := container.find_child("VBox_TableList", true, false) as VBoxContainer
	var vbox_joined := container.find_child("VBox_JoinedTables", true, false) as VBoxContainer
	if vbox_my == null or vbox_joined == null:
		return

	_clear_children(vbox_my)
	_clear_children(vbox_joined)

	# Récupère les tables "re-jointes" côté user
	var joined: Array = []
	if account_manager != null and account_manager.has_method("get_user_data"):
		var d: Variant = account_manager.call("get_user_data", uname)
		if typeof(d) == TYPE_DICTIONARY:
			joined = (d as Dictionary).get("tables_joined", [])

	if joined.is_empty():
		var row0 := HBoxContainer.new()
		var lab0 := Label.new()
		lab0.text = "— aucune table —"
		row0.add_child(lab0)
		vbox_my.add_child(row0)
	else:
		for it in joined:
			var tid := ""
			if typeof(it) == TYPE_STRING:
				tid = str(it)
			elif typeof(it) == TYPE_DICTIONARY:
				var dd: Dictionary = it
				tid = str(dd.get("table_id", dd.get("id","")))
			if tid == "":
				continue

			# Charger infos table
			var tname := "Table"
			var owner := ""
			var exists := true
			if table_manager != null and table_manager.has_method("table_exists"):
				exists = bool(table_manager.call("table_exists", tid))
			if not exists:
				# Nettoie la référence locale
				if account_manager != null and account_manager.has_method("remove_joined_table"):
					account_manager.call("remove_joined_table", tid)
				continue

			if table_manager != null and table_manager.has_method("get_table_data"):
				var td_v: Variant = table_manager.call("get_table_data", tid)
				if typeof(td_v) == TYPE_DICTIONARY:
					var td: Dictionary = td_v
					tname = str(td.get("table_name","Table"))
					owner = str(td.get("owner_username",""))

			var am_owner := (uname != "" and owner != "" and uname == owner)

			# Redirige vers "Vos tables" ou "Tables rejointes"
			if am_owner:
				_build_table_row_into(vbox_my, tid, tname, owner, true)
			else:
				_build_table_row_into(vbox_joined, tid, tname, owner, false)

	# Rafraîchit le bloc "Tables invitées"
	_ensure_invited_block()
	_refresh_invited_list()


func _build_table_row(table_dict: Dictionary) -> void:
	if table_dict.is_empty():
		return
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var name: String = "Nouvelle Table"
	if table_dict.has("table_name"):
		name = str(table_dict["table_name"])
	elif table_dict.has("name"):
		name = str(table_dict["name"])

	var tid: String = ""
	if table_dict.has("table_id"):
		tid = str(table_dict["table_id"])
	elif table_dict.has("id"):
		tid = str(table_dict["id"])
	elif table_dict.size() == 1:
		var vs: Array = table_dict.values()
		if vs.size() == 1 and typeof(vs[0]) != TYPE_DICTIONARY:
			tid = str(vs[0])
		var ks: Array = table_dict.keys()
		if ks.size() == 1 and name == "Nouvelle Table":
			name = str(ks[0])

	var lbl := Label.new()
	lbl.text = name
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.add_child(lbl)

	# ▶ Ouvrir
	var btn_open := Button.new()
	btn_open.text = "▶ Ouvrir"
	btn_open.disabled = (tid == "")
	btn_open.pressed.connect(Callable(self, "_on_open_table").bind(tid))
	row.add_child(btn_open)

	# ✏️ Renommer
	var btn_edit := Button.new()
	btn_edit.text = "✏️"; btn_edit.tooltip_text = "Renommer"
	btn_edit.disabled = (tid == "")
	btn_edit.pressed.connect(Callable(self, "_on_click_rename_table").bind(tid))
	row.add_child(btn_edit)

	# 🗑️ Supprimer
	var btn_del := Button.new()
	btn_del.text = "🗑️"; btn_del.tooltip_text = "Supprimer"
	btn_del.disabled = (tid == "")
	btn_del.pressed.connect(Callable(self, "_on_click_delete_table").bind(tid, name))
	row.add_child(btn_del)

	vbox_table_list.add_child(row)

func _on_create_table_pressed() -> void:
	var uname: String = _get_current_username()
	if uname == "":
		return
	var tid: String = ""
	if table_manager != null and table_manager.has_method("create_table"):
		tid = str(table_manager.call("create_table", uname, "Nouvelle Table"))
	if tid == "":
		return
	if account_manager != null and account_manager.has_method("add_joined_table"):
		account_manager.call("add_joined_table", tid)
	_refresh_table_list()
	_update_welcome_label_flexible()
	_diagnose_session()

# ---- Open (TableRoomScreen prioritaire) ----
func _on_open_table(table_id: String) -> void:
	if table_id == "":
		return

	# Purge si la table n'existe plus
	if table_manager != null and table_manager.has_method("table_exists"):
		var exists: bool = bool(table_manager.call("table_exists", table_id))
		if not exists:
			if account_manager != null and account_manager.has_method("remove_joined_table"):
				account_manager.call("remove_joined_table", table_id)
			_refresh_table_list()
			push_warning("[MM] Table introuvable. Elle a été retirée de votre liste.")
			return

	# Sélectionne la table courante
	if table_manager != null and table_manager.has_method("set_current_table_id"):
		table_manager.call("set_current_table_id", table_id)

	# Ouvre la première scène disponible
	var candidates: Array = [
		"res://Scenes/TableRoom.tscn",
		"res://Scenes/TableRoomScreen.tscn",
		"res://Scenes/Table.tscn",
		"res://Scenes/Game/TableRoom.tscn",
		"res://Scenes/Dev/TableRoom.tscn"
	]
	for p in candidates:
		if ResourceLoader.exists(p):
			get_tree().change_scene_to_file(p)
			return

	push_warning("[MM] Aucune scène TableRoom trouvée.")

# ---- Rename ----
func _on_click_rename_table(table_id: String) -> void:
	if table_id == "":
		return
	_selected_table_for_action = table_id
	if lineedit_rename != null and table_manager != null and table_manager.has_method("get_table_data"):
		var v: Variant = table_manager.call("get_table_data", table_id)
		if typeof(v) == TYPE_DICTIONARY:
			var d: Dictionary = v
			lineedit_rename.text = str(d.get("table_name", "Nouvelle Table"))
	if popup_rename != null:
		popup_rename.popup_centered()

func _on_rename_enter(_text: String) -> void:
	_apply_rename_table()

func _apply_rename_table() -> void:
	if _selected_table_for_action == "":
		return
	var new_name: String = "Nouvelle Table"
	if lineedit_rename != null:
		var t: String = lineedit_rename.text.strip_edges()
		if t != "":
			new_name = t
	var ok: bool = false
	if table_manager != null and table_manager.has_method("rename_table"):
		ok = bool(table_manager.call("rename_table", _selected_table_for_action, new_name))
	print("[MM] rename_table tid=", _selected_table_for_action, " -> ", ok)
	_close_rename_popup()
	if ok:
		_refresh_table_list()
	_diagnose_session()

func _close_rename_popup() -> void:
	if popup_rename != null:
		popup_rename.hide()
	_selected_table_for_action = ""

# ---- Delete ----
func _on_click_delete_table(table_id: String, table_name: String) -> void:
	if table_id == "":
		return
	_selected_table_for_action = table_id

	# Si je ne suis pas propriétaire -> quitter au lieu de supprimer
	var uname: String = _get_current_username()
	var not_owner: bool = false
	if table_manager != null and table_manager.has_method("is_owner"):
		not_owner = not bool(table_manager.call("is_owner", table_id, uname))

	if not_owner:
		_on_leave_table(table_id)
		return

	# Récupère un nom lisible
	var name_to_show: String = table_name
	if name_to_show == "":
		if table_manager != null and table_manager.has_method("get_table_data"):
			var v: Variant = table_manager.call("get_table_data", table_id)
			if typeof(v) == TYPE_DICTIONARY:
				name_to_show = str((v as Dictionary).get("table_name", ""))
	if name_to_show == "":
		name_to_show = "cette table"

	if label_delete_confirm != null:
		label_delete_confirm.text = "Supprimer la table « {0} » ?".format([name_to_show])
	if popup_delete != null:
		popup_delete.popup_centered()


func _confirm_delete_table() -> void:
	if _selected_table_for_action == "":
		return
	var tid: String = _selected_table_for_action
	var deleted: bool = false
	if table_manager != null and table_manager.has_method("delete_table"):
		deleted = bool(table_manager.call("delete_table", tid))
	print("[MM] delete_table tid=", tid, " -> ", deleted)

	if account_manager != null and account_manager.has_method("remove_joined_table"):
		account_manager.call("remove_joined_table", tid)

	_close_delete_popup()
	_refresh_table_list()
	_diagnose_session()

func _close_delete_popup() -> void:
	if popup_delete != null:
		popup_delete.hide()
	_selected_table_for_action = ""

# ======================= DEBUG =======================
func _on_debug_storage_pressed() -> void:
	if account_manager != null and account_manager.has_method("debug_report_storage"):
		account_manager.call("debug_report_storage")

func _on_show_session_pressed() -> void:
	_diagnose_session()

func _on_refresh_pressed() -> void:
	_ensure_current_user_loaded()
	_update_welcome_label_flexible()
	_refresh_friend_list()
	_refresh_table_list()
	_diagnose_session()

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/Login.tscn")

func _diagnose_session() -> void:
	var am_is_autoload: bool = (account_manager != null and account_manager.get_parent() == get_tree().get_root())
	print("[MM] AM=", account_manager, " (autoload=", am_is_autoload, ")")
	var uname: String = _get_current_username()
	print("[MM] current_username=", uname)
	if uname != "":
		var d: Dictionary = _get_user_data(uname)
		print("[MM] user_data keys=", d.keys())
		print("[MM] friends=", d.get("friends", []))
		print("[MM] tables_joined(raw)=", d.get("tables_joined", []))

# ======================= HELPERS =======================
func _find_am_autoload() -> Node:
	var root: Node = get_tree().get_root()
	if root != null:
		var aut: Node = root.find_child("AccountManager", false, false)
		if aut != null:
			return aut
	var cs: Node = get_tree().get_current_scene()
	if cs != null:
		var local_am: Node = cs.find_child("AccountManager", true, false)
		if local_am != null:
			return local_am
	return null

func _find_tm_autoload() -> Node:
	var root: Node = get_tree().get_root()
	if root != null:
		var aut: Node = root.find_child("TableManager", false, false)
		if aut != null:
			return aut
	var cs: Node = get_tree().get_current_scene()
	if cs != null:
		var local_tm: Node = cs.find_child("TableManager", true, false)
		if local_tm != null:
			return local_tm
	return null

func _get_current_username() -> String:
	if account_manager != null and account_manager.has_method("get_current_username"):
		return str(account_manager.call("get_current_username"))
	return ""

func _get_user_data(username: String) -> Dictionary:
	if account_manager != null and account_manager.has_method("get_user_data"):
		var v: Variant = account_manager.call("get_user_data", username)
		if typeof(v) == TYPE_DICTIONARY:
			return v
	return {}

func _on_leave_table(table_id: String) -> void:
	if table_id == "":
		return
	var uname: String = _get_current_username()
	if uname == "":
		return

	# Nettoyage côté table (participants/invited)
	if table_manager != null and table_manager.has_method("remove_user_from_table"):
		table_manager.call("remove_user_from_table", table_id, uname)

	# Retirer de ma liste locale
	if account_manager != null and account_manager.has_method("remove_joined_table"):
		account_manager.call("remove_joined_table", table_id)

	_refresh_table_list()
	_diagnose_session()
	
# -- crée au besoin le bloc "Tables invitées" sous TableListContainer --
func _ensure_invited_block() -> void:
	var vbox_my := find_child("VBox_TableList", true, false) as VBoxContainer
	if vbox_my == null:
		return
	var parent := vbox_my.get_parent()
	if parent == null:
		return

	var invited_title := parent.find_child("Label_InvitedTables", false, false) as Label
	if invited_title == null:
		invited_title = Label.new()
		invited_title.name = "Label_InvitedTables"
		invited_title.text = "Tables invitées"

	var vbox_invited := parent.find_child("VBox_InvitedTables", false, false) as VBoxContainer
	if vbox_invited == null:
		vbox_invited = VBoxContainer.new()
		vbox_invited.name = "VBox_InvitedTables"
		vbox_invited.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# insérer les deux blocs juste après "Vos tables"
	_insert_below(parent, vbox_my, invited_title)
	_insert_below(parent, invited_title, vbox_invited)



func _on_accept_invite_pressed(table_id: String) -> void:
	var uname := _get_current_username()
	if table_id == "" or uname == "":
		return
	# Ajoute dans tables_joined + retire l’invitation
	if account_manager != null and account_manager.has_method("add_joined_table"):
		account_manager.call("add_joined_table", table_id)
	if account_manager != null and account_manager.has_method("remove_invitation"):
		account_manager.call("remove_invitation", uname, table_id)
	# On rafraîchit les deux listes
	_refresh_table_list()
	_refresh_invited_list()

func _on_decline_invite_pressed(table_id: String) -> void:
	var uname := _get_current_username()
	if table_id == "" or uname == "":
		return
	if account_manager != null and account_manager.has_method("remove_invitation"):
		account_manager.call("remove_invitation", uname, table_id)
	_refresh_invited_list()

# -- crée les blocs (titres + vboxes) si absents --
# Retourne/ crée le conteneur scrollable qui contiendra toutes les listes
func _ensure_tables_area() -> VBoxContainer:
	var container := find_child("TableListContainer", true, false)
	if container == null:
		return null

	# Cherche un ScrollContainer sous TableListContainer (ou crée-le)
	var sc := container.find_child("ScrollContainer", true, false) as ScrollContainer
	if sc == null:
		sc = ScrollContainer.new()
		sc.name = "ScrollContainer"
		sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
		container.add_child(sc)

	# Cherche/ crée la VBox principale
	var area := container.find_child("VBox_TablesArea", true, false) as VBoxContainer
	if area == null:
		area = VBoxContainer.new()
		area.name = "VBox_TablesArea"
		area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sc.add_child(area)
	return area

func _ensure_table_blocks() -> void:
	var area := _ensure_tables_area()
	if area == null:
		return

	# Vos tables : on réutilise VBox_TableList si présent, sinon on le crée
	var vbox_my := area.find_child("VBox_TableList", false, false) as VBoxContainer
	if vbox_my == null:
		vbox_my = VBoxContainer.new()
		vbox_my.name = "VBox_TableList"
		area.add_child(vbox_my)

	# Titre "Tables rejointes" + VBox_JoinedTables
	var lbl_joined := area.find_child("Label_JoinedTables", false, false) as Label
	if lbl_joined == null:
		lbl_joined = Label.new()
		lbl_joined.name = "Label_JoinedTables"
		lbl_joined.text = "Tables rejointes"
		area.add_child(lbl_joined)

	var vbox_joined := area.find_child("VBox_JoinedTables", false, false) as VBoxContainer
	if vbox_joined == null:
		vbox_joined = VBoxContainer.new()
		vbox_joined.name = "VBox_JoinedTables"
		vbox_joined.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		area.add_child(vbox_joined)

	# Titre "Tables invitées" + VBox_InvitedTables
	var lbl_inv := area.find_child("Label_InvitedTables", false, false) as Label
	if lbl_inv == null:
		lbl_inv = Label.new()
		lbl_inv.name = "Label_InvitedTables"
		lbl_inv.text = "Tables invitées"
		area.add_child(lbl_inv)

	var vbox_inv := area.find_child("VBox_InvitedTables", false, false) as VBoxContainer
	if vbox_inv == null:
		vbox_inv = VBoxContainer.new()
		vbox_inv.name = "VBox_InvitedTables"
		vbox_inv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		area.add_child(vbox_inv)

	# Assure l’ordre: Vos tables -> Rejointes -> Invitée
	var order: Array[Node] = []
	if vbox_my != null: order.append(vbox_my)
	if lbl_joined != null: order.append(lbl_joined)
	if vbox_joined != null: order.append(vbox_joined)
	if lbl_inv != null: order.append(lbl_inv)
	if vbox_inv != null: order.append(vbox_inv)

	for i in range(order.size()):
		area.move_child(order[i], i)


func _clear_children(node: Node) -> void:
	if node == null: return
	for c in node.get_children():
		(c as Node).queue_free()

func _refresh_invited_list() -> void:
	var area := _ensure_tables_area()
	if area == null:
		return
	var vbox_inv := area.find_child("VBox_InvitedTables", false, false) as VBoxContainer
	if vbox_inv == null:
		return
	_clear_children(vbox_inv)

	var uname := _get_current_username()
	if uname == "":
		return

	var invitations: Array = []
	if account_manager != null and account_manager.has_method("get_user_data"):
		var d: Variant = account_manager.call("get_user_data", uname)
		if typeof(d) == TYPE_DICTIONARY:
			invitations = (d as Dictionary).get("invitations", [])

	if invitations.is_empty():
		var row0 := HBoxContainer.new()
		var lab0 := Label.new()
		lab0.text = "— aucune invitation —"
		row0.add_child(lab0)
		vbox_inv.add_child(row0)
		return

	for it in invitations:
		var tid := str(it) if typeof(it) == TYPE_STRING else str((it as Dictionary).get("table_id", ""))
		if tid == "":
			continue

		var tname := "Table"
		var owner := ""
		if table_manager != null and table_manager.has_method("get_table_data"):
			var td_v: Variant = table_manager.call("get_table_data", tid)
			if typeof(td_v) == TYPE_DICTIONARY:
				var td: Dictionary = td_v
				tname = str(td.get("table_name","Table"))
				owner = str(td.get("owner_username",""))

		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var lab := Label.new()
		lab.text = "%s  (MJ: %s)" % [tname, owner]
		lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(lab)

		var btn_ok := Button.new()
		btn_ok.text = "Accepter"
		btn_ok.pressed.connect(Callable(self, "_on_accept_invite_pressed").bind(tid))
		row.add_child(btn_ok)

		var btn_no := Button.new()
		btn_no.text = "Refuser"
		btn_no.pressed.connect(Callable(self, "_on_decline_invite_pressed").bind(tid))
		row.add_child(btn_no)

		vbox_inv.add_child(row)



# Construit une ligne pour une table dans le vbox cible
func _build_table_row_into(vbox: VBoxContainer, tid: String, tname: String, owner: String, am_owner: bool) -> void:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Label
	var lab := Label.new()
	lab.text = "%s  (MJ: %s)" % [tname, owner]
	lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lab)

	# ▶ Ouvrir
	var btn_open := Button.new()
	btn_open.text = "▶ Ouvrir"
	btn_open.disabled = (tid == "")
	btn_open.pressed.connect(Callable(self, "_on_open_table").bind(tid))
	row.add_child(btn_open)

	if am_owner:
		# ✏️ Renommer
		var btn_edit := Button.new()
		btn_edit.text = "✏️"
		btn_edit.tooltip_text = "Renommer"
		btn_edit.disabled = (tid == "")
		btn_edit.pressed.connect(Callable(self, "_on_click_rename_table").bind(tid))
		row.add_child(btn_edit)

		# 🗑️ Supprimer
		var btn_del := Button.new()
		btn_del.text = "🗑️"
		btn_del.tooltip_text = "Supprimer"
		btn_del.disabled = (tid == "")
		# on passe aussi le nom pour le popup (évite %s brut)
		btn_del.pressed.connect(Callable(self, "_on_click_delete_table").bind(tid, tname))
		row.add_child(btn_del)
	else:
		# 🚪 Quitter
		var btn_leave := Button.new()
		btn_leave.text = "🚪 Quitter"
		btn_leave.disabled = (tid == "")
		btn_leave.pressed.connect(Callable(self, "_on_leave_table").bind(tid))
		row.add_child(btn_leave)

	vbox.add_child(row)
