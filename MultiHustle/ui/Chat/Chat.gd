extends "res://ui/Chat/Chat.gd"

func _ready():
	Network._whitelist_rpc_method("send_mh_chat_message")
	Network.connect("mh_chat_message_received", self, "on_mh_chat_message_received")
	print("MH Modded Chat ready!")

func process_command(message:String):
	var a = .process_command(message)
	if a: return a
	if not(Network.multiplayer_active and not SteamLobby.SPECTATING):
		if is_instance_valid(Global.current_game):
			# Technically checks player 1 and 2 twice, but I'll leave it just in case
			for v in Global.current_game.players.keys():
				if message.begins_with("/em" + str(v) + " "):
					var player = Global.current_game.get_player(v)
					if player:
						player.emote(message.split("/em" + str(v) + " ")[ - 1])
						return true
	return a

# Same as vanilla but with custom player name colors
func on_mh_chat_message_received(player_id: int, message: String, username: String):
	var team = Network.get_team(player_id)
	var color = Network.get_color(team)
	#if Network.game == null:
	#	color = "d931e8"
	print(color)


	var text = ProfanityFilter.filter(("<[color=#%s]" % [color]) + username + "[/color]>: " + message)
	var node = RichTextLabel.new()
	node.bbcode_enabled = true
	node.append_bbcode(text)
	node.fit_content_height = true
	if not (player_id == Network.player_id):
		play_chat_sound()
	$"%MessageContainer".call_deferred("add_child", node)
	if $"%MessageContainer".get_child_count() + 1 > MAX_LINES:
		$"%MessageContainer".call_deferred("remove_child", $"%MessageContainer".get_child(0))
	yield(get_tree(), "idle_frame")
	yield(get_tree(), "idle_frame")
	$"%ScrollContainer".scroll_vertical = 10000000000000000

func send_message(message):
	if process_command(message):
		return

	var steam_name = Steam.getFriendPersonaName(Steam.getSteamID())
	
	if "[img" in message and "ui/unknown2.png" in message:
		SteamHustle.unlock_achievement("ACH_JUMPSCARE")
	if not Network.multiplayer_active and not SteamLobby.SPECTATING:
		on_chat_message_received(1, message)
		return
	Network.rpc_("send_mh_chat_message", [Network.player_id, message, steam_name])
