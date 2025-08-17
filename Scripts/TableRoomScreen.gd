extends Control

# Managers
var table_manager: Node
var account_manager: Node

# UI existante (mappée sur la nouvelle hiérarchie)
var label_name: Label
var label_players: Label
var btn_back: Button
var btn_enter: Button

# UI d'invitation (noms actualisés)
var hbox_invite: HBoxContainer
var opt_friend: OptionButton
var opt_role: OptionButton # reste null (pas présent dans la hiérarchie)
var btn_invite: Button

# Liste interactive des invités
var label_invites_title: Label
var vbox_invited_list: VBoxContainer

# Etat
var _tid: String = ""
var _current_user: String = ""

func _ready() -> void:
	table_manager = _find_tm_autoload()
	account_manager = _find_am_autoload()

	# -- nouveaux noms --
	label_name    = find_child("Label_Title", true, false) as Label
	label_players = find_child("Label_Invited", true, false) as Label
	btn_back      = find_child("Button_Back", true, false) as Button
	btn_enter     = find_child("Button_EnterTable", true, false) as Button

	# --- connexions boutons navigation ---
	if btn_back != null:
		btn_back.pressed.connect(func():
			get_tree().change_scene_to_file("res://Scenes/MultiplayerMenu.tscn")
		)
	if btn_enter != null:
		btn_enter.pressed.connect(func():
			var game_scene: String = "res://Scenes/TableGame.tscn"
			if ResourceLoader.exists(game_scene):
				get_tree().change_scene_to_file(game_scene)
			else:
				push_error("TableGame.tscn introuvable")
		)

	# UI invitation
	_ensure_invite_ui()

	_current_user = _get_current_username()
	_tid = _get_current_table_id()
	if _tid == "":
		_to_menu()
		return

	_refresh_all()

# ---------------- UI bootstrap (rattachement) ----------------
func _ensure_invite_ui() -> void:
	hbox_invite = find_child("HBox_Invite", true, false) as HBoxContainer
	opt_friend  = find_child("OptionButton_InviteList", true, false) as OptionButton
	btn_invite  = find_child("Button_Invite", true, false) as Button
	opt_role    = null

	label_invites_title = find_child("Label_Invited", true, false) as Label
	vbox_invited_list   = find_child("VBox_InvitedPlayers", true, false) as VBoxContainer

	if btn_invite != null and not btn_invite.pressed.is_connected(Callable(self, "_on_invite_pressed")):
		btn_invite.pressed.connect(Callable(self, "_on_invite_pressed"))

# ---------------- Rendu / refresh ----------------
func _refresh_all() -> void:
	var d: Dictionary = _get_table_data(_tid)
	if d.is_empty():
		_to_menu()
		return

	var name: String = str(d.get("table_name", "Sans nom"))
	if label_name != null:
		label_name.text = "Salle de jeu : " + name

	var parts: Dictionary = d.get("participants", {})
	var invited: Array   = d.get("invited_players", [])
	var owner: String    = str(d.get("owner_username", ""))

	# Résumé texte
	var lines: Array = []
	if owner != "":
		lines.append("• %s (%s)" % [owner, str(parts.get(owner, "MJ"))])
	for k in parts.keys():
		if k != "" and k != owner:
			lines.append("• %s (%s)" % [k, str(parts[k])])
	for f in invited:
		if f != "" and f != owner and not parts.has(f):
			lines.append("• %s (invité)" % [f])
	if label_players != null:
		label_players.text = String("\n").join(lines)

	# Dropdown amis
	_fill_friends_dropdown(invited, parts)

	# Liste interactive
	_rebuild_invited_list(invited, parts, owner)

func _fill_friends_dropdown(invited: Array, parts: Dictionary) -> void:
	if opt_friend == null:
		return
	opt_friend.clear()

	var friends: Array = []
	if _current_user != "" and account_manager != null and account_manager.has_method("get_friends"):
		friends = account_manager.call("get_friends", _current_user)

	for f in friends:
		if f != "" and not invited.has(f) and not parts.has(f):
			opt_friend.add_item(f)

