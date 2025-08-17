extends Control

func _ready():
	var role_option = find_child("RoleOption")
	role_option.clear()
	role_option.add_item("MJ")
	role_option.add_item("Joueur")

func get_selected_role() -> String:
	var role_option = find_child("RoleOption")
	return role_option.get_item_text(role_option.get_selected_id())
