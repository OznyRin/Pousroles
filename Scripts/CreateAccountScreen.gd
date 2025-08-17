extends Control
# UI inchangée : LineEdit_Email, LineEdit_Password, LineEdit_Username,
# Button_Create, Button_Back, Label_Error

# Managers
var account_manager: Node

# UI
var line_email: LineEdit
var line_password: LineEdit
var line_username: LineEdit
var btn_create: Button
var btn_back: Button
var label_error: Label

func _ready() -> void:
	# Récup manager dynamiquement
	account_manager = _find_am()

	# Récup UI (dyn.)
	line_email    = find_child("LineEdit_Email", true, false) as LineEdit
	line_password = find_child("LineEdit_Password", true, false) as LineEdit
	line_username = find_child("LineEdit_Username", true, false) as LineEdit
	btn_create    = find_child("Button_Create", true, false) as Button
	btn_back      = find_child("Button_Back", true, false) as Button
	label_error   = find_child("Label_Error", true, false) as Label

	if btn_create != null:
		btn_create.pressed.connect(_on_create_pressed)
	if btn_back != null:
		btn_back.pressed.connect(_on_back_pressed)

	if label_error != null:
		label_error.text = ""

func _on_create_pressed() -> void:
	var email: String = ""
	var password: String = ""
	var username: String = ""

	if line_email != null:
		email = String(line_email.text)
	if line_password != null:
		password = String(line_password.text)
	if line_username != null:
		username = String(line_username.text)

	var ok: bool = false
	if account_manager != null and account_manager.has_method("create_account"):
		ok = bool(account_manager.call("create_account", email, password, username))

	if not ok:
		if label_error != null:
			label_error.text = "Création impossible (email/username déjà pris ou invalide)."
		return

	# Succès → retour Login (flux MVP)
	if label_error != null:
		label_error.text = "Compte créé. Vous pouvez vous connecter."
	var tree: SceneTree = get_tree()
	if tree != null:
		tree.change_scene_to_file("res://Scenes/Login.tscn")

func _on_back_pressed() -> void:
	var tree: SceneTree = get_tree()
	if tree != null:
		tree.change_scene_to_file("res://Scenes/Login.tscn")

# --- helpers ---
func _find_am() -> Node:
	var root: Node = get_tree().get_current_scene()
	if root != null:
		var am: Node = root.find_child("AccountManager", true, false)
		if am != null:
			return am
	var any: Node = get_tree().get_root()
	if any != null:
		var am2: Node = any.find_child("AccountManager", true, false)
		if am2 != null:
			return am2
	return null
