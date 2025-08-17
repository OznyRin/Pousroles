extends Control

func _ready():
	find_child("Button_CreateTable").pressed.connect(_on_create_pressed)
	find_child("Button_JoinTable").pressed.connect(_on_join_code_pressed)
	refresh_table_list()

func refresh_table_list():
	var username = AccountManager.get_current_user()
	var tables = TableManager.get_tables_for_user(username)
	var vbox = find_child("VBoxMain")
	for child in vbox.get_children():
		if child.name.begins_with("TableButton_"):
			child.queue_free()
	for table in tables:
		var hbox = HBoxContainer.new()
		var table_button = Button.new()
		table_button.name = "TableButton_" + table["uuid"]
		table_button.text = table["name"]
		table_button.pressed.connect(_on_table_selected.bind(table["uuid"]))
		var delete_button = Button.new()
		delete_button.text = "🗑"
		delete_button.pressed.connect(_on_delete_table.bind(table["uuid"]))
		hbox.add_child(table_button)
		hbox.add_child(delete_button)
		vbox.add_child(hbox)

func _on_create_pressed():
	var name = find_child("LineEdit_TableName").text.strip_edges()
	if name.is_empty(): return
	var username = AccountManager.get_current_user()
	TableManager.create_table(name, username)
	refresh_table_list()

func _on_delete_table(uuid: String):
	TableManager.delete_table(uuid)
	refresh_table_list()

func _on_table_selected(uuid: String):
	TableManager.set_current_table(uuid)
	get_tree().change_scene_to_file("res://Scenes/TableRoom.tscn")

func _on_join_code_pressed():
	var code = find_child("LineEdit_JoinCode").text.strip_edges()
	TableManager.set_current_table(code)
	get_tree().change_scene_to_file("res://Scenes/TableRoom.tscn")
