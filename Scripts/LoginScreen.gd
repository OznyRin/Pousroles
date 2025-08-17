extends Control
# Hiérarchie:
#  VBoxMain / LineEdit_Email, LineEdit_Password, Button_Login, Button_CreateAccount, Label_Error

var account_manager: Node

var line_email: LineEdit
var line_password: LineEdit
var btn_login: Button
var btn_create_account: Button
var label_error: Label

func _ready() -> void:
	account_manager = _find_am_autoload()

	line_email = find_child("LineEdit_Email", true, false) as LineEdit
	line_password = find_child("LineEdit_Password", true, false) as LineEdit
	btn_login = find_child("Button_Login", true, false) as Button
	btn_create_account = find_child("Button_CreateAccount", true, false) as Button
	label_error = find_child("Label_Error", true, false) as Label

	if btn_login != null:
		btn_login.pressed.connect(_on_login_pressed)
	if btn_create_account != null:
		btn_create_account.pressed.connect(_on_create_account_pressed)
	if label_error != null:
		label_error.text = ""

func _on_login_pressed() -> void:
	var email: String = ""
	var password: String = ""
	if line_email != null:
		email = String(line_email.text)
	if line_password != null:
		password = String(line_password.text)

	if email.strip_edges() == "" or password.strip_edges() == "":
		_set_error("Saisis ton identifiant (email ou pseudo) et ton mot de passe.")
		return

	var uname: String = ""
	if account_manager != null and account_manager.has_method("validate_login"):
		var u: Variant = account_manager.call("validate_login", email, password)
		uname = String(u)

	if uname == "":
		_set_error("Identifiants invalides.")
		return

	# Sécurité : on (re)pose la session sur l’autoload au cas où une autre instance aurait été utilisée
	var am_autoload: Node = _find_am_autoload()
	if am_autoload != null and am_autoload.has_method("set_current_username"):
		am_autoload.call("set_current_username", uname)
# Nettoyage data (une fois) après login réussi
	am_autoload.call("clean_tables_joined", uname)

	var tree: SceneTree = get_tree()
	if tree != null:
		tree.change_scene_to_file("res://Scenes/MultiplayerMenu.tscn")

func _on_create_account_pressed() -> void:
	var tree: SceneTree = get_tree()
	if tree != null:
		tree.change_scene_to_file("res://Scenes/CreateAccount.tscn")

func _set_error(msg: String) -> void:
	if label_error != null:
		label_error.text = msg

# ---------- helpers ----------
func _find_am_autoload() -> Node:
	# 1) autoload : child direct du root
	var root: Node = get_tree().get_root()
	if root != null:
		var aut: Node = root.find_child("AccountManager", false, false)
		if aut != null:
			# print("[Login] AccountManager (autoload) OK")
			return aut
	# 2) fallback : un node dans la scène courante
	var scene: Node = get_tree().get_current_scene()
	if scene != null:
		var local_am: Node = scene.find_child("AccountManager", true, false)
		if local_am != null:
			# print("[Login] AccountManager (local scene) utilisé (fallback)")
			return local_am
	return null
