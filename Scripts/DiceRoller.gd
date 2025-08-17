extends HBoxContainer
class_name DiceRoller

signal roll_request(sides: int, count: int, mod: int)

var _sb_count: SpinBox
var _sb_mod: SpinBox

const ALLOWED = [2, 4, 6, 20, 100]

func _ready() -> void:
	custom_minimum_size = Vector2(0, 28)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var lbl := Label.new()
	lbl.text = "Dés :"
	add_child(lbl)

	_sb_count = SpinBox.new()
	_sb_count.min_value = 1
	_sb_count.max_value = 20
	_sb_count.step = 1
	_sb_count.value = 1
	_sb_count.custom_minimum_size = Vector2(52, 0)
	_sb_count.tooltip_text = "Nombre de dés"
	add_child(_sb_count)

	_sb_mod = SpinBox.new()
	_sb_mod.min_value = -100
	_sb_mod.max_value  =  100
	_sb_mod.step = 1
	_sb_mod.value = 0
	_sb_mod.custom_minimum_size = Vector2(64, 0)
	_sb_mod.tooltip_text = "Modificateur"
	add_child(_sb_mod)

	_add_die_button("D2",   2)
	_add_die_button("D4",   4)
	_add_die_button("D6",   6)
	_add_die_button("D20", 20)
	_add_die_button("D100",100)

func _add_die_button(txt: String, sides: int) -> void:
	var b := Button.new()
	b.text = txt
	b.focus_mode = Control.FOCUS_NONE
	add_child(b)
	b.pressed.connect(func():
		var c := int(clamp(_sb_count.value, 1, 20))
		var m := int(clamp(_sb_mod.value, -100, 100))
		if ALLOWED.has(sides):
			emit_signal("roll_request", sides, c, m)
	)
