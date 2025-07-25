extends "res://ReplayManager.gd"

func init():
	.init()
	var mh_data = {}
	frames["MultiHustle"] = mh_data
	for index in Global.current_game.players:
		frames[index] = {}
		frames["emotes"][index] = {}
		mh_data[index] = {}
	

func frame_ids():
	var ids = .frame_ids()
	for id in frames:
		if id is int and !ids.has(id):
			ids.append(id)
	return ids

func undo(cut = true):
	if resimulating:
		return 
	var last_frame = 0
	var last_id = 1
	for id in frame_ids():
		for frame in frames[id].keys():
			if frame > last_frame:
				last_frame = frame
				last_id = id
	if cut:
		for id in frame_ids():
			frames[id].erase(last_frame)
	resimulating = true
	playback = true
	resim_tick = (last_frame - 2) if cut else - 1

func generate_mp_replay_name(p1: String, p2: String):
	var v_name = "MH_"
	for player in Network.game.player_names:
		var p_name = Network.game.player_names[player]
		v_name += p_name.substr(0, 3)
		v_name += "-vs-"
	return v_name.substr(0, len(v_name) - 4) + "_" + generate_replay_name()

func save_replay(match_data: Dictionary, file_name = "", autosave = false):
	
	var team_data = {}
	
	for player in Network.game.players:
		team_data[player] = Network.get_team(player)

	match_data["teams"] = team_data
	match_data["display_names"] = Network.game.player_names_rich

	.save_replay(match_data, file_name, autosave)