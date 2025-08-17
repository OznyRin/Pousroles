extends Node

var current_character: Dictionary = {}

func load_character(name: String) -> void:
	var path = "user://Data/Characters/character_%s.json" % name
	var file = FileAccess.open(path, FileAccess.READ)
	
	if file:
		current_character = JSON.parse_string(file.get_as_text())
	else:
		current_character = {
			"name": name,
			"age": "",
			"description": "",
			"stats": {},
			"skills": [],
			"special_skills": [],
			"spells": [],
			"inventory": [],
			"notes": ""
		}

func save_character(name: String) -> void:
	var dir = DirAccess.open("user://")
	if not dir.dir_exists("user://Data/Characters"):
		dir.make_dir_recursive("user://Data/Characters")
	
	var path = "user://Data/Characters/character_%s.json" % name
	var file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(current_character, "\t"))
	file.close()
