extends Node

# user://Data/Tables/table_<uuid>.json
# {
#   "table_id": "<uuid>",
#   "table_name": "<name>",
#   "owner_username": "<owner>",
#   "invited_players": ["Alice","Bob"],
#   "participants": { "Owner": "MJ", "Alice": "Joueur" }
# }

var _tables_cache: Dictionary = {}    # table_id -> Dictionary
var _current_table_id: String = ""

func _ready() -> void:
	_ensure_dir()

# ---------- API de base ----------
func create_table(owner_username: String, table_name: String) -> String:
	_ensure_dir()
	var uuid: String = _uuid_v4()
	var d: Dictionary = {
		"table_id": uuid,
		"table_name": table_name,
		"owner_username": owner_username,
		"invited_players": [],
		"participants": {}
	}
	# Owner = MJ
	var parts: Dictionary = d.get("participants", {})
	parts[owner_username] = "MJ"
	d["participants"] = parts

	if not _save_table_dict(d):
		return ""
	_tables_cache[uuid] = d.duplicate(true)
	return uuid

func get_table_data(table_id: String) -> Dictionary:
	if table_id == "":
		return {}
	if _tables_cache.has(table_id):
		return (_tables_cache[table_id] as Dictionary).duplicate(true)
	var d: Dictionary = _load_table_dict(table_id)
	if not d.is_empty():
		_normalize_table_dict(d)
		_tables_cache[table_id] = d.duplicate(true)
	return d

func rename_table(table_id: String, new_name: String) -> bool:
	if table_id == "":
		return false
	var d: Dictionary = get_table_data(table_id)
	if d.is_empty():
		return false
	d["table_name"] = new_name
	var ok: bool = _save_table_dict(d)
	if ok:
		_tables_cache[table_id] = d.duplicate(true)
	return ok

func delete_table(table_id: String) -> bool:
	if table_id == "":
		return false
	var p: String = _table_path(table_id)
	if not FileAccess.file_exists(p):
		_tables_cache.erase(table_id)
		return true
	var abs: String = ProjectSettings.globalize_path(p)
	var err: int = DirAccess.remove_absolute(abs)
	if err == OK:
		_tables_cache.erase(table_id)
		return true
	return false

func table_exists(table_id: String) -> bool:
	return not get_table_data(table_id).is_empty()

# ---------- Participants / Invites ----------
func add_invited_player(table_id: String, username: String) -> bool:
	var d: Dictionary = get_table_data(table_id)
	if d.is_empty() or username == "":
		return false
	var invites: Array = d.get("invited_players", [])
	if not invites.has(username):
		invites.append(username)
		d["invited_players"] = invites
		if _save_table_dict(d):
			_tables_cache[table_id] = d.duplicate(true)
			return true
	return true

func set_participant_role(table_id: String, username: String, role: String) -> bool:
	var d: Dictionary = get_table_data(table_id)
	if d.is_empty() or username == "":
		return false
	var parts: Dictionary = d.get("participants", {})
	parts[username] = role
	d["participants"] = parts
	if _save_table_dict(d):
		_tables_cache[table_id] = d.duplicate(true)
		return true
	return false

func remove_participant(table_id: String, username: String) -> bool:
	var d: Dictionary = get_table_data(table_id)
	if d.is_empty() or username == "":
		return false
	var parts: Dictionary = d.get("participants", {})
	if parts.has(username):
		parts.erase(username)
		d["participants"] = parts
		if _save_table_dict(d):
			_tables_cache[table_id] = d.duplicate(true)
			return true
	return false

func get_participants(table_id: String) -> Dictionary:
	var d: Dictionary = get_table_data(table_id)
	if d.is_empty():
		return {}
	return d.get("participants", {})

# ---------- table courante ----------
func set_current_table_id(tid: String) -> void:
	_current_table_id = tid

func get_current_table_id() -> String:
	return _current_table_id

# ---------- Fichiers ----------
func _tables_dir() -> String:
	return "user://Data/Tables"

func _table_path(table_id: String) -> String:
	return _tables_dir().rstrip("/") + "/table_%s.json".format([table_id])

func _ensure_dir() -> void:
	var abs: String = ProjectSettings.globalize_path(_tables_dir())
	DirAccess.make_dir_recursive_absolute(abs)

func _save_table_dict(d: Dictionary) -> bool:
	if not d.has("table_id"):
		return false
	_normalize_table_dict(d)
	var path: String = _table_path(str(d["table_id"]))
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(d, "  "))
	f.flush()
	f.close()
	return true

func _load_table_dict(table_id: String) -> Dictionary:
	var path: String = _table_path(table_id)
	if not FileAccess.file_exists(path):
		return {}
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var txt: String = f.get_as_text()
	f.close()
	var j: JSON = JSON.new()
	var err: int = j.parse(txt)
	if err != OK:
		return {}
	var raw: Variant = j.data
	if typeof(raw) == TYPE_DICTIONARY:
		var d: Dictionary = raw
		_normalize_table_dict(d)
		return d
	return {}

func _normalize_table_dict(d: Dictionary) -> void:
	if not d.has("invited_players"): d["invited_players"] = []
	if not d.has("participants"): d["participants"] = {}
	if not d.has("table_name"): d["table_name"] = "Nouvelle Table"
	if not d.has("owner_username"): d["owner_username"] = ""

