extends Control

# === AUTLOADS ===================================================
var account_manager: Node = null
var table_manager:   Node = null
var network_manager: Node = null

# === CHAT UI ====================================================
var label_title:  Label  = null
var chat_scroll:  ScrollContainer = null
var chat_box:     VBoxContainer   = null
var input_chat:   LineEdit        = null
var btn_send:     Button          = null
var btn_back:     Button          = null
var hbox_chat:    HBoxContainer   = null

var _btn_chat: Button = null
var _chat_panel: DraggablePanel = null

# === STATE ======================================================
var _username: String = ""
var _table_id: String = ""

const NET_PORT: int = 24545
const NET_IP_LOCAL: String = "127.0.0.1"

# === FILES / DIRS ==============================================
const IMAGES_DIR: String = "user://SharedImages"
const TABLES_DIR: String = "user://Data/Tables"

# === BOARD / IMAGES ============================================
var _board_layer: Control = null
# scene_id -> (img_id -> {file_name, path, pos, size})
var _images_by_scene: Dictionary = {}
var _is_loading_full_state: bool = false

# === DICE =======================================================
const DICE_ALLOWED: Array[int] = [2, 4, 6, 20, 100]
var _dice_panel: DraggablePanel = null
var _dice_roller: DiceRoller     = null

# === SCENES / PANELS ===========================================
var _btn_scene: Button = null
var _scene_panel: DraggablePanel = null

# Gestionnaire “scènes”
# --- Scene browser UI
const SceneBrowserPanel = preload("res://Scripts/SceneBrowserPanel.gd")
const SceneManagerPanel = preload("res://Scripts/SceneManagerPanel.gd")
const ResizeHandle      = preload("res://Scripts/ResizeHandle.gd")
var _scene_ui := SceneManagerPanel.new()
var _scene_browser_window: DraggablePanel = null
var _scene_browser_ui: SceneBrowserPanel = null
var _scene_browser_panel: DraggablePanel = null
# (facultatif : ajout d’images via un FileDialog global)
var _file_dialog: FileDialog = null

# Store des scènes  { id -> { "name": String, "thumb_path": String } }
var _scenes: Dictionary = {}
var _current_scene_id: String = ""

# === READY ======================================================
func _ready() -> void:
	# --- autoloads
	account_manager = _find_autoload("AccountManager")
	table_manager   = _find_autoload("TableManager")
	network_manager = _find_autoload("NetworkManager")

	# --- chat refs
	label_title = find_child("Label_Title", true, false) as Label
	chat_scroll = find_child("ChatScroll", true, false) as ScrollContainer
	chat_box    = find_child("ChatBox", true, false) as VBoxContainer
	input_chat  = find_child("LineEdit_ChatInput", true, false) as LineEdit
	btn_send    = find_child("Button_Send", true, false) as Button
	btn_back    = find_child("Button_Back", true, false) as Button
	hbox_chat   = find_child("HBoxChat", true, false) as HBoxContainer

	if btn_send:
		btn_send.pressed.connect(_on_send_pressed)
	if input_chat:
		input_chat.text_submitted.connect(func(_t: String) -> void: _send_message())
	if btn_back:
		btn_back.pressed.connect(func() -> void:
			get_tree().change_scene_to_file("res://Scenes/MultiplayerMenu.tscn")
		)

	var vbox_main: VBoxContainer = find_child("VBoxMain", true, false) as VBoxContainer

	# Bouton “Chat”
	var chat_btn := Button.new()
	chat_btn.name = "Button_Chat"
	chat_btn.text = "Chat"
	chat_btn.focus_mode = Control.FOCUS_NONE
	(vbox_main if vbox_main else self).add_child(chat_btn)
	_btn_chat = chat_btn
	_btn_chat.pressed.connect(_toggle_chat_panel)

	_build_chat_panel()
	_wrap_chat_in_panel()

	# Board layer en fond
	_board_layer = _get_board_layer()

	# Contexte
	_username = _get_username_safe()
	_table_id = _get_table_id_safe()
	if label_title:
		var tn: String = _table_name_safe()
		if tn.is_empty():
			tn = "Table"
		label_title.text = tn + " — chat"

	# Scènes (store + panneau)
	_init_scene_store()
	_build_scene_panel()

	var btn_scene_local := Button.new()
	btn_scene_local.name = "Button_Scene"
	btn_scene_local.text = "Scène"
	btn_scene_local.focus_mode = Control.FOCUS_NONE
	(vbox_main if vbox_main else self).add_child(btn_scene_local)
	_btn_scene = btn_scene_local
	_btn_scene.pressed.connect(_toggle_scene_panel)

	# Panneau “lancer des dés”
	var btn_launch_dice := Button.new()
	btn_launch_dice.text = "Lancer des dés"
	btn_launch_dice.focus_mode = Control.FOCUS_NONE
	(vbox_main if vbox_main else self).add_child(btn_launch_dice)

	_dice_panel = DraggablePanel.new()
	_dice_panel.visible = false
	_dice_panel.z_index = 20
	_dice_panel.set_title("Lancer des dés")
	add_child(_dice_panel)
	_dice_panel.global_position = Vector2(160, 140)
	_dice_roller = DiceRoller.new()
	_dice_panel.set_content(_dice_roller)
	_dice_roller.roll_request.connect(_on_dice_request)

	btn_launch_dice.pressed.connect(func() -> void:
		_dice_panel.visible = not _dice_panel.visible
		if _dice_panel.visible:
			_dice_panel.move_to_front()
	)

	# Réseau
	_drop_existing_peer()
	_start_fresh_network_session()

	# Images + board
	_load_images_from_disk()
	_respawn_board_for_current_scene()

	_add_chat_line("[Système] Bienvenue, " + _username + ".")

