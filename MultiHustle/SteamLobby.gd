extends "res://SteamLobby.gd"

var OPPONENT_IDS = {}

var is_syncing = false
var sync_confirms = {}

signal start_game()



func _setup_game_vs(steam_id):
	Network.log_to_file("Normal game setup got called for some reason")
	host_game_vs_all()

func host_game_vs_all():
	Network.log_to_file("host_game_vs_all called")
	if SteamHustle.STEAM_ID != LOBBY_OWNER:
		Network.log_to_file("Only host can setup")
		return
	Network.log_to_file("registering players")
	REMATCHING_ID = 0
	OPPONENT_IDS.clear()
	OPPONENT_IDS[1] = SteamHustle.STEAM_ID
	var idx = 1
	Network.log_to_file("Lobby members: " + str(LOBBY_MEMBERS))
	for member in LOBBY_MEMBERS:
		#Exclude ourselves when counting lobby members
		if member.steam_id != SteamHustle.STEAM_ID:
			var steam_id = member.steam_id
			var status = Steam.getLobbyMemberData(LOBBY_ID, steam_id, "status")
			#if status == "ready":
			if status == "idle":
				idx += 1
				OPPONENT_IDS[idx] = steam_id
			else:
				# I should probably tweak this, but for now it does this
				Steam.closeP2PSessionWithUser(steam_id)
	Network.multiplayer_host = true
	#PLAYER_SIDE = 1
	#multihustle_start()
	# DEBUG Stuff
	multihustle_start()

func multihustle_start():
	Network.log_to_file("multihustle_start called")
	OPPONENT_ID = LOBBY_OWNER
	var data = {
		"multihustle_start":OPPONENT_IDS,
	}
	_send_P2P_Packet(0, data)
	send_sync(OPPONENT_IDS)

func send_sync(OPPONENT_IDS):
	Network.log_to_file("send_sync called")
	Network.log_to_file("opponent ids: " + str(OPPONENT_IDS))
	OPPONENT_ID = LOBBY_OWNER
	self.OPPONENT_IDS = OPPONENT_IDS
	for steam_id in sync_confirms.keys():
		if !OPPONENT_IDS.values().has(steam_id):
			sync_confirms.erase(steam_id)
	for steam_id in OPPONENT_IDS.values():
		if !sync_confirms.has(steam_id):
			sync_confirms[steam_id] = false
		Network.register_player_steam(steam_id)
	sync_confirms[SteamHustle.STEAM_ID] = true
	is_syncing = true
	var data = {
		"steam_id":SteamHustle.STEAM_ID,
		"sync_confirm":true
	}
	_send_P2P_Packet(0, data)

func sync_confirm(steam_id):
	Network.log_to_file("sync_confirm called")
	sync_confirms[steam_id] = true
	if is_syncing:
		for confirmation in sync_confirms.values():
			if !confirmation:
				return
		is_syncing = false
		sync_confirms.clear()
		_setup_game_vs_group(OPPONENT_IDS)

func _setup_game_vs_group(OPPONENT_IDS):
	Network.log_to_file("_setup_game_vs_group called")
	Network.log_to_file("opponent ids: " + str(OPPONENT_IDS))
	SETTINGS_LOCKED = true
	self.OPPONENT_IDS = OPPONENT_IDS
	Network.char_loaded.clear()
	for steam_id in OPPONENT_IDS.values():
		Network.char_loaded[steam_id] = false
	for index in OPPONENT_IDS.keys():
		var steam_id = OPPONENT_IDS[index]
		if steam_id == SteamHustle.STEAM_ID:
			PLAYER_SIDE = index
			Network.player_id = index
			Steam.setLobbyMemberData(SteamLobby.LOBBY_ID, "player_id", str(index))
			break
	Network.log_to_file("made it to character select")
	Network.network_ids = OPPONENT_IDS
	if SteamHustle.STEAM_ID == LOBBY_OWNER:
		rpc_("open_chara_select")
		Network.callv("open_chara_select", [])
	Steam.setLobbyMemberData(LOBBY_ID, "status", "fighting")
	Steam.setLobbyMemberData(LOBBY_ID, "opponent_id", str(OPPONENT_ID))

# All RPCs go to everyone
func rpc_(function_name:String, arg = null):
	if OPPONENT_ID != 0:
		var data = {
			"rpc_data":{
				"func":function_name, 
				"arg":arg
			}
		}
		_send_P2P_Packet(0, data)

func _receive_rpc(data):
	var a = false
	for id in OPPONENT_IDS.values():
		if id == p2p_packet_sender:
			a = true
	if !a:
		return
	var args = data.rpc_data.arg
	if args == null:
		args = []
	elif not args is Array:
		args = [args]
	Network.callv(data.rpc_data.func , args)