# ---------- UUID ----------
func _uuid_v4() -> String:
	var bytes: PackedByteArray = Crypto.new().generate_random_bytes(16)
	bytes[6] = (bytes[6] & 0x0F) | 0x40
	bytes[8] = (bytes[8] & 0x3F) | 0x80
	var hex: String = bytes.hex_encode()
	return "%s-%s-%s-%s-%s" % [
		hex.substr(0, 8),
		hex.substr(8, 4),
		hex.substr(12, 4),
		hex.substr(16, 4),
		hex.substr(20, 12)
	]

# ---------- (déjà proposés précédemment) index utilitaires ----------
func get_all_tables() -> Array:
	var out: Array = []
	_ensure_dir()
	var abs_dir: String = ProjectSettings.globalize_path(_tables_dir())
	var da: DirAccess = DirAccess.open(abs_dir)
	if da == null:
		return out
	da.list_dir_begin()
	while true:
		var fn: String = da.get_next()
		if fn == "":
			break
		if da.current_is_dir():
			continue
		if fn.begins_with("table_") and fn.ends_with(".json"):
			var id: String = fn.trim_prefix("table_").trim_suffix(".json")
			var d: Dictionary = _load_table_dict(id)
			if not d.is_empty():
				out.append(d)
	da.list_dir_end()
	return out

func find_table_id_by_name_exact(name: String) -> String:
	if name == "":
		return ""
	var matches: Array = []
	var arr: Array = get_all_tables()
	for d in arr:
		var tname: String = str((d as Dictionary).get("table_name", ""))
		if tname == name:
			var tid: String = str((d as Dictionary).get("table_id", ""))
			if tid != "":
				matches.append(tid)
	if matches.size() == 1:
		return matches[0]
	return ""
	
# --- Retirer un invité (et sa trace éventuelle dans participants) ---
func remove_invited_player(table_id: String, username: String) -> bool:
	var d: Dictionary = get_table_data(table_id)
	if d.is_empty() or username == "":
		return false

	var changed: bool = false

	var invites: Array = d.get("invited_players", [])
	if invites.has(username):
		invites.erase(username)
		d["invited_players"] = invites
		changed = true

	# On enlève aussi son rôle préparé au moment de l'invite (s'il existe)
	var parts: Dictionary = d.get("participants", {})
	if parts.has(username):
		parts.erase(username)
		d["participants"] = parts
		changed = true

	if changed and _save_table_dict(d):
		_tables_cache[table_id] = d.duplicate(true)
		return true
	return changed

# --- Variante "kick": supprime dans participants, et si encore invité -> supprime aussi ---
func kick_user(table_id: String, username: String) -> bool:
	var d: Dictionary = get_table_data(table_id)
	if d.is_empty() or username == "":
		return false
	if is_owner(table_id, username):
		return false # on ne kick pas le MJ

	var changed: bool = false
	var parts: Dictionary = d.get("participants", {})
	if parts.has(username):
		parts.erase(username)
		d["participants"] = parts
		changed = true

	var invites: Array = d.get("invited_players", [])
	if invites.has(username):
		invites.erase(username)
		d["invited_players"] = invites
		changed = true

	if changed and _save_table_dict(d):
		_tables_cache[table_id] = d.duplicate(true)
		return true
	return changed

# --- Ownership / leave helpers (UNIQUE) ---
func is_owner(table_id: String, username: String) -> bool:
	var d: Dictionary = get_table_data(table_id)
	if d.is_empty():
		return false
	return str(d.get("owner_username","")) == username

func remove_user_from_table(table_id: String, username: String) -> bool:
	if table_id == "" or username == "":
		return false
	var d: Dictionary = get_table_data(table_id)
	if d.is_empty():
		return false

	var changed: bool = false

	# participants
	var parts: Dictionary = d.get("participants", {})
	if parts.has(username):
		parts.erase(username)
		d["participants"] = parts
		changed = true

	# invités
	var invites: Array = d.get("invited_players", [])
	if invites.has(username):
		invites.erase(username)
		d["invited_players"] = invites
		changed = true

	if changed and _save_table_dict(d):
		_tables_cache[table_id] = d.duplicate(true)
		return true
	return changed

# --- Compat NetworkManager (UNIQUE) ---
func get_table_info(table_id: String) -> Dictionary:
	return get_table_data(table_id)

func add_or_update_invited_player(table_id: String, username: String, role: String) -> bool:
	var ok1: bool = add_invited_player(table_id, username)
	var ok2: bool = set_participant_role(table_id, username, role)
	return ok1 and ok2

# Le joueur "username" a-t-il un lien légitime avec la table ?
# -> owner OU déjà invité OU déjà participant.
func is_member(table_id: String, username: String) -> bool:
	if table_id == "" or username == "":
		return false
	var d: Dictionary = get_table_data(table_id)
	if d.is_empty():
		return false
	if str(d.get("owner_username","")) == username:
		return true
	var parts: Dictionary = d.get("participants", {})
	if parts.has(username):
		return true
	var invited: Array = d.get("invited_players", [])
	if invited.has(username):
		return true
	return false