func _rebuild_invited_list(invited: Array, parts: Dictionary, owner: String) -> void:
	if vbox_invited_list == null:
		return
	for c in vbox_invited_list.get_children():
		(c as Node).queue_free()

	if invited.is_empty():
		var row: HBoxContainer = HBoxContainer.new()
		var lab: Label = Label.new()
		lab.text = "— aucun invité —"
		row.add_child(lab)
		vbox_invited_list.add_child(row)
		return

	var am_owner: bool = (_current_user == owner)

	for u in invited:
		if u == "" or u == owner:
			continue
		var row2: HBoxContainer = HBoxContainer.new()
		var lab2: Label = Label.new()
		var lab_text: String = u
		if parts.has(u):
			lab_text += " (rejoint)"
		lab2.text = lab_text
		row2.add_child(lab2)

		var btn: Button = Button.new()
		btn.text = "🗑️"
		btn.disabled = not am_owner
		btn.pressed.connect(Callable(self, "_on_remove_invited_pressed").bind(u))
		row2.add_child(btn)

		vbox_invited_list.add_child(row2)

# ---------------- Actions ----------------
func _on_invite_pressed() -> void:
	if _tid == "" or opt_friend == null or opt_friend.item_count == 0:
		return
	var idx: int = opt_friend.get_selected_id()
	if idx < 0: idx = opt_friend.get_selected()
	var friend_name: String = opt_friend.get_item_text(max(idx, 0))
	if friend_name == "": return

	var role: String = "Joueur"
	if opt_role != null and opt_role.item_count > 0:
		role = opt_role.get_item_text(opt_role.get_selected())

	if table_manager != null and table_manager.has_method("add_invited_player"):
		table_manager.call("add_invited_player", _tid, friend_name)
	if table_manager != null and table_manager.has_method("set_participant_role"):
		table_manager.call("set_participant_role", _tid, friend_name, role)
	if account_manager != null and account_manager.has_method("add_invitation"):
		account_manager.call("add_invitation", friend_name, _tid)

	_refresh_all()

func _on_remove_invited_pressed(username: String) -> void:
	if _tid == "" or username == "":
		return
	if table_manager != null and table_manager.has_method("remove_invited_player"):
		table_manager.call("remove_invited_player", _tid, username)
	if account_manager != null and account_manager.has_method("remove_invitation"):
		account_manager.call("remove_invitation", username, _tid)
	_refresh_all()

# ---------------- Helpers ----------------
func _to_menu() -> void:
	get_tree().change_scene_to_file("res://Scenes/MultiplayerMenu.tscn")

func _get_current_username() -> String:
	if account_manager != null and account_manager.has_method("get_current_username"):
		return str(account_manager.call("get_current_username"))
	return ""

func _get_current_table_id() -> String:
	if table_manager != null and table_manager.has_method("get_current_table_id"):
		return str(table_manager.call("get_current_table_id"))
	return ""

func _get_table_data(tid: String) -> Dictionary:
	if table_manager != null and table_manager.has_method("get_table_data"):
		var v: Variant = table_manager.call("get_table_data", tid)
		if typeof(v) == TYPE_DICTIONARY:
			return v
	return {}

func _find_am_autoload() -> Node:
	var root: Node = get_tree().get_root()
	if root != null:
		var aut: Node = root.find_child("AccountManager", false, false)
		if aut != null: return aut
	var cs: Node = get_tree().get_current_scene()
	if cs != null:
		var local: Node = cs.find_child("AccountManager", true, false)
		if local != null: return local
	return null

func _find_tm_autoload() -> Node:
	var root: Node = get_tree().get_root()
	if root != null:
		var aut: Node = root.find_child("TableManager", false, false)
		if aut != null: return aut
	var cs: Node = get_tree().get_current_scene()
	if cs != null:
		var local: Node = cs.find_child("TableManager", true, false)
		if local != null: return local
	return null