# === CHAT =======================================================
func _on_send_pressed() -> void:
	_send_message()

func _send_message() -> void:
	if input_chat == null:
		return
	var msg: String = input_chat.text.strip_edges()
	if msg.is_empty():
		return
	if _is_multiplayer_connected():
		rpc("rpc_chat", _username, msg)
	else:
		_show_line(_username + " : " + msg)
	input_chat.text = ""

@rpc("any_peer", "call_local")
func rpc_chat(from_user: String, text: String) -> void:
	_show_line(String(from_user) + " : " + String(text))

func _show_line(line: String) -> void:
	_add_chat_line(line)

func _add_chat_line(text: String) -> void:
	if chat_box == null:
		return
	var lbl := Label.new()
	lbl.text = text
	chat_box.add_child(lbl)
	await get_tree().process_frame
	if chat_scroll:
		chat_scroll.scroll_vertical = 1_000_000

# === DES ========================================================
func _on_dice_request(sides: int, count: int, mod: int) -> void:
	if not DICE_ALLOWED.has(sides):
		return
	var c: int = clampi(count, 1, 20)
	var m: int = clampi(mod, -100, 100)

	var rolls: PackedInt32Array = _roll_many(sides, c)
	var subtotal: int = 0
	for r in rolls:
		subtotal += r
	var total: int = subtotal + m

	if _is_multiplayer_connected():
		rpc("rpc_dice_result", _username, sides, c, m, rolls, total)
	else:
		_show_dice_result(_username, sides, c, m, rolls, subtotal, total)

