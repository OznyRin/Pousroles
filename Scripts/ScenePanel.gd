extends VBoxContainer

## === Panneau "Scène" ultra simple (sans gestionnaire média) ===
##
## Signaux vers TableGame :
##  - rename_requested(new_name)
##  - new_scene_requested()
##  - open_scene_browser()
##  - add_image_requested()        <-- ouvre simplement le FileDialog côté TableGame

signal rename_requested(new_name: String)
signal new_scene_requested()
signal open_scene_browser()
signal add_image_requested()

var _name_edit: LineEdit

func _ready() -> void:
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	theme_type_variation = &"Panel"
	add_theme_constant_override("separation", 8)

	var title := Label.new()
	title.text = "Gestion de la scène"
	add_child(title)

	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "Nom de la scène"
	add_child(_name_edit)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)
	add_child(btn_row)

	var btn_rename := Button.new()
	btn_rename.text = "Renommer"
	btn_rename.pressed.connect(func(): rename_requested.emit(_name_edit.text))
	btn_row.add_child(btn_rename)

	var btn_new := Button.new()
	btn_new.text = "Nouvelle scène"
	btn_new.pressed.connect(func(): new_scene_requested.emit())
	btn_row.add_child(btn_new)

	var btn_add_img := Button.new()
	btn_add_img.text = "Ajouter une image…"
	btn_add_img.pressed.connect(func(): add_image_requested.emit())
	add_child(btn_add_img)

	var btn_browser := Button.new()
	btn_browser.text = "Parcourir les scènes…"
	btn_browser.pressed.connect(func(): open_scene_browser.emit())
	add_child(btn_browser)

func set_scene_name(n: String) -> void:
	if _name_edit:
		_name_edit.text = n
