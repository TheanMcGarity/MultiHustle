extends "res://cl_port/Network.gd"

var char_loaded = {}

var sync_unlocks = {}

var lock_sync_unlocks = true

#Oh my god I hate this so much but it somehow works in testing dpajwojiosdfnikvkvknovnkonkoiopsja
var mh_file_path = "user://logs/mhlogs" + Time.get_time_string_from_unix_time(int(Time.get_unix_time_from_system()-(Time.get_ticks_msec()/1000))).replace(":", ".") + ".log"
var net_file_path = "user://logs/netlogs" + Time.get_time_string_from_unix_time(int(Time.get_unix_time_from_system()-(Time.get_ticks_msec()/1000))).replace(":", ".") + ".log"
var logger = load("res://MultiHustle/Logger.gd")

# Util Functions

"""
Quick note from CTAG: I use a lot of questionable logic to sorta ignore dead players while still sending them actions.
Dead players could get desynced and nobody would be the wiser besides the dead player.
If someone comes along who wants to fix this and make it properly ignore/remove/make them spectators, go ahead.
But I'm fairly confident that this should cover for now.
"""

func log_to_file(msg, net = false):
	print(msg)
	self.log(msg, net)

func log(msg, net = false):
	if net:
		logger.mh_log("[" + str(float(Time.get_ticks_msec())/1000.0) + "] " + msg, net_file_path)
	else:
		logger.mh_log("[" + str(float(Time.get_ticks_msec())/1000.0) + "] " + msg, mh_file_path)

func get_all_pairs(list):
	var idx = 0
	var listEnd = len(list)
	var listEndMinus = listEnd - 1
	var result = []
	for p1 in list:
		for p2 in list.slice(idx+1, listEnd):
			result.append([p1, p2])
		idx = idx + 1
		if (idx == listEndMinus):
			break
	return result

# Deprecated, base game always has it now.
func has_char_loader()->bool:
	return true

func ensure_script_override(object):
	#var property_list = object.get_property_list()
	#var properties = {}
	#for property in property_list:
	#	properties[property.name] = object.get(property.name)
	object.set_script(load(object.get_script().resource_path))
	#for property in properties.keys():
	#	object.set(property, properties[property])

func pid_to_usernamepid_to_username(player_id):
	if !is_instance_valid(game):
		return ""
	if SteamLobby.SPECTATING or !network_ids.has(player_id):
		return Global.current_game.match_data.user_data["p" + str(player_id)]
	if direct_connect:
		return players[network_ids[opponent_player_id(player_id)]]
	return players[network_ids[player_id]]

remotesync func end_turn_simulation(tick, player_id):
	Network.log("Ending turn simulation for player " + str(player_id) + " at tick " + str(tick))
	ticks[player_id] = tick
	turn_synced = true
	for v in ticks.values():
		if v != tick:
			turn_synced = false
	if turn_synced:
		send_ready = false
		emit_signal("player_turns_synced")

func submit_action(action, data, extra):
	if multiplayer_active:
		action_inputs[player_id]["action"] = action
		action_inputs[player_id]["data"] = data
		action_inputs[player_id]["extra"] = extra
		rpc_("multiplayer_turn_ready", player_id)
		Network.log("Action ready for player " + str(player_id))

func send_current_action():
	if last_action:
		rpc_("send_action", [last_action["action"], last_action["data"], last_action["extra"], player_id], "remote")

remotesync func multiplayer_turn_ready(id):
	turns_ready[id] = true
	Network.log("Turn ready for player " + str(id) + " | Turns ready: " + str(turns_ready))
	emit_signal("player_turn_ready", id)
	if steam:
		SteamLobby.spectator_turn_ready(id)
	for r in turns_ready.values():
		if !r:
			return
	action_submitted = true
	last_action = action_inputs[player_id]
	if is_instance_valid(game):
		last_action_sent_tick = game.current_tick
	send_current_action()
	possible_softlock = true
	emit_signal("turn_ready")
	turn_synced = false
	send_ready = true

func sync_tick():
	lock_sync_unlocks = false
	if not game.players[Network.player_id].game_over:
		Network.log("Telling opponent im ready")
		rpc_("mh_opponent_tick", player_id, "remote")

