extends Node

#class_name MultiHustle_UISelectors

onready var selects = { # [Char, Opp] nodes
	1:[get_child(1).get_child(0),get_child(1).get_child(2)], # Left
	2:[get_child(1).get_child(1), get_child(1).get_child(3)] # Right
}
onready var local_char_select = selects[1][0]
var main

func Init(main):
	self.main = main
	var assigned_ids = []
	for id in selects.keys():
		var charSelect = selects[id][0]
		var oppSelect = selects[id][1]
		charSelect.parent = self
		oppSelect.parent = charSelect
		charSelect.opponentSelect = oppSelect
		if id == 1 && Network.multiplayer_active:
			# I don't like the number of things I'm doing here, a better way is probably most certainly possible.
			charSelect.Init(main, id)
			charSelect.SelectIndex(Network.player_id)
			oppSelect.on_ParentChanged()
			assigned_ids.append(Network.player_id)
			charSelect.hide()
		else:
			var new_id = 1
			while assigned_ids.has(new_id):
				new_id += 1
			# This too. I hate this.
			charSelect.Init(main, id)
			charSelect.SelectIndex(new_id)
			oppSelect.on_ParentChanged()
			assigned_ids.append(new_id)
	# TODO - Make this more expandable
	Network.log_to_file("Network Player ID: " + str(Network.player_id) + " | Assigned IDs: " + str(assigned_ids))
	selects[1][0].DeactivateChar(assigned_ids[1])
	selects[2][0].DeactivateChar(assigned_ids[0])

func reinit(main):
	self.main = main
	var assigned_ids = []
	for id in selects.keys():
		var charSelect = selects[id][0]
		var oppSelect = selects[id][1]

		if id == 1 and Network.multiplayer_active:
			charSelect.hide()

		charSelect.parent = self
		oppSelect.parent = charSelect
		charSelect.opponentSelect = oppSelect
		
		# This too. I hate this.
		charSelect.reinit(main, id)
		oppSelect.reinit(main, id)
	
	# TODO - Make this more expandable
	Network.log_to_file("Network Player ID: " + str(Network.player_id) + " | Assigned IDs: " + str(assigned_ids))
	selects[1][0].DeactivateChar(assigned_ids[1])
	selects[2][0].DeactivateChar(assigned_ids[0])

func DeactivateOther(selfId:int, charId:int):
	match(selfId):
		1:
			selects[2][0].DeactivateChar(charId)
		2:
			selects[1][0].DeactivateChar(charId)

func _process(delta):
	for pair in selects.values():
		for entry in pair:
			if Network.multiplayer_active && entry == local_char_select:
				continue
			if !entry.visible && main.game.game_paused:
				entry.ClearGameOver()
			entry.visible = main.game.game_paused

func GetAllActiveChars():
	var active_chars = []
	for pair in selects.values():
		var entry = pair[0]
		active_chars.append(entry.get_activeChar())
	return active_chars

func ResetGhosts():
	for index in main.game.players.keys():
		main.player_ghost_actions[index] = "Continue"
		main.player_ghost_datas[index] = null
		main.player_ghost_extras[index] = null
