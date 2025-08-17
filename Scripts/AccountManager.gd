extends Node
# Pas de class_name (évite conflit avec autoload)

var users_data: Dictionary = {}
var _current_username: String = ""

# ---------------- PATHS ----------------
func _get_users_dir() -> String:
	return "user://Data/Users/"

func _globalize(p: String) -> String:
	return ProjectSettings.globalize_path(p)

func _ensure_dir_absolute(path_user_scheme: String) -> void:
	var abs: String = _globalize(path_user_scheme)
	if not DirAccess.dir_exists_absolute(abs):
		var err: int = DirAccess.make_dir_recursive_absolute(abs)
		if err != OK:
			push_error("[AccountManager] Impossible de créer le dossier: " + abs)

# ---------------- SESSION ----------------
func set_current_username(username: String) -> void:
	_current_username = username

func get_current_username() -> String:
	return _current_username

func get_user_data(username: String) -> Dictionary:
	if users_data.has(username):
		return users_data[username]
	return {}

# ---------------- UTIL ----------------
func _user_file_path(username: String) -> String:
	return _get_users_dir() + "user_%s.json" % username

func _scan_all_user_jsons() -> Array:
	# Liste TOUS les .json (user_*.json + anciens *.json)
	_ensure_dir_absolute(_get_users_dir())
	var out: Array = []
	var da: DirAccess = DirAccess.open(_get_users_dir())
	if da == null:
		push_error("[AccountManager] DirAccess.open a échoué sur: " + _globalize(_get_users_dir()))
		return out
	da.list_dir_begin()
	var name: String = da.get_next()
	while name != "":
		if not da.current_is_dir() and name.ends_with(".json"):
			out.append(name)
		name = da.get_next()
	da.list_dir_end()
	return out

func _basename_without_prefix(fname: String) -> String:
	# "user_Ozny.json" -> "Ozny", "Ozny.json" -> "Ozny"
	var base: String = fname
	if base.ends_with(".json"):
		base = base.left(base.length() - 5)
	if base.begins_with("user_"):
		base = base.substr(5)
	return base

func _first_non_empty(a: String, b: String) -> String:
	return a if a.strip_edges() != "" else b

func _to_array(v: Variant) -> Array:
	# Garantit un Array, même si vieux formats (Dictionary, null, String…)
	if typeof(v) == TYPE_ARRAY:
		return v
	if typeof(v) == TYPE_DICTIONARY:
		var d: Dictionary = v
		return d.values()
	return []

# ---------------- NORMALISATION ----------------
func _normalize_user_dict(d_in: Dictionary) -> Dictionary:
	var d: Dictionary = d_in.duplicate(true)

	var email: String = String(d.get("email", ""))
	var username: String = String(d.get("username", _first_non_empty(String(d.get("user","")), String(d.get("name","")))))

	# mots de passe legacy
	var password_keys: Array = ["password", "pass", "pwd", "mdp"]
	var pwd: String = ""
	for k in password_keys:
		if d.has(k):
			pwd = String(d[k])
			break

	var friends: Array = []
	if d.has("friends"):
		friends = _to_array(d["friends"])
	elif d.has("amis"):
		friends = _to_array(d["amis"])

	var tables_joined: Array = []
	if d.has("tables_joined"):
		tables_joined = _to_array(d["tables_joined"])
	elif d.has("tables"):
		tables_joined = _to_array(d["tables"])

	var invitations: Array = []
	if d.has("invitations"):
		invitations = _to_array(d["invitations"])

	return {
		"email": email,
		"username": username,
		"password": pwd,
		"friends": friends,
		"tables_joined": tables_joined,
		"invitations": invitations
	}

# ---------------- I/O ----------------
func save_user(username: String) -> bool:
	if not users_data.has(username):
		return false
	_ensure_dir_absolute(_get_users_dir())
	var path: String = _user_file_path(username)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("[AccountManager] Échec ouverture écriture: " + _globalize(path))
		return false
	var data: Dictionary = _normalize_user_dict(users_data[username])
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	return true

func load_user(username: String) -> Dictionary:
	var path_std: String = _user_file_path(username)
	var path_legacy: String = _get_users_dir() + "%s.json" % username

	var path: String = ""
	if FileAccess.file_exists(path_std):
		path = path_std
	elif FileAccess.file_exists(path_legacy):
		path = path_legacy
	else:
		return {}

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("[AccountManager] Échec ouverture lecture: " + _globalize(path))
		return {}
	var text: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) == TYPE_DICTIONARY:
		var d: Dictionary = _normalize_user_dict(parsed)
		if String(d.get("username","")) == "":
			d["username"] = username
		users_data[String(d["username"])] = d
		return d
	return {}