remote func mh_opponent_tick(id):
	Network.log("Opponent is ready")
	yield (get_tree(), "idle_frame")
	if is_instance_valid(game):
		game.network_simulate_readies[id] = true

func reset_action_inputs():
	turns_ready = {}
	action_inputs = {}
	for player in game.players.keys():
		if game.players[player].game_over:
			action_inputs[player] = {
				"action":"ContinueAuto", 
				"data":null, 
				"extra":null, 
			}
			turns_ready[player] = true
		else:
			action_inputs[player] = {
				"action":null, 
				"data":null, 
				"extra":null, 
			}
			turns_ready[player] = false

func sync_unlock_turn():
	Network.log("telling opponent we are actionable")
	
	rpc_("opponent_sync_check_unlock", null, "remote")

remote func opponent_sync_check_unlock():
	Network.log("Opponent is actionable")
	while is_instance_valid(game) and not game.game_paused:
		yield (get_tree(), "idle_frame")
	Network.log("So are we")
	sync_unlocks[player_id] = true
	rpc_("mh_opponent_sync_unlock", player_id, "remote")

remote func mh_opponent_sync_unlock(id):
	if !lock_sync_unlocks:
		Network.log("Opponent sync unlocked, ID: " + str(id))
		sync_unlocks[id] = true
		Network.log("Sync unlocks: " + str(sync_unlocks))
		var done = true
		for value in sync_unlocks.values():
			if !value:
				done = value
				break
		if done:
			for key in sync_unlocks.keys():
				if not game.players[key].game_over:
					sync_unlocks[key] = false
			can_open_action_buttons = true
			Network.log("Unlocking action buttons")
			emit_signal("force_open_action_buttons")
			lock_sync_unlocks = true

remote func player_disconnected(id):
	if not (id in players):
		return 
	if Global.css_open:
		if steam and game.players[id].hp > 0:
			game.players[id].forfeit()
	emit_signal("player_disconnected")
	if is_host():
		if players.has(id):
			emit_signal("game_error", "Player " + players[id] + " disconnected")
	else:
		unregister_player(id)
	if not steam:
		end_game()

# Teams

remotesync func on_team_change(team:int, username:String, player:int):
	var team_name
	var in_team = true
	match team:
		1:
			team_name = "Red"
		2:
			team_name = "Blue"
		3:
			team_name = "Yellow"
		4:
			team_name = "Green"
		_:
			team_name = "None"
			in_team = false
	
	print(username+"'s team changed to "+str(team_name))
	
	for team_key in teams:
		var team_dict = teams[team_key]
		if team_dict.has(player):
			team_living[team_key] -= 1
			team_dict.erase(player)
	
	if not(in_team):
		return
	

	team_living[team] += 1
	teams[team][player] = null
	 

# TODO: Move to game.gd
# Please do Dictionary<int, Dictionary<int, BaseChar>>
var teams: Dictionary = { 
	1: {},
	2: {},
	3: {},
	4: {},
	0: {}
}

func print_team_counts():
	pass
	#print("Team Player Counts")
	#print("Red team: " + str(teams[1].size()))
	#print("Blue team: " + str(teams[1].size()))
	#print("Yellow team: " + str(teams[1].size()))
	#print("Green team: " + str(teams[1].size()))
	
	#logger.mh_log("[" + str(float(Time.get_ticks_msec())/1000.0) + "] Team Player Counts", mh_file_path)
	#logger.mh_log("[" + str(float(Time.get_ticks_msec())/1000.0) + "] Red team: " + str(teams[1].size()), mh_file_path)
	#logger.mh_log("[" + str(float(Time.get_ticks_msec())/1000.0) + "] Blue team: " + str(teams[2].size()), mh_file_path)
	#logger.mh_log("[" + str(float(Time.get_ticks_msec())/1000.0) + "] Yellow team: " + str(teams[3].size()), mh_file_path)
	#logger.mh_log("[" + str(float(Time.get_ticks_msec())/1000.0) + "] Green team: " + str(teams[4].size()), mh_file_path)

