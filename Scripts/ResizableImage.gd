extends Control
# ResizableImage.gd — Godot 4.4
# Image déplaçable + redimensionnable (poignées) + menu d’options
# + sélection, suppression (× / Suppr) et zoom Ctrl+Molette.
# Émet des signaux pour que le parent synchronise réseau & sauvegarde.

class_name ResizableImage

signal image_changed(image_id: String, pos: Vector2, size: Vector2)
signal image_delete_requested(image_id: String)

# Identifiant donné par TableGame
var image_id: String = ""

# --- Visuel interne ---
var tex_rect: TextureRect
var _btn_close: Button

# --- Menu contexte ---
var _menu: PopupMenu

# --- État drag/resize ---
enum DragMode { NONE, MOVE, TL, TR, BL, BR }
var _drag_mode: int = DragMode.NONE
var _drag_offset_global: Vector2 = Vector2.ZERO
var _orig_rect_global: Rect2 = Rect2()

# --- Options ---
const HANDLE_SIZE: int = 12
const MIN_W: int = 64
const MIN_H: int = 64
const BORDER_W: int = 2

var keep_aspect: bool = false
var snap_enabled: bool = false
var snap_px: int = 16

var _orig_tex_size: Vector2i = Vector2i(256, 256)
var _selected: bool = false

func _ready() -> void:
	# TextureRect plein et transparent aux événements (IMPORTANT)
	tex_rect = TextureRect.new()
	tex_rect.stretch_mode = TextureRect.STRETCH_SCALE
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tex_rect)

	# Bouton supprimer
	_btn_close = Button.new()
	_btn_close.text = "×"
	_btn_close.tooltip_text = "Supprimer (Suppr)"
	_btn_close.custom_minimum_size = Vector2(18, 18)
	_btn_close.focus_mode = Control.FOCUS_NONE
	_btn_close.visible = false
	add_child(_btn_close)
	_btn_close.pressed.connect(func(): emit_signal("image_delete_requested", image_id))

	# Menu clic-droit
	_menu = PopupMenu.new()
	add_child(_menu)
	_menu.add_check_item("Garder le ratio", 1)
	_menu.add_check_item("Snap 16 px", 2)
	_menu.add_separator()
	_menu.add_item("50 %", 10)
	_menu.add_item("100 % (origine)", 11)
	_menu.add_item("200 %", 12)
	_menu.add_separator()
	_menu.add_item("Reset taille (256×256)", 20)
	_menu.id_pressed.connect(_on_menu)

	# Ce Control doit capter la souris
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process_unhandled_input(true)

	# Toujours derrière dans la pile parente
	z_index = -1000

	# Taille par défaut
	size = Vector2(256, 256)
	tex_rect.size = size
	_update_close_pos()

func set_image_from_file(path: String) -> bool:
	var img := Image.new()
	var err := img.load(path)
	if err != OK:
		return false
	var tex := ImageTexture.create_from_image(img)
	tex_rect.texture = tex

	_orig_tex_size = Vector2i(tex.get_width(), tex.get_height())

	# Ajuste la taille initiale (limite 512x512)
	var w: float = float(_orig_tex_size.x)
	var h: float = float(_orig_tex_size.y)
	if w > 0.0 and h > 0.0:
		var max_side := 512.0
		var scale := 1.0
		if w > max_side or h > max_side:
			scale = min(max_side / w, max_side / h)
		size = Vector2(max(MIN_W, int(w * scale)), max(MIN_H, int(h * scale)))
		tex_rect.size = size

	_update_close_pos()
	queue_redraw()
	return true

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		if tex_rect != null:
			tex_rect.size = size
		_update_close_pos()