# ---------------- AUTH (email OU pseudo, legacy OK) ----------------
# Retourne le username trouvé ou ""
func validate_login(email: String, password: String) -> String:
	var input_id: String = email.strip_edges()
	var input_pw: String = password

	var files: Array = _scan_all_user_jsons()
	for fname in files:
		var path: String = _get_users_dir() + fname
		var f: FileAccess = FileAccess.open(path, FileAccess.READ)
		if f == null:
			continue
		var txt: String = f.get_as_text()
		f.close()

		var parsed: Variant = JSON.parse_string(txt)
		if typeof(parsed) != TYPE_DICTIONARY:
			continue
		var raw: Dictionary = parsed
		var d: Dictionary = _normalize_user_dict(raw)

		# fallback username depuis nom de fichier
		var filename_user: String = _basename_without_prefix(fname)
		if String(d.get("username","")) == "":
			d["username"] = filename_user

		var em: String = String(d.get("email",""))
		var un: String = String(d.get("username",""))
		var pw: String = String(d.get("password",""))

		# identifiant insensible à la casse : email, username ou nom de fichier
		var id_l: String = input_id.to_lower()
		var match: bool = (id_l == em.to_lower()) or (id_l == un.to_lower()) or (id_l == filename_user.to_lower())
		if not match:
			continue

		# mot de passe (champ manquant = "", donc accepte si input vide)
		if pw == input_pw:
			users_data[un] = d
			set_current_username(un)
			return un

	return ""

# ---------------- CREATE ----------------
func create_account(email: String, password: String, username: String) -> bool:
	if email.strip_edges() == "" or password.strip_edges() == "" or username.strip_edges() == "":
		return false
	if users_data.has(username):
		return false

	# unicité tous formats
	var files: Array = _scan_all_user_jsons()
	for fname in files:
		var path: String = _get_users_dir() + fname
		var f: FileAccess = FileAccess.open(path, FileAccess.READ)
		if f == null:
			continue
		var txt: String = f.get_as_text(); f.close()
		var parsed: Variant = JSON.parse_string(txt)
		if typeof(parsed) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = _normalize_user_dict(parsed)
		if String(d.get("username","")).to_lower() == username.to_lower():
			return false
		var em: String = String(d.get("email",""))
		if em != "" and em.to_lower() == email.to_lower():
			return false

	var new_user: Dictionary = _normalize_user_dict({
		"email": email,
		"username": username,
		"password": password,
		"friends": [],
		"tables_joined": [],
		"invitations": []
	})
	users_data[username] = new_user

	if not save_user(username):
		users_data.erase(username)
		return false

	set_current_username(username)
	return true

# ---------------- FRIENDS / TABLES ----------------
func add_friend(username: String, friend_username: String) -> bool:
	if username == "" or friend_username.strip_edges() == "":
		return false
	var ud: Dictionary = get_user_data(username)
	if ud.is_empty():
		ud = load_user(username)
		if ud.is_empty():
			return false
	var friends: Array = _to_array(ud.get("friends", []))
	if not friends.has(friend_username):
		friends.append(friend_username)
		ud["friends"] = friends
		users_data[username] = _normalize_user_dict(ud)
		return save_user(username)
	return true

func add_joined_table(table_id: String) -> bool:
	var uname: String = get_current_username()
	if uname == "":
		return false
	var ud: Dictionary = get_user_data(uname)
	if ud.is_empty():
		ud = load_user(uname)
		if ud.is_empty():
			return false
	var tj: Array = _to_array(ud.get("tables_joined", []))
	if not tj.has(table_id):
		tj.append(table_id)
		ud["tables_joined"] = tj
		users_data[uname] = _normalize_user_dict(ud)
		return save_user(uname)
	return true

func remove_joined_table(table_id: String) -> bool:
	var uname: String = get_current_username()
	if uname == "":
		return false
	var ud: Dictionary = get_user_data(uname)
	if ud.is_empty():
		ud = load_user(uname)
		if ud.is_empty():
			return false
	var tj: Array = _to_array(ud.get("tables_joined", []))
	if tj.has(table_id):
		tj.erase(table_id)
		ud["tables_joined"] = tj
		users_data[uname] = _normalize_user_dict(ud)
		return save_user(uname)
	return true

# ---------------- DEBUG ----------------
func debug_report_storage() -> void:
	_ensure_dir_absolute(_get_users_dir())
	var abs_dir: String = _globalize(_get_users_dir())
	print("[AccountManager] 📂 user://Data/Users = ", abs_dir)
	var files: Array = _scan_all_user_jsons()
	print("[AccountManager] Fichiers détectés : ", files)

# Nettoie "tables_joined" : ne garde que des IDs (String).
# Ignore les fantômes de l'ancien format, ex: { "participants": { ... } }.
func clean_tables_joined(username: String) -> void:
	var d: Dictionary = get_user_data(username)
	if typeof(d) != TYPE_DICTIONARY or d.is_empty():
		return

	var in_arr: Array = d.get("tables_joined", [])
	var out_arr: Array = []

	for it in in_arr:
		var t := typeof(it)

		if t == TYPE_STRING:
			var s := str(it)
			if s != "":
				out_arr.append(s)

		elif t == TYPE_DICTIONARY:
			var di: Dictionary = it
			# cas usuels avec id
			if di.has("table_id"):
				out_arr.append(str(di["table_id"]))
			elif di.has("id"):
				out_arr.append(str(di["id"]))
			elif di.size() == 1:
				# format { "NomTable": "<id>" } -> garder la valeur si ce n'est pas un dict
				var vs: Array = di.values()
				if vs.size() == 1 and typeof(vs[0]) != TYPE_DICTIONARY:
					out_arr.append(str(vs[0]))
			# sinon: fantôme (ex: { "participants": {...} }) -> on ignore

		# autres types -> ignore

	d["tables_joined"] = out_arr
	users_data[username] = d
	save_user(username)


# Pratique : nettoie pour l'utilisateur courant.
func clean_current_user_tables_joined() -> void:
	var u := get_current_username()
	if u != "":
		clean_tables_joined(u)

# --- helper local pour récupérer TableManager autoload ---
# --- Helpers TableManager (UNIQUE) -------------------------------------------
func _am_find_table_manager() -> Node:
	var root := get_tree().get_root()
	if root != null:
		var tm := root.find_child("TableManager", false, false)
		if tm != null:
			return tm
	var cs := get_tree().get_current_scene()
	if cs != null:
		var local := cs.find_child("TableManager", true, false)
		if local != null:
			return local
	return null

# --- Purge 1 : fichiers de table inexistants ---------------------------------
func purge_current_user_invalid_tables() -> int:
	var uname := get_current_username()
	if uname == "":
		return 0
	var d := get_user_data(uname)
	if typeof(d) != TYPE_DICTIONARY or d.is_empty():
		return 0

	var tm := _am_find_table_manager()
	var joined: Array = d.get("tables_joined", [])
	var kept: Array = []
	var removed := 0

	for it in joined:
		var tid := ""
		if typeof(it) == TYPE_STRING:
			tid = str(it)
		elif typeof(it) == TYPE_DICTIONARY:
			var dd: Dictionary = it
			tid = str(dd.get("table_id", dd.get("id","")))
		if tid == "":
			continue

		var exists := true
		if tm != null and tm.has_method("table_exists"):
			exists = bool(tm.call("table_exists", tid))
		if exists:
			kept.append(tid)
		else:
			removed += 1

	d["tables_joined"] = kept
	users_data[uname] = d
	save_user(uname)
	return removed

# --- Purge 2 : non-membres (ni owner, ni invité, ni participant) -------------
func purge_current_user_non_member_tables() -> int:
	var uname := get_current_username()
	if uname == "":
		return 0
	var d := get_user_data(uname)
	if typeof(d) != TYPE_DICTIONARY or d.is_empty():
		return 0

	var tm := _am_find_table_manager()
	var joined: Array = d.get("tables_joined", [])
	var kept: Array = []
	var removed := 0

	for it in joined:
		var tid := ""
		if typeof(it) == TYPE_STRING:
			tid = str(it)
		elif typeof(it) == TYPE_DICTIONARY:
			var dd: Dictionary = it
			tid = str(dd.get("table_id", dd.get("id","")))
		if tid == "":
			continue

		var ok := true
		if tm != null and tm.has_method("is_member"):
			ok = bool(tm.call("is_member", tid, uname))
		if ok:
			kept.append(tid)
		else:
			removed += 1

	d["tables_joined"] = kept
	users_data[uname] = d
	save_user(uname)
	return removed


