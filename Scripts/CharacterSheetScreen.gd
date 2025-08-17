extends Control

var character_manager: CharacterManager
var current_character_name: String = ""

func _ready() -> void:
	# Initialisation du gestionnaire
	character_manager = get_tree().get_root().find_child("CharacterManager", true, false)
	
	# Connexion des boutons
	find_child("Button_Save").pressed.connect(_on_save_pressed)
	find_child("Button_Back").pressed.connect(_on_back_pressed)

func setup(character_name: String) -> void:
	current_character_name = character_name
	character_manager.load_character(character_name)
	_update_ui_from_data()

func _on_save_pressed() -> void:
	_update_data_from_ui()
	character_manager.save_character(current_character_name)

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/MultiplayerMenu.tscn")

func _update_ui_from_data() -> void:
	var data = character_manager.current_character
	
	find_child("LineEdit_Name").text = data.get("name", "")
	find_child("LineEdit_Age").text = str(data.get("age", ""))
	find_child("TextEdit_Description").text = data.get("description", "")
	
	# À compléter pour les autres onglets selon les structures

func _update_data_from_ui() -> void:
	var data = character_manager.current_character
	
	data["name"] = find_child("LineEdit_Name").text
	data["age"] = find_child("LineEdit_Age").text
	data["description"] = find_child("TextEdit_Description").text
	
	# À compléter pour les autres onglets