# ===================== INPUT =====================

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton

		# Clic droit -> menu
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			_menu.set_item_checked(0, keep_aspect)
			_menu.set_item_checked(1, snap_enabled)
			_menu.position = mb.position  # local
			_menu.popup()
			return

		# Sélection au clic gauche
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_select_me()

		# Ctrl + molette = zoom
		if mb.ctrl_pressed and mb.pressed and (mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			if _selected:
				var factor := 1.1
				if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
					factor = 1.0 / factor
				_zoom_from_center(factor)
			return

		# Drag / resize au clic gauche
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_start_drag(_local_to_global(mb.position))
			else:
				_drag_mode = DragMode.NONE
				set_default_cursor_shape(Control.CURSOR_ARROW)

	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		_update_cursor(mm.position)  # position locale
		if _drag_mode != DragMode.NONE:
			_on_drag(_local_to_global(mm.position))

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var k := event as InputEventKey
		if k.pressed and not k.echo and k.keycode == KEY_DELETE and _selected:
			emit_signal("image_delete_requested", image_id)

# ===================== MENU =====================

func _on_menu(id: int) -> void:
	match id:
		1:
			keep_aspect = not keep_aspect
			_menu.set_item_checked(_menu.get_item_index(id), keep_aspect)
		2:
			snap_enabled = not snap_enabled
			_menu.set_item_checked(_menu.get_item_index(id), snap_enabled)
		10: _scale_from_factor(0.5)
		11: _set_to_original_size()
		12: _scale_from_factor(2.0)
		20:
			size = Vector2(256, 256)
			tex_rect.size = size
			_emit_changed()
			_update_close_pos()
			queue_redraw()

func _scale_from_factor(f: float) -> void:
	var new_size := size * f
	new_size.x = max(new_size.x, float(MIN_W))
	new_size.y = max(new_size.y, float(MIN_H))
	var center_g := _global_origin() + size * 0.5
	var new_rect := Rect2(center_g - new_size * 0.5, new_size)
	_set_global_rect(new_rect)

func _set_to_original_size() -> void:
	var s := Vector2(max(MIN_W, _orig_tex_size.x), max(MIN_H, _orig_tex_size.y))
	var center_g := _global_origin() + size * 0.5
	var new_rect := Rect2(center_g - s * 0.5, s)
	_set_global_rect(new_rect)

# ===================== DRAG / RESIZE =====================

func _start_drag(mouse_global: Vector2) -> void:
	_orig_rect_global = Rect2(_global_origin(), size)

	var local := _global_to_local(mouse_global)
	var hit := _hit_handle(local)
	if hit != DragMode.NONE:
		_drag_mode = hit
		return

	_drag_mode = DragMode.MOVE
	_drag_offset_global = mouse_global - _global_origin()

func _on_drag(mouse_global: Vector2) -> void:
	if _drag_mode == DragMode.MOVE:
		var new_global_origin := mouse_global - _drag_offset_global
		_set_global_origin(new_global_origin)
		return

	var r := _orig_rect_global
	var lp := mouse_global

	if _drag_mode == DragMode.TL:
		r.position = lp
		r.size = (_orig_rect_global.end - lp)
	elif _drag_mode == DragMode.TR:
		r.position.y = lp.y
		r.size.x = (lp.x - _orig_rect_global.position.x)
		r.size.y = (_orig_rect_global.end.y - lp.y)
	elif _drag_mode == DragMode.BL:
		r.position.x = lp.x
		r.size.x = (_orig_rect_global.end.x - lp.x)
		r.size.y = (lp.y - _orig_rect_global.position.y)
	elif _drag_mode == DragMode.BR:
		r.size = (lp - _orig_rect_global.position)

	# Min
	r.size.x = max(r.size.x, MIN_W)
	r.size.y = max(r.size.y, MIN_H)

	# Garder ratio si activé
	if keep_aspect and _orig_tex_size.y > 0:
		var ratio := float(_orig_tex_size.x) / float(_orig_tex_size.y)
		var w := r.size.x
		var h := r.size.y
		var use_w := absf(w - _orig_rect_global.size.x) >= absf(h - _orig_rect_global.size.y)
		if use_w: h = w / ratio
		else:     w = h / ratio  # correction ratio si besoin (ici volontairement simple)
		match _drag_mode:
			DragMode.TL:
				r.position.x = r.end.x - w
				r.position.y = r.end.y - h
			DragMode.TR:
				r.position.y = r.end.y - h
			DragMode.BL:
				r.position.x = r.end.x - w
			_:
				pass
		r.size = Vector2(w, h)

	# Snap optionnel
	if snap_enabled and snap_px > 0:
		var endp := r.end
		r.size.x = float(int(r.size.x / snap_px + 0.5) * snap_px)
		r.size.y = float(int(r.size.y / snap_px + 0.5) * snap_px)
		match _drag_mode:
			DragMode.TL:
				r.position = endp - r.size
			DragMode.TR:
				r.position.y = endp.y - r.size.y
			DragMode.BL:
				r.position.x = endp.x - r.size.x
			_:
				pass

	_set_global_rect(r)

# ===================== SÉLECTION =====================

func _select_me() -> void:
	_selected = true
	_btn_close.visible = true
	queue_redraw()

func _deselect_me() -> void:
	_selected = false
	_btn_close.visible = false
	queue_redraw()

# ===================== DESSIN =====================

func _draw() -> void:
	# Bordure (plus visible si sélectionnée)
	var rect := Rect2(Vector2.ZERO, size)
	var col: Color
	if _selected:
		col = Color(1, 1, 1, 0.9)
	else:
		col = Color(1, 1, 1, 0.5)
	draw_rect(rect, Color(1,1,1,0), false, float(BORDER_W))
	draw_rect(rect.grow(-BORDER_W), col, false, float(BORDER_W))
	# Poignées
	var hs := float(HANDLE_SIZE)
	var s := size
	var c := Color(1,1,1,0.85)
	draw_rect(Rect2(Vector2(0,0), Vector2(hs,hs)), c)
	draw_rect(Rect2(Vector2(s.x-hs,0), Vector2(hs,hs)), c)
	draw_rect(Rect2(Vector2(0,s.y-hs), Vector2(hs,hs)), c)
	draw_rect(Rect2(Vector2(s.x-hs,s.y-hs), Vector2(hs,hs)), c)

# ===================== HELPERS COORDS =====================

func _update_close_pos() -> void:
	if _btn_close == null: return
	var bs := _btn_close.size
	if bs == Vector2.ZERO:
		bs = _btn_close.get_minimum_size()
	_btn_close.position = Vector2(max(0.0, size.x - bs.x - 4.0), 4.0)

func _global_to_local(global_point: Vector2) -> Vector2:
	var inv := get_global_transform_with_canvas().affine_inverse()
	return inv * global_point

func _local_to_global(local_point: Vector2) -> Vector2:
	return get_global_transform_with_canvas() * local_point

func _parent_global_to_local(global_point: Vector2) -> Vector2:
	var parent_ci := get_parent() as CanvasItem
	if parent_ci == null:
		return global_point
	var inv := parent_ci.get_global_transform_with_canvas().affine_inverse()
	return inv * global_point

func _global_origin() -> Vector2:
	return get_global_transform_with_canvas().origin

func _set_global_origin(new_global_origin: Vector2) -> void:
	position = _parent_global_to_local(new_global_origin)
	_emit_changed()
	_update_close_pos()

func _set_global_rect(r_global: Rect2) -> void:
	position = _parent_global_to_local(r_global.position)
	size = r_global.size
	tex_rect.size = size
	_emit_changed()
	_update_close_pos()
	queue_redraw()

func _zoom_from_center(factor: float) -> void:
	var new_size := Vector2(
		max(MIN_W, size.x * factor),
		max(MIN_H, size.y * factor)
	)
	var center_g := _global_origin() + size * 0.5
	var new_rect := Rect2(center_g - new_size * 0.5, new_size)
	_set_global_rect(new_rect)

func _hit_handle(local_pos: Vector2) -> int:
	var hs := float(HANDLE_SIZE)
	var s := size
	var tl := Rect2(Vector2(0, 0), Vector2(hs, hs))
	var tr := Rect2(Vector2(s.x - hs, 0), Vector2(hs, hs))
	var bl := Rect2(Vector2(0, s.y - hs), Vector2(hs, hs))
	var br := Rect2(Vector2(s.x - hs, s.y - hs), Vector2(hs, hs))

	if tl.has_point(local_pos): return DragMode.TL
	if tr.has_point(local_pos): return DragMode.TR
	if bl.has_point(local_pos): return DragMode.BL
	if br.has_point(local_pos): return DragMode.BR
	return DragMode.NONE

func _update_cursor(local_pos: Vector2) -> void:
	var hit := _hit_handle(local_pos)
	if hit == DragMode.TL or hit == DragMode.BR:
		set_default_cursor_shape(Control.CURSOR_FDIAGSIZE)
	elif hit == DragMode.TR or hit == DragMode.BL:
		set_default_cursor_shape(Control.CURSOR_BDIAGSIZE)
	else:
		if _drag_mode == DragMode.MOVE:
			set_default_cursor_shape(Control.CURSOR_MOVE)
		else:
			set_default_cursor_shape(Control.CURSOR_ARROW)

func _emit_changed() -> void:
	emit_signal("image_changed", image_id, position, size)