func is_on_team(character, id:int):
	return teams[id].values().contains(character)

func get_team(character_id:int):
	for team in teams:
		if teams[team].has(character_id):
			return team
	
	return 0 # if the character is not in a team (FFA)

func get_color(id:int):
	print("Getting color for team "+str(id))
	match id:
		1:
			return "ff333d" # Red
		2:
			return "1d8df5" # Blue
		3:
			return "fcc603" # Yellow
		4:
			return "2ac91e" # Green
	
	return "ffffff" # White / None

func create_team_button(text:String, name:String, team:int, container:Node):
	var team_button = load("res://MultiHustle/Teams/TeamButton.tscn").instance()
	container.add_child(team_button)
	team_button.text = text
	team_button.name = name
	team_button.team_id = team
	return team_button

signal mh_chat_message_received(id, message, username)
remotesync func send_mh_chat_message(player_id, message, username):
	emit_signal("mh_chat_message_received", player_id, message, username)
	

signal mh_chat_message_received_preformatted(message)
remotesync func send_mh_chat_message_preformatted(message):
	emit_signal("mh_chat_message_received_preformatted", message)
	

# TODO: Make an actual system that isnt this
var temp_hitbox_teams = { }

func get_living_players_on_team(team:int):
	if (teams == null):
		print("null teams")
	if (teams[team] == null):
		print("null team")
	var living = teams[team].size()
	print(str(team)+" "+living)
	for player in teams[team]:
		living -= int(player.game_over)
	return living

remotesync func set_display_name(name:String, char_id:int):
	game.player_names_rich[char_id] = "[center][color=#"+get_color(get_team(char_id))+"]"+name+"[/color][/center]"
	game.player_names[char_id] = name
	
	name_init_count += 1
	if name_init_count > game.players.size():
		name_initialized = true
		
		main.uiselectors.reinit(main)
		main.hud_layer.reinit(main.hud_layer.p1index, main.hud_layer.p2index)
	else:
		name_initialized = false

remotesync func set_ghost_display_name(name:String, char_id:int):
	var label:RichTextLabel = game.ghost_game.players[char_id].display_name
	label.bbcode_text = "[center][color=#99"+get_color(get_team(char_id))+"]"+name+"[/color][/center]"
	
var team_living:Dictionary = {
	1:0,
	2:0,
	3:0,
	4:0,
	0:0
}


var name_init_count:int = 0
var name_initialized:bool = false

var main

func get_contains_string(option_button:OptionButton, string:String):
	for i in range(0, option_button.get_item_count()):
		if string in option_button.get_item_text(i):
			return true 
	return false

signal mh_resim_accepted(player)

signal mh_resim_requested(player)

remotesync func request_mh_resim(requester_id:int):
	resync_counter = 1
	resync_request_player_id = requester_id
	emit_signal("mh_resim_requested", requester_id)

var resync_request_player_id:int = 0



remotesync func accept_mh_resim(player_id:int):
	# todo: make better
	resync_counter += 1

	log_to_file("ACCEPT_MH_RESIM()->%d,%d)" % players.size, resync_counter)

	if (self.player_id == player_id):
		var team = Network.get_team(Network.player_id)
		var color = Network.get_color(team)
		var username = game.player_names[Network.player_id]
		var msg = ("[color=#%s]%s[/color] clicked RESYNC. %d/%d" % [color, username, resync_counter, players.size()]) 

		rpc_("send_mh_chat_message_preformatted", [msg])

	
	emit_signal("mh_resim_accepted", player_id)

func request_softlock_fix():
	if multiplayer_active:
		rpc_("request_mh_resim", [Network.player_id])

var resync_counter = 0

func accept_softlock_fix():
	if multiplayer_active:
		rpc_("accept_mh_resim", [Network.player_id])

remotesync func mh_resim(frames):
	if player_id != 1:
		ReplayManager.frames = frames
	log_to_file("MH Resync from %s" % game.player_names[resync_request_player_id])
	undo = true
	auto = true

	if is_instance_valid(game):
		game.undo(false)

	log_to_file("MH_RESIM()")
	resync_request_player_id = 0