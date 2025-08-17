extends Node

signal network_ready_as_server()
signal network_ready_as_client()
signal invitation_received(invite: Dictionary)
signal table_ready(table_info: Dictionary)

var peer: ENetMultiplayerPeer
var is_server: bool = false

var account_manager: AccountManager
var table_manager: TableManager

func _ready() -> void:
	var a_v: Variant = find_child("AccountManager", true, false)
	if a_v and a_v is AccountManager:
		account_manager = a_v
	var t_v: Variant = find_child("TableManager", true, false)
	if t_v and t_v is TableManager:
		table_manager = t_v

# ----------------------------------------------------------------------------- #
#                                SERVEUR / CLIENT                               #
# ----------------------------------------------------------------------------- #
func host_server(port: int) -> bool:
	var p: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var err: int = p.create_server(port, 32)
	if err != OK:
		return false
	peer = p
	multiplayer.multiplayer_peer = peer
	is_server = true
	emit_signal("network_ready_as_server")
	return true

func connect_to_server(ip: String, port: int) -> bool:
	var p: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
	var err: int = p.create_client(ip, port)
	if err != OK:
		return false
	peer = p
	multiplayer.multiplayer_peer = peer
	is_server = false
	emit_signal("network_ready_as_client")
	return true

# ----------------------------------------------------------------------------- #
#                          PROTOCOLE D’INVITATION (MVP)                          #
# Règle : la table n’apparaît côté joueur que si la connexion ENet existe déjà. #
# ----------------------------------------------------------------------------- #

# payload:
# { "table_id": String, "table_name": String, "from_mj": String,
#   "role": String, "target_username": String }
@rpc("any_peer")
func rpc_invite_to_table(payload: Dictionary) -> void:
	# Appelé côté CLIENT (connexion déjà établie).
	if account_manager == null:
		return

	# Filtrer : traiter uniquement si je suis la cible.
	var me: String = account_manager.get_current_username()
	var target_v: Variant = payload.get("target_username", "")
	var target_username: String = String(target_v)
	if target_username != "" and target_username != me:
		return

	# 1) Persister l'invitation localement (fait apparaître dans "invitations").
	#    ⚠️ add_invitation attend (username: String, table_id: String)
	var table_id: String = String(payload.get("table_id", ""))

	# Fallback si table_id absent: prendre la table courante
	if table_id == "":
		var root: Node = get_tree().get_root()
		var tm: Node = root.find_child("TableManager", false, false)
		if tm != null and tm.has_method("get_current_table_id"):
			table_id = str(tm.call("get_current_table_id"))

	if target_username != "" and table_id != "":
		account_manager.add_invitation(target_username, table_id)
	else:
		push_warning("[Net] add_invitation: username/id manquants dans payload: " + str(payload))

	emit_signal("invitation_received", payload)

	# 2) MVP : auto-acceptation → demander au serveur de nous valider.
	var table_id_v: Variant = payload.get("table_id", "")
	var tid_for_server: String = String(table_id_v)
	if tid_for_server == "":
		return
	rpc_id(1, "rpc_accept_invite", tid_for_server, me)


@rpc("authority")
func rpc_accept_invite(table_id: String, username: String) -> void:
	# Appelé côté SERVEUR (MJ).
	if not is_server:
		return
	if table_manager == null:
		return

	var table_data: Dictionary = table_manager.get_table_info(table_id)
	if table_data.is_empty():
		return

	# Ajouter/mettre à jour l'invité dans la table (rôle "Player").
	if username != "":
		table_manager.add_or_update_invited_player(table_id, username, "Player")

	# Renvoyer l’info de la table au client pour finaliser l’apparition côté joueur.
	var sender_id: int = multiplayer.get_remote_sender_id()
	rpc_id(sender_id, "rpc_table_ready", table_data)

@rpc("any_peer")
func rpc_table_ready(table_info: Dictionary) -> void:
	# Côté CLIENT : marquer la table comme "jointe" → visible dans le menu.
	if account_manager != null:
		var tid_v: Variant = table_info.get("table_id", "")
		var table_id: String = String(tid_v)
		if table_id != "":
			account_manager.add_joined_table(table_id)
	emit_signal("table_ready", table_info)