# --- extraction d'un id à partir d'une entrée "tables_joined" hétérogène ---
func _am_extract_tid_from_variant(it: Variant, tm: Node) -> String:
	# string -> ok
	if typeof(it) == TYPE_STRING:
		var s: String = str(it)
		return s

	# dictionnaire -> chercher id/uuid/...
	if typeof(it) == TYPE_DICTIONARY:
		var d: Dictionary = it
		# cas direct
		for k in ["table_id", "id", "uuid", "uid", "tid"]:
			if d.has(k):
				return str(d[k])

		# format { "NomTable": "<id>" }
		if d.size() == 1:
			var vs: Array = d.values()
			if vs.size() == 1 and typeof(vs[0]) == TYPE_STRING:
				return str(vs[0])
			# { "participants": { ... } } -> fantôme -> pas d'id
			if d.has("participants"):
				return ""

			# format { "NomTable": { ... } } -> tenter via le nom (clé unique)
			var ks: Array = d.keys()
			if ks.size() == 1 and typeof(ks[0]) == TYPE_STRING:
				var name_guess: String = str(ks[0])
				if tm != null and tm.has_method("find_table_id_by_name_exact"):
					return str(tm.call("find_table_id_by_name_exact", name_guess))

		# dict avec juste un nom -> tenter l'index par nom
		if d.has("table_name") or d.has("name"):
			var name2: String = str(d.get("table_name", d.get("name", "")))
			if name2 != "" and tm != null and tm.has_method("find_table_id_by_name_exact"):
				return str(tm.call("find_table_id_by_name_exact", name2))

	# sinon: rien
	return ""

# --- répare tables_joined d'un utilisateur : renvoie true si modifié ---
func repair_tables_joined(username: String) -> bool:
	var d: Dictionary = get_user_data(username)
	if typeof(d) != TYPE_DICTIONARY or d.is_empty():
		return false

	var tm: Node = _am_find_table_manager()
	var joined: Array = d.get("tables_joined", [])
	var out: Array = []
	var changed: bool = false

	for it in joined:
		var tid: String = _am_extract_tid_from_variant(it, tm)
		if tid == "":
			# rien trouvé -> on ne garde pas l'entrée
			changed = true
			continue
		if not out.has(tid):
			out.append(tid)
		# si différent du format d'origine -> on a migré
		if typeof(it) != TYPE_STRING or str(it) != tid:
			changed = true

	if changed:
		d["tables_joined"] = out
		users_data[username] = d
		save_user(username)

	return changed

# --- pratique : répare pour l'utilisateur courant ---
func repair_current_user_tables_joined() -> bool:
	var u: String = get_current_username()
	if u == "":
		return false
	return repair_tables_joined(u)

# --- PURGE FORTE: supprime toutes les entrées dont le fichier n’existe plus ---
func purge_invalid_tables(username: String) -> int:
	var d: Dictionary = get_user_data(username)
	if typeof(d) != TYPE_DICTIONARY or d.is_empty():
		return 0

	var tm: Node = _am_find_table_manager()
	var joined: Array = d.get("tables_joined", [])
	var out: Array = []
	var removed: int = 0

	for it in joined:
		var tid: String = _am_extract_tid_from_variant(it, tm)
		if tid == "":
			removed += 1
			continue
		var keep: bool = true
		if tm != null and tm.has_method("table_exists"):
			keep = bool(tm.call("table_exists", tid))
		if keep:
			if not out.has(tid):
				out.append(tid)
		else:
			removed += 1

	if removed > 0:
		d["tables_joined"] = out
		users_data[username] = d
		save_user(username)

	return removed

# === Invitations (à coller dans AccountManager.gd) ===

# --- Invitations (rétro-compatible) ---

func add_invitation(target_username: String, table_id: String = "") -> bool:
	if target_username == "":
		return false
	# fallback si table_id non fourni : prendre la table courante
	if table_id == "":
		var tm := _am_find_table_manager()
		if tm != null and tm.has_method("get_current_table_id"):
			table_id = str(tm.call("get_current_table_id"))
	if table_id == "":
		return false

	var d: Dictionary = get_user_data(target_username)
	if typeof(d) != TYPE_DICTIONARY or d.is_empty():
		load_user(target_username)
		d = get_user_data(target_username)
		if typeof(d) != TYPE_DICTIONARY or d.is_empty():
			return false

	var inv: Array = d.get("invitations", [])
	if not inv.has(table_id):
		inv.append(table_id)
		d["invitations"] = inv
		users_data[target_username] = d
		save_user(target_username)
	return true


func remove_invitation(target_username: String, table_id: String = "") -> bool:
	if target_username == "":
		return false
	if table_id == "":
		var tm := _am_find_table_manager()
		if tm != null and tm.has_method("get_current_table_id"):
			table_id = str(tm.call("get_current_table_id"))
	if table_id == "":
		return false

	var d: Dictionary = get_user_data(target_username)
	if typeof(d) != TYPE_DICTIONARY or d.is_empty():
		return false

	var inv: Array = d.get("invitations", [])
	if inv.has(table_id):
		inv.erase(table_id)
		d["invitations"] = inv
		users_data[target_username] = d
		save_user(target_username)
	return true


func get_friends(username: String) -> Array:
	var d: Dictionary = get_user_data(username)
	if typeof(d) == TYPE_DICTIONARY:
		return d.get("friends", [])
	return []