func _read_P2P_Packet_custom(readable):
	var sender = p2p_packet_sender
	if readable.has("_packetName"):
		match readable._packetName:
			"go_button_activate":
				Network.char_loaded[sender] = true
	._read_P2P_Packet_custom(readable)
	if readable.has("multihustle_start"):
		send_sync(readable.multihustle_start)
	if readable.has("sync_confirm"):
		sync_confirm(readable.steam_id)

# These are hardly needed, I'm putting these here so that I can log packets recieved and sent for debugging purposes
func _read_P2P_Packet():
	var PACKET_SIZE:int = Steam.getAvailableP2PPacketSize(0)

	if PACKET_SIZE > 0:
		var PACKET:Dictionary = Steam.readP2PPacket(PACKET_SIZE, 0)
		if PACKET.empty() or PACKET == null:
			Network.log_to_file("WARNING: read an empty packet with non-zero size!")
		var PACKET_SENDER:int = PACKET["steam_id_remote"]
		p2p_packet_sender = PACKET_SENDER
		var PACKET_CODE:PoolByteArray = PACKET["data"]
		var readable:Dictionary = bytes2var(PACKET_CODE)
		Network.log_to_file("P2P packet recieved! Sender: " + str(p2p_packet_sender) + " Data: " + str(readable), true)
		if readable.has("rpc_data"):
			_receive_rpc(readable)
		if readable.has("challenge_from"):
			_receive_challenge(readable.challenge_from, readable.match_settings)
		if readable.has("challenge_accepted"):
			if PACKET_SENDER == CHALLENGING_STEAM_ID:
				_on_opponent_challenge_accepted(readable.challenge_accepted)
		if readable.has("match_quit"):
			if PACKET_SENDER == OPPONENT_ID:
				if Network.rematch_menu:
					emit_signal("quit_on_rematch")
					Steam.setLobbyMemberData(LOBBY_ID, "status", "busy")
				if not is_instance_valid(Global.current_game):
					get_tree().reload_current_scene()
				Steam.setLobbyMemberData(LOBBY_ID, "opponent_id", "")
				Steam.setLobbyMemberData(LOBBY_ID, "character", "")
				Steam.setLobbyMemberData(LOBBY_ID, "player_id", "")
		if readable.has("match_settings_updated"):
			if PACKET_SENDER == LOBBY_OWNER:
				if SETTINGS_LOCKED:
					NEW_MATCH_SETTINGS = readable.match_settings_updated
				else :
					MATCH_SETTINGS = readable.match_settings_updated
				emit_signal("received_match_settings", readable.match_settings_updated)
		if readable.has("player_busy"):
			pass
		if readable.has("request_match_settings"):
			_send_P2P_Packet(readable.request_match_settings, {"match_settings_updated":MATCH_SETTINGS})
		if readable.has("message"):
			if readable.message == "handshake":
				emit_signal("handshake_made")
		
		if readable.has("challenge_cancelled"):
			if PACKET_SENDER == CHALLENGER_STEAM_ID:
				emit_signal("challenger_cancelled")
				CHALLENGER_STEAM_ID = 0
		if readable.has("challenge_declined"):
			_on_challenge_declined(readable.challenge_declined)
		if readable.has("spectate_accept"):
			if PACKET_SENDER == REQUESTING_TO_SPECTATE:
				REQUESTING_TO_SPECTATE = 0
				_on_spectate_request_accepted(readable)
		if readable.has("spectator_replay_update"):
			if PACKET_SENDER == SPECTATING_ID:
				_on_received_spectator_replay(readable.spectator_replay_update)
		if readable.has("request_spectate"):
			_on_received_spectate_request(readable.request_spectate)
		if readable.has("spectate_ended"):
			_remove_spectator(readable.spectate_ended)
		if readable.has("spectate_declined"):
			if PACKET_SENDER == REQUESTING_TO_SPECTATE:
				REQUESTING_TO_SPECTATE = 0
				_on_spectate_declined()
		if readable.has("spectator_sync_timers"):
			if PACKET_SENDER == SPECTATING_ID:
				_on_spectate_sync_timers(readable.spectator_sync_timers)
		if readable.has("spectator_turn_ready"):
			if PACKET_SENDER == SPECTATING_ID:
				_on_spectate_turn_ready(readable.spectator_turn_ready)
		if readable.has("spectator_tick_update"):
			if PACKET_SENDER == SPECTATING_ID:
				_on_spectate_tick_update(readable.spectator_tick_update)
		if readable.has("spectator_player_forfeit"):
			if PACKET_SENDER == SPECTATING_ID:
				Network.player_forfeit(readable.spectator_player_forfeit)
		if readable.has("validate_auth_session"):
			_validate_Auth_Session(readable.validate_auth_session, PACKET_SENDER)
		_read_P2P_Packet_custom(readable)

func _send_P2P_Packet(target:int, packet_data:Dictionary)->void :
	Network.log_to_file("Sending P2P packet! Data: " + str(packet_data), true)
	._send_P2P_Packet(target, packet_data)
