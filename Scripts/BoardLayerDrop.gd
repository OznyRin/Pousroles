extends Control
##
## Réception de drag&drop depuis les vignettes du gestionnaire de médias.
##

signal media_dropped(path: String, local_pos: Vector2)

func can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY:
		return false
	var d: Dictionary = data
	return String(d.get("type","")) == "media_path" and String(d.get("path","")) != ""

func drop_data(at_position: Vector2, data: Variant) -> void:
	if not can_drop_data(at_position, data):
		return
	var d: Dictionary = data
	var path: String = String(d.get("path",""))
	# 'at_position' est déjà en coordonnées locales de ce Control.
	media_dropped.emit(path, at_position)