func _roll_many(sides: int, count: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	for i in count:
		out.append(randi_range(1, sides))
	return out

@rpc("any_peer", "call_local")
func rpc_dice_result(username: String, sides: int, count: int, mod: int, rolls: PackedInt32Array, total: int) -> void:
	var subtotal: int = 0
	for v in rolls:
		subtotal += v
	_show_dice_result(username, sides, count, mod, rolls, subtotal, total)

func _join_ints(a: PackedInt32Array) -> String:
	var parts: Array[String] = []
	for v in a:
		parts.append(str(v))
	return "[" + ", ".join(parts) + "]"

func _show_dice_result(username: String, sides: int, count: int, mod: int, rolls: PackedInt32Array, subtotal: int, total: int) -> void:
	var list_txt: String = _join_ints(rolls)
	var line: String = str(username, " lance ", count, "D", sides, " → ", list_txt, " = ", subtotal)
	if mod != 0:
		line += " ; total = " + str(total)
	_add_chat_line(line)

# === RÉSEAU =====================================================
func _drop_existing_peer() -> void:
	var mp: MultiplayerAPI = get_tree().get_multiplayer()
	if mp and mp.get_multiplayer_peer() != null:
		mp.multiplayer_peer = null

func _is_multiplayer_connected() -> bool:
	var mp: MultiplayerAPI = get_tree().get_multiplayer()
	if mp == null:
		return false
	var p: MultiplayerPeer = mp.get_multiplayer_peer()
	if p == null:
		return false
	if p is ENetMultiplayerPeer:
		var enp: ENetMultiplayerPeer = p
		return enp.get_connection_status() == ENetMultiplayerPeer.CONNECTION_CONNECTED
	return true

func _start_fresh_network_session() -> void:
	var mp: MultiplayerAPI = get_tree().get_multiplayer()

	var owner: String = ""
	if table_manager and table_manager.has_method("get_table_data"):
		var v: Variant = table_manager.call("get_table_data", _table_id)
		if v is Dictionary:
			owner = String((v as Dictionary).get("owner_username", ""))

	var ok: bool = false
	if _username != "" and _username == owner:
		if network_manager and network_manager.has_method("host_server"):
			ok = bool(network_manager.call("host_server", NET_PORT))
		else:
			var peer_try := ENetMultiplayerPeer.new()
			ok = (peer_try.create_server(NET_PORT, 32) == OK)
			if ok:
				mp.multiplayer_peer = peer_try
		if ok:
			_add_chat_line("[Réseau] Serveur prêt sur le port " + str(NET_PORT) + ".")
			_connect_multiplayer_signals_once()
			return
		else:
			_add_chat_line("[Réseau] Échec host_server — tentative client.")

	var ip_target: String = NET_IP_LOCAL
	if network_manager and network_manager.has_method("connect_to_server"):
		ok = bool(network_manager.call("connect_to_server", ip_target, NET_PORT))
	else:
		var peer_cli := ENetMultiplayerPeer.new()
		ok = (peer_cli.create_client(ip_target, NET_PORT) == OK)
		if ok:
			mp.multiplayer_peer = peer_cli

	if ok:
		_add_chat_line("[Réseau] Connecté au serveur " + ip_target + ":" + str(NET_PORT) + ".")
		_connect_multiplayer_signals_once()
	else:
		_add_chat_line("[Réseau] Aucune session — chat local uniquement.")

func _connect_multiplayer_signals_once() -> void:
	var mp: MultiplayerAPI = get_tree().get_multiplayer()
	if mp == null:
		return
	if mp.get_multiplayer_peer() == null:
		call_deferred("_connect_multiplayer_signals_once")
		return

	_set_rpc_root_to_scene()

	if not mp.connected_to_server.is_connected(_on_connected_to_server):
		mp.connected_to_server.connect(_on_connected_to_server)
	if not mp.connection_failed.is_connected(_on_connection_failed):
		mp.connection_failed.connect(_on_connection_failed)
	if not mp.server_disconnected.is_connected(_on_server_disconnected):
		mp.server_disconnected.connect(_on_server_disconnected)
	if not mp.peer_connected.is_connected(_on_peer_connected):
		mp.peer_connected.connect(_on_peer_connected)
	if not mp.peer_disconnected.is_connected(_on_peer_disconnected):
		mp.peer_disconnected.connect(_on_peer_disconnected)

func _set_rpc_root_to_scene() -> void:
	var cs: Node = get_tree().get_current_scene()
	var mp: MultiplayerAPI = get_tree().get_multiplayer()
	if cs and mp and mp.get_multiplayer_peer() != null:
		mp.root_path = cs.get_path()

func _on_connected_to_server() -> void:
	var mp: MultiplayerAPI = get_tree().get_multiplayer()
	var id_txt: String = ""
	if mp:
		id_txt = str(mp.get_unique_id())
	_add_chat_line("[Réseau] Connecté au serveur. ID=" + id_txt)

func _on_connection_failed() -> void:
	_add_chat_line("[Réseau] Échec de connexion.")

func _on_server_disconnected() -> void:
	_add_chat_line("[Réseau] Déconnecté du serveur.")

func _on_peer_connected(id: int) -> void:
	_add_chat_line("[Réseau] Peer connecté: " + str(id))
	if get_tree().get_multiplayer().is_server():
		var payload: Array = _serialize_full_state()
		rpc_id(id, "rpc_full_state", payload)

func _on_peer_disconnected(id: int) -> void:
	_add_chat_line("[Réseau] Peer déconnecté: " + str(id))

# === BOARD / IMAGES ============================================
func _get_board_layer() -> Control:
	var n: Node = find_child("BoardLayer", true, false)
	if n and n is Control:
		return n as Control
	var layer := Control.new()
	layer.name = "BoardLayer"
	layer.anchor_left = 0; layer.anchor_top = 0
	layer.anchor_right = 1; layer.anchor_bottom = 1
	layer.offset_left = 0; layer.offset_top = 0
	layer.offset_right = 0; layer.offset_bottom = 0
	layer.mouse_filter = Control.MOUSE_FILTER_PASS
	layer.z_index = -1000
	add_child(layer)
	move_child(layer, 0)
	return layer

func _clear_board_images() -> void:
	if _board_layer == null:
		return
	for c in _board_layer.get_children():
		if c is ResizableImage:
			c.queue_free()

func _respawn_board_for_current_scene() -> void:
	_clear_board_images()
	if _current_scene_id == "":
		return
	if not _images_by_scene.has(_current_scene_id):
		_images_by_scene[_current_scene_id] = {}
	var dict: Dictionary = _images_by_scene[_current_scene_id]
	for id in dict.keys():
		var e: Dictionary = dict[id]
		var path: String = String(e.get("path",""))
		var pos:  Vector2 = _vec2_from_any(e.get("pos", Vector2.ZERO))
		var size: Vector2 = _vec2_from_any(e.get("size", Vector2(256,256)))
		_spawn_image_node(String(id), path, pos, size)

# Ajout d’image (optionnel, accessible depuis le gestionnaire si besoin)
func _ensure_file_dialog() -> void:
	if _file_dialog:
		return
	_file_dialog = FileDialog.new()
	_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_file_dialog.add_filter("*.png; PNG")
	_file_dialog.add_filter("*.jpg,*.jpeg; JPEG")
	_file_dialog.add_filter("*.webp; WebP")
	add_child(_file_dialog)
	_file_dialog.file_selected.connect(_on_image_file_selected)

func _on_image_file_selected(path: String) -> void:
	var img := Image.new()
	if img.load(path) != OK:
		_add_chat_line("[Système] Impossible de charger l'image : " + path)
		return
	var bytes: PackedByteArray = img.save_png_to_buffer()
	var id: String = _gen_image_id()
	var name_only: String = _basename(path)
	var vp: Vector2 = get_viewport_rect().size
	var pos: Vector2 = (vp * 0.5) - Vector2(128, 128)
	var size: Vector2 = Vector2(256, 256)
	rpc("rpc_add_image_bytes", id, name_only, bytes, pos, size, _current_scene_id)

@rpc("any_peer", "call_local")
func rpc_add_image_bytes(id: String, original_name: String, png_bytes: PackedByteArray, pos: Vector2, size: Vector2, scene_id: String) -> void:
	var path: String = _write_shared_image(id, original_name, png_bytes)
	if not _images_by_scene.has(scene_id):
		_images_by_scene[scene_id] = {}
	_images_by_scene[scene_id][id] = {"file_name": original_name, "path": path, "pos": pos, "size": size}
	_save_images_by_scene()
	if scene_id == _current_scene_id:
		_spawn_image_node(id, path, pos, size)
# si la scène n’a pas encore de miniature, prends ce visuel
	if _scenes.has(scene_id):
		var sd: Dictionary = _scenes[scene_id]
		var tp: String = String(sd.get("thumb_path",""))
		if tp == "":
			sd["thumb_path"] = path
			_scenes[scene_id] = sd
			_save_scenes_to_disk()
			_push_scene_model_to_browser()


@rpc("any_peer", "call_local")
func rpc_update_image(id: String, pos: Vector2, size: Vector2, scene_id: String) -> void:
	if not _images_by_scene.has(scene_id):
		return
	if not _images_by_scene[scene_id].has(id):
		return
	_images_by_scene[scene_id][id]["pos"] = pos
	_images_by_scene[scene_id][id]["size"] = size
	_save_images_by_scene()
	if scene_id != _current_scene_id:
		return
	var node: Node = _board_layer.find_child("Img_"+id, true, false)
	if node and node is ResizableImage:
		var ri := node as ResizableImage
		ri.position = pos
		ri.size = size
		var texrect: TextureRect = ri.find_child("Texture", true, false) as TextureRect
		if texrect:
			texrect.size = size

@rpc("any_peer", "call_local")
func rpc_remove_image(id: String, scene_id: String) -> void:
	if _images_by_scene.has(scene_id) and _images_by_scene[scene_id].has(id):
		_images_by_scene[scene_id].erase(id)
		_save_images_by_scene()
	if scene_id != _current_scene_id:
		return
	var node: Node = _board_layer.find_child("Img_"+id, true, false)
	if node:
		node.queue_free()

@rpc("any_peer", "call_local")
func rpc_full_state(entries: Array) -> void:
	_is_loading_full_state = true
	for e_v in entries:
		if typeof(e_v) != TYPE_DICTIONARY:
			continue
		var e: Dictionary = e_v
		var id: String = String(e.get("id",""))
		var name: String = String(e.get("filename","image"))
		var bytes: PackedByteArray = PackedByteArray()
		var bv: Variant = e.get("bytes", PackedByteArray())
		if bv is PackedByteArray:
			bytes = bv
		var pos: Vector2 = _vec2_from_any(e.get("pos", Vector2.ZERO))
		var size: Vector2 = _vec2_from_any(e.get("size", Vector2(256,256)))
		var scene_id: String = String(e.get("scene_id",""))
		if id == "" or bytes.is_empty() or scene_id == "":
			continue
		rpc_add_image_bytes(id, name, bytes, pos, size, scene_id)
	_is_loading_full_state = false
	_respawn_board_for_current_scene()

func _spawn_image_node(id: String, path: String, pos: Vector2, size: Vector2) -> ResizableImage:
	var ri := ResizableImage.new()
	ri.name = "Img_" + id
	ri.image_id = id
	_board_layer.add_child(ri)
	ri.position = pos
	if ri.has_method("set_image_from_file"):
		ri.call("set_image_from_file", path)
	else:
		var img := Image.new()
		if img.load(path) == OK:
			var tex := ImageTexture.create_from_image(img)
			var tr: TextureRect = ri.find_child("Texture", true, false) as TextureRect
			if tr == null:
				tr = TextureRect.new()
				tr.name = "Texture"
				tr.stretch_mode = TextureRect.STRETCH_SCALE
				ri.add_child(tr)
			tr.texture = tex
	ri.size = size
	var tr2: TextureRect = ri.find_child("Texture", true, false) as TextureRect
	if tr2:
		tr2.size = size

	ri.image_changed.connect(func(_id: String, p: Vector2, s: Vector2) -> void:
		if _id == id:
			if _images_by_scene.has(_current_scene_id) and _images_by_scene[_current_scene_id].has(id):
				_images_by_scene[_current_scene_id][id]["pos"] = p
				_images_by_scene[_current_scene_id][id]["size"] = s
				_save_images_by_scene()
			if _is_multiplayer_connected() and not _is_loading_full_state:
				rpc("rpc_update_image", id, p, s, _current_scene_id)
	)
	ri.image_delete_requested.connect(func(_id: String) -> void:
		if _id == id:
			if _is_multiplayer_connected():
				rpc("rpc_remove_image", id, _current_scene_id)
			else:
				rpc_remove_image(id, _current_scene_id)
	)
	return ri

func _write_shared_image(id: String, original_name: String, png_bytes: PackedByteArray) -> String:
	if DirAccess.make_dir_recursive_absolute(IMAGES_DIR) != OK:
		return "user://img_" + id + ".png"
	var safe_name: String = _basename(original_name)
	var file_path: String = IMAGES_DIR + "/" + id + "_" + safe_name + ".png"
	var f := FileAccess.open(file_path, FileAccess.WRITE)
	if f:
		f.store_buffer(png_bytes)
		f.close()
	return file_path

# === SAVE / LOAD ===============================================
func _images_by_scene_json_path() -> String:
	if DirAccess.make_dir_recursive_absolute(TABLES_DIR) != OK:
		pass
	return TABLES_DIR + "/" + _table_id + "_images_by_scene.json"

func _save_images_by_scene() -> void:
	var out: Dictionary = {}  # scene_id -> img_id -> dict JSON-safe
	for scene_id in _images_by_scene.keys():
		var dscene: Dictionary = _images_by_scene[scene_id]
		var scene_out: Dictionary = {}
		for img_id in dscene.keys():
			var e: Dictionary = dscene[img_id]
			var pos_v: Vector2 = _vec2_from_any(e.get("pos", Vector2.ZERO))
			var size_v: Vector2 = _vec2_from_any(e.get("size", Vector2(256,256)))
			scene_out[img_id] = {
				"file_name": String(e.get("file_name", "image")),
				"path": String(e.get("path", "")),
				"pos": [float(pos_v.x), float(pos_v.y)],
				"size": [float(size_v.x), float(size_v.y)]
			}
		out[scene_id] = scene_out
	var f := FileAccess.open(_images_by_scene_json_path(), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(out, "  "))
		f.close()

func _load_images_from_disk() -> void:
	_images_by_scene.clear()
	var p: String = _images_by_scene_json_path()
	if not FileAccess.file_exists(p):
		return
	var f := FileAccess.open(p, FileAccess.READ)
	if f == null:
		return
	var txt: String = f.get_as_text()
	f.close()
	var j := JSON.new()
	if j.parse(txt) != OK:
		return
	if typeof(j.data) != TYPE_DICTIONARY:
		return
	_images_by_scene = (j.data as Dictionary)

# === SCENES STORE ==============================================
func _scenes_json_path() -> String:
	if DirAccess.make_dir_recursive_absolute(TABLES_DIR) != OK:
		pass
	return TABLES_DIR + "/" + _table_id + "_scenes.json"

func _init_scene_store() -> void:
	_load_scenes_from_disk()
	if _current_scene_id == "" and _scenes.is_empty():
		_create_new_scene("Nouvelle scène")
	_save_scenes_to_disk()

func _load_scenes_from_disk() -> void:
	_scenes.clear()
	_current_scene_id = ""
	var p: String = _scenes_json_path()
	if not FileAccess.file_exists(p):
		return
	var f := FileAccess.open(p, FileAccess.READ)
	if f == null:
		return
	var txt: String = f.get_as_text()
	f.close()
	var j := JSON.new()
	if j.parse(txt) != OK:
		return
	if typeof(j.data) != TYPE_DICTIONARY:
		return
	var root: Dictionary = (j.data as Dictionary)
	var cur_v: Variant = root.get("current", "")
	if cur_v is String:
		_current_scene_id = String(cur_v)
	var list_v: Variant = root.get("scenes", {})
	if list_v is Dictionary:
		_scenes = (list_v as Dictionary)

func _save_scenes_to_disk() -> void:
	var f := FileAccess.open(_scenes_json_path(), FileAccess.WRITE)
	if f == null:
		return
	var out: Dictionary = { "current": _current_scene_id, "scenes": _scenes }
	f.store_string(JSON.stringify(out, "  "))
	f.close()

func _new_id(prefix: String) -> String:
	return prefix + "_" + str(Time.get_unix_time_from_system()) + "_" + str(randi())

func _create_new_scene(name_: String) -> String:
	var id: String = _new_id("scene")
	_scenes[id] = { "name": String(name_), "thumb_path": "" }
	_current_scene_id = id
	if not _images_by_scene.has(id):
		_images_by_scene[id] = {}
	_save_scenes_to_disk()
	_save_images_by_scene()
	_add_chat_line("[Scène] Créée : " + name_)
	_push_scene_model_to_browser()
	return id

func _rename_scene(scene_id: String, new_name: String) -> void:
	if scene_id == "":
		return
	if not _scenes.has(scene_id):
		return
	var d: Dictionary = _scenes[scene_id]
	d["name"] = String(new_name)
	_scenes[scene_id] = d
	_save_scenes_to_disk()
	if scene_id == _current_scene_id:
		_add_chat_line("[Scène] Renommée en : " + new_name)
		_push_scene_model_to_browser()
		
func _delete_scene(scene_id: String) -> void:
	if scene_id == "" or not _scenes.has(scene_id):
		return
	_scenes.erase(scene_id)
	if _images_by_scene.has(scene_id):
		_images_by_scene.erase(scene_id)
	if _current_scene_id == scene_id:
		_current_scene_id = _scenes.keys().front() if _scenes.size() > 0 else ""
	_save_scenes_to_disk()
	_save_images_by_scene()
	_respawn_board_for_current_scene()
	_push_scene_model_to_browser()

func _get_scene_name(id: String) -> String:
	if _scenes.has(id):
		var d: Dictionary = _scenes[id]
		return String(d.get("name",""))
	return ""

# === PANEL “SCÈNE” =============================================
func _build_scene_panel() -> void:
	if _scene_panel != null and is_instance_valid(_scene_panel):
		return
	_scene_panel = DraggablePanel.new()
	_scene_panel.name = "ScenePanel"
	_scene_panel.set_title("Scène")
	add_child(_scene_panel)
	_scene_panel.hide()
	_scene_panel.global_position = Vector2(220, 120)

	var vb := VBoxContainer.new()
	vb.custom_minimum_size = Vector2(320, 160)
	_scene_panel.set_content(vb)

	# 1) Renommer
	var h := HBoxContainer.new()
	vb.add_child(h)
	var lbl := Label.new()
	lbl.text = "Nom :"
	h.add_child(lbl)
	var tf := LineEdit.new()
	tf.name = "TFSceneName"
	tf.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tf.text = _get_scene_name(_current_scene_id)
	tf.placeholder_text = "Nom de la scène"
	h.add_child(tf)
	var bren := Button.new()
	bren.text = "Renommer"
	bren.pressed.connect(func():
		_rename_scene(_current_scene_id, tf.text.strip_edges())
	)
	h.add_child(bren)

	# 2) Ajouter image
	var badd := Button.new()
	badd.text = "Ajouter image…"
	badd.focus_mode = Control.FOCUS_NONE
	badd.pressed.connect(func():
		_ensure_file_dialog()
		_file_dialog.popup_centered_ratio(0.75)
	)
	vb.add_child(badd)

	# 3) Nouvelle scène
	var bnew := Button.new()
	bnew.text = "Nouvelle scène"
	bnew.pressed.connect(func():
		var new_id := _create_new_scene("Nouvelle scène")
		_set_current_scene(new_id)
		_respawn_board_for_current_scene()
		tf.text = _get_scene_name(_current_scene_id)
	)
	vb.add_child(bnew)

	# 4) Gestionnaire
	var bman := Button.new()
	bman.text = "Gestionnaire de scènes…"
	bman.pressed.connect(_toggle_scene_browser) # ← au lieu de _open_scene_browser
	vb.add_child(bman)

func _toggle_scene_panel() -> void:
	if _scene_panel == null:
		_build_scene_panel()
	if _scene_panel.visible:
		_scene_panel.hide()
	else:
		_scene_panel.show()
		_scene_panel.move_to_front()

func _set_current_scene(id: String) -> void:
	if id == "" or not _scenes.has(id):
		return
	_current_scene_id = id
	_save_scenes_to_disk()
	_push_scene_model_to_browser()

func _build_scene_model() -> Dictionary:
	var scenes_arr: Array = []
	for id in _scenes.keys():
		var name: String = _get_scene_name(id)
		var players: Array = []           # à remplir plus tard si tu as une liste réseau
		var gm_here: bool = false
		var thumb: String = _get_scene_thumb(id)   # <-- manquait

		scenes_arr.append({
			"id": id,
			"name": name,
			"players": players,
			"gm_here": gm_here,
			"thumb_path": thumb                # le SceneBrowserPanel lit ce champ
		})

	# (facultatif pour la colonne de droite)
	var players_list: Array = []
	return {
		"active": _current_scene_id,
		"scenes": scenes_arr,
		"players": players_list
	}


func _push_scene_model_to_ui() -> void:
	if _scene_ui:
		_scene_ui.set_model(_build_scene_model())

# === PANEL “CHAT” ==============================================
func _build_chat_panel() -> void:
	if _chat_panel != null and is_instance_valid(_chat_panel):
		return
	_chat_panel = DraggablePanel.new()
	_chat_panel.name = "ChatPanel"
	_chat_panel.set_title("Chat")
	add_child(_chat_panel)
	_chat_panel.hide()
	_chat_panel.global_position = Vector2(24, 120)

	var body := VBoxContainer.new()
	body.name = "ChatBody"
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	_chat_panel.set_content(body)

func _wrap_chat_in_panel() -> void:
	if _chat_panel == null or not is_instance_valid(_chat_panel):
		return
	var body: VBoxContainer = _chat_panel.find_child("ChatBody", true, false) as VBoxContainer
	if body == null:
		return
	if chat_scroll and chat_scroll.get_parent() != body:
		chat_scroll.get_parent().remove_child(chat_scroll)
		body.add_child(chat_scroll)
	if hbox_chat and hbox_chat.get_parent() != body:
		hbox_chat.get_parent().remove_child(hbox_chat)
		body.add_child(hbox_chat)
	_chat_panel.custom_minimum_size = Vector2(420, 240)

func _toggle_chat_panel() -> void:
	if _chat_panel == null:
		return
	if _chat_panel.visible:
		_chat_panel.hide()
	else:
		_chat_panel.show()
		_chat_panel.move_to_front()

# === HELPERS ====================================================
func _serialize_full_state() -> Array:
	var arr: Array = []
	for scene_id in _images_by_scene.keys():
		var dscene: Dictionary = _images_by_scene[scene_id]
		for img_id in dscene.keys():
			var e: Dictionary = dscene[img_id]
			var filename: String = String(e.get("file_name",""))
			var path: String     = String(e.get("path",""))
			var pos: Vector2     = _vec2_from_any(e.get("pos", Vector2.ZERO))
			var size: Vector2    = _vec2_from_any(e.get("size", Vector2(256,256)))
			var bytes: PackedByteArray = PackedByteArray()
			if FileAccess.file_exists(path):
				var f := FileAccess.open(path, FileAccess.READ)
				if f != null:
					bytes = f.get_buffer(f.get_length())
					f.close()
			arr.append({
				"id": String(img_id),
				"filename": filename,
				"bytes": bytes,
				"pos": pos,
				"size": size,
				"scene_id": String(scene_id)
			})
	return arr

func _vec2_from_any(v: Variant) -> Vector2:
	if typeof(v) == TYPE_VECTOR2:
		return v
	if typeof(v) == TYPE_ARRAY:
		var a: Array = v
		if a.size() >= 2:
			return Vector2(float(a[0]), float(a[1]))
	return Vector2.ZERO

func _get_username_safe() -> String:
	if account_manager:
		if account_manager.has_method("get_current_username"):
			var v: Variant = account_manager.call("get_current_username")
			if v != null:
				return String(v)
		var p: Variant = account_manager.get("current_username")
		if p != null:
			return String(p)
	return "Joueur"

func _get_table_id_safe() -> String:
	if table_manager and table_manager.has_method("get_current_table_id"):
		var v: Variant = table_manager.call("get_current_table_id")
		if v != null:
			return String(v)
	return "default_table"

func _table_name_safe() -> String:
	if table_manager and table_manager.has_method("get_table_data"):
		var d: Variant = table_manager.call("get_table_data", _get_table_id_safe())
		if d is Dictionary:
			return String((d as Dictionary).get("table_name","Table"))
	return "Table"

func _find_autoload(name_wanted: String) -> Node:
	var root: Window = get_tree().get_root()
	if root:
		var aut: Node = root.find_child(name_wanted, false, false)
		if aut:
			return aut
	var cs: Node = get_tree().get_current_scene()
	if cs:
		var local: Node = cs.find_child(name_wanted, true, false)
		if local:
			return local
	return null

func _basename(path: String) -> String:
	var s: String = path
	var slash: int = max(s.rfind("/"), s.rfind("\\"))
	if slash >= 0:
		s = s.substr(slash + 1)
	var dot: int = s.rfind(".")
	if dot > 0:
		s = s.substr(0, dot)
	return s

func _gen_image_id() -> String:
	var sec: int = Time.get_unix_time_from_system()
	var ms: int  = Time.get_ticks_msec() % 1000
	randomize()
	return str(sec) + "_" + str(ms) + "_" + str(randi())

func _open_scene_browser() -> void:
	if _scene_browser_window == null:
		_scene_browser_window = DraggablePanel.new()
		_scene_browser_window.set_title("Gestionnaire de scènes")
		_scene_browser_window.global_position = Vector2(360, 120)
		add_child(_scene_browser_window)
		_scene_browser_ui = SceneBrowserPanel.new()
		_scene_browser_window.set_content(_scene_browser_ui)
		_scene_browser_window.visible = false

		# connexions
		_scene_browser_ui.activate_scene_requested.connect(func(id: String) -> void:
			_set_current_scene(id)
			_respawn_board_for_current_scene()
			_push_scene_model_to_browser()
		)
		_scene_browser_ui.move_gm_requested.connect(func(id: String) -> void:
			_add_chat_line("[Scène] MJ → " + _get_scene_name(id))
			# TODO: branchement réseau si besoin
		)
		_scene_browser_ui.move_user_requested.connect(func(uid: String, sid: String) -> void:
			_add_chat_line("[Scène] Déplacer " + uid + " → " + _get_scene_name(sid))
			# TODO: branchement réseau si besoin
		)

	_push_scene_model_to_browser()
	_scene_browser_window.show()
	_scene_browser_window.move_to_front()

func _get_scene_thumb(scene_id: String) -> String:
	if _scenes.has(scene_id):
		var d: Dictionary = _scenes[scene_id]
		var t := String(d.get("thumb_path",""))
		if t != "":
			return t
	if _images_by_scene.has(scene_id):
		var dscene: Dictionary = _images_by_scene[scene_id]
		for k in dscene.keys():
			var e: Dictionary = dscene[k]
			return String(e.get("path",""))
	return ""

func _toggle_scene_browser() -> void:
	_ensure_scene_browser()
	if _scene_browser_panel.visible:
		_scene_browser_panel.hide()
	else:
		_push_scene_model_to_browser()
		_scene_browser_panel.show()
		_scene_browser_panel.move_to_front()

func _push_scene_model_to_browser() -> void:
	if _scene_browser_ui:
		var model := _build_scene_model()
		print("[SceneBrowser] push model: active=", model.get("active",""),
			  " scenes=", (model.get("scenes", []) as Array).size())
		_scene_browser_ui.set_model(model)


func _ensure_scene_browser() -> void:
	if _scene_browser_panel and is_instance_valid(_scene_browser_panel):
		return

	_scene_browser_ui = SceneBrowserPanel.new()
	# très important : que le contenu occupe l’espace
	_scene_browser_ui.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scene_browser_ui.size_flags_vertical   = Control.SIZE_EXPAND_FILL

	_scene_browser_panel = DraggablePanel.new()
	_scene_browser_panel.set_title("Gestionnaire de scènes")
	_scene_browser_panel.visible = false
	_scene_browser_panel.global_position = Vector2(56, 56)

	# Donne VRAIMENT une taille au panneau
	_scene_browser_panel.custom_minimum_size = Vector2(560, 420)
	_scene_browser_panel.size = Vector2(560, 420) # assure l’ouverture “grande”

	_scene_browser_panel.set_content(_scene_browser_ui)
	add_child(_scene_browser_panel)

# --- poignée de resize en bas-droite du gestionnaire
	var rh := ResizeHandle.new()
	rh.name = "ResizeHandle"
	rh.target = _scene_browser_panel
	rh.min_size = Vector2(360, 240)

	# 1) donner une taille AVANT les anchors/offsets
	rh.custom_minimum_size = Vector2(24, 24)
	rh.size = rh.custom_minimum_size

	# 2) ancrer coin bas-droite
	rh.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT, true)
	rh.offset_right = 0
	rh.offset_bottom = 0
	rh.offset_left = -rh.size.x
	rh.offset_top  = -rh.size.y

	# 3) empêcher toute extension automatique
	rh.size_flags_horizontal = 0
	rh.size_flags_vertical   = 0

	# 4) seul le handle doit consommer l’input
	rh.mouse_filter = Control.MOUSE_FILTER_STOP

	_scene_browser_panel.add_child(rh)



	# pour être sûr que seul le handle capte l’input de resize
	rh.mouse_filter = Control.MOUSE_FILTER_STOP

	rh.offset_bottom = 0

	# Signaux venant de la liste
	_scene_browser_ui.activate_scene_requested.connect(func(scene_id: String) -> void:
		_set_current_scene(scene_id)
		_respawn_board_for_current_scene()
		_push_scene_model_to_browser()
	)
	_scene_browser_ui.move_user_requested.connect(func(user_id: String, scene_id: String) -> void:
		_add_chat_line("[Scène] Déplacer joueur %s → %s" % [user_id, scene_id])
	)
	_scene_browser_ui.move_gm_requested.connect(func(scene_id: String) -> void:
		_add_chat_line("[Scène] Déplacer le MJ → %s" % scene_id)
	)
