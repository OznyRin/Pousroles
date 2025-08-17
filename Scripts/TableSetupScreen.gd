extends Control
class_name TableSetupScreen

var label_title: Label
var option_invite_list: OptionButton
var button_invite: Button
var label_invited: Label
var vbox_invited: VBoxContainer
var button_enter: Button
var button_back: Button

var account_manager: AccountManager
var table_manager: TableManager
var network_manager: NetworkManager

var table_id: String = ""
var table_name: String = "Nouvelle Table"
var owner_username: String = ""

func _ready() -> void:
	var vbox_main_v: Variant = find_child("VBox_Main", true, false)
	if vbox_main_v:
		var l1_v: Variant = vbox_main_v.find_child("Label_Title", true, false)
		if l1_v and l1_v is Label:
			label_title = l1_v
		var hbox_inv_v: Variant = vbox_main_v.find_child("HBox_Invite", true, false)
		if hbox_inv_v:
			var opt_v: Variant = hbox_inv_v.find_child("OptionButton_InviteList", true, false)
			if opt_v and opt_v is OptionButton:
				option_invite_list = opt_v
			var b_v: Variant = hbox_inv_v.find_child("Button_Invite", true, false)
			if b_v and b_v is Button:
				button_invite = b_v
		var l2_v: Variant = vbox_main_v.find_child("Label_Invited", true, false)
		if l2_v and l2_v is Label:
			label_invited = l2_v
		var sc_v: Variant = vbox_main_v.find_child("ScrollContainer", true, false)
		if sc_v:
			var vb_v: Variant = sc_v.find_child("VBox_InvitedPlayers", true, false)
			if vb_v and vb_v is VBoxContainer:
				vbox_invited = vb_v
		var be_v: Variant = vbox_main_v.find_child("Button_EnterTable", true, false)
		if be_v and be_v is Button:
			button_enter = be_v
		var bb_v: Variant = vbox_main_v.find_child("Button_Back", true, false)
		if bb_v and bb_v is Button:
			button_back = bb_v

	var a_v: Variant = find_child("AccountManager", true, false)
	if a_v and a_v is AccountManager:
		account_manager = a_v
	var t_v: Variant = find_child("TableManager", true, false)
	if t_v and t_v is TableManager:
		table_manager = t_v
	var n_v: Variant = find_child("NetworkManager", true, false)
	if n_v and n_v is NetworkManager:
		network_manager = n_v

	if button_invite:
		button_invite.pressed.connect(_on_button_invite_pressed)
	if button_enter:
		button_enter.pressed.connect(_on_button_enter_pressed)
	if button_back:
		button_back.pressed.connect(_on_button_back_pressed)

	if label_title:
		label_title.text = "Configuration — %s" % table_name
	if table_manager:
		table_manager.create_or_load_table(table_id, owner_username, table_name)
	_refresh_invited_list()

func setup_table_context(p_table_id: String, p_owner: String, p_name: String) -> void:
	table_id = p_table_id
	owner_username = p_owner
	table_name = p_name

func _refresh_invited_list() -> void:
	if not vbox_invited:
		return
	for c in vbox_invited.get_children():
		c.queue_free()
	if not table_manager:
		return
	var info: Dictionary = table_manager.get_table_info(table_id)
	var arr: Array = info.get("invited_players", [])
	for it_v in arr:
		if typeof(it_v) == TYPE_DICTIONARY:
			var it: Dictionary = it_v
			var h: HBoxContainer = HBoxContainer.new()
			var l: Label = Label.new()
			var uname: String = String(it.get("username",""))
			var role: String = String(it.get("role","Player"))
			l.text = "%s  —  %s" % [uname, role]
			h.add_child(l)
			vbox_invited.add_child(h)

func _on_button_invite_pressed() -> void:
	if not option_invite_list or not network_manager or not account_manager:
		return
	var sel_idx: int = option_invite_list.selected
	var username: String = ""
	if sel_idx >= 0:
		username = option_invite_list.get_item_text(sel_idx)
	var payload: Dictionary = {
		"table_id": table_id,
		"table_name": table_name,
		"from_mj": owner_username,
		"role": "Player",
		"target_username": username
	}
	# Diffusion : chaque client filtre par target_username
	network_manager.rpc("rpc_invite_to_table", payload)
	if table_manager and username != "":
		table_manager.add_or_update_invited_player(table_id, username, "Player")
	_refresh_invited_list()

func _on_button_enter_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/TableRoom.tscn")

func _on_button_back_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/MultiplayerMenu.tscn")
