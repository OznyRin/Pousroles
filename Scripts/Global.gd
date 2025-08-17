extends Node

# Ce fichier contient les variables globales partagées dans tout le projet

var current_user_data: Dictionary = {}
var username: String = ""  # <- à ajouter

# Fonction utilitaire pour générer un identifiant unique (UUID-like)
func generate_uuid() -> String:
	var uuid = ""
	var chars = "abcdef0123456789"
	var sections = [8, 4, 4, 4, 12]
	for section in sections:
		for i in range(section):
			uuid += chars[randi() % chars.length()]
		uuid += "-"
	uuid = uuid.substr(0, uuid.length() - 1) # Supprimer le dernier tiret
	return uuid
