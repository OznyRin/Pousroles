# res://Tools/ContractCheck.gd
extends Node

# 📌 Mets ici les chemins exacts de tes scripts et leurs méthodes obligatoires.
const CONTRACTS := {
	"res://Scripts/MultiplayerMenu.gd": [
		"_refresh_friend_list",
		"_on_add_friend_pressed",
		"_refresh_table_list",
		"_build_table_row",
		"_on_create_table_pressed",
		"_on_click_rename_table",
		"_on_click_delete_table",
		"_apply_rename_table",
		"_confirm_delete_table"
	],
	"res://Scripts/AccountManager.gd": [
		"create_account",
		"validate_login",
		"set_current_username",
		"get_current_username",
		"get_user_data",
		"save_user",
		"load_user",
		"add_friend",
		"add_joined_table"
	],
	"res://Scripts/TableManager.gd": [
		"create_table"
	],
	"res://Scripts/LoginScreen.gd": [
		"_on_login_pressed"
	],
	"res://Scripts/CreateAccountScreen.gd": [
		"_on_create_pressed",
		"_on_back_pressed"
	]
}

func _ready() -> void:
	_print_header()
	_run_contract_checks()
	_print_footer()

func _run_contract_checks() -> void:
	var any_missing: bool = false
	for path in CONTRACTS.keys():
		var script_res := load(path)
		if script_res == null:
			any_missing = true
			printerr("[CONTRACT] Script introuvable: ", path)
			continue

		var method_list: Array = []
		if script_res is Script:
			method_list = (script_res as Script).get_script_method_list()
		var names: Array[String] = []
		for m in method_list:
			var d: Dictionary = m
			var n: String = String(d.get("name", ""))
			if n != "":
				names.append(n)

		var required: Array = CONTRACTS[path]
		var miss: Array = []
		for req in required:
			if not names.has(String(req)):
				miss.append(req)

		if miss.is_empty():
			print_rich("[color=green][OK][/color] ", path)
		else:
			any_missing = true
			printerr("[CONTRACT][MISSING] ", path, " → ", miss)

	if any_missing:
		printerr("[CONTRACT] Des méthodes manquent. Corrige avant de lancer le build.")
	else:
		print_rich("[color=green][CONTRACT] Tous les contrats sont satisfaits.[/color]")

func _print_header() -> void:
	print_rich("\n[color=yellow]=== Vérification de contrat Pousroles ===[/color]")

func _print_footer() -> void:
	print_rich("[color=yellow]======================================[/color]\n")
