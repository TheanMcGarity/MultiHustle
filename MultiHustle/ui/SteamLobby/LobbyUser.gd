extends "res://ui/SteamLobby/LobbyUser.gd"

signal start_game_pressed()

func init(member):
	.init(member)
	var button = $"%ChallengeButton"
	if !button.disabled && button.visible:
		button.disabled = true
	elif Steam.getLobbyOwner(SteamLobby.LOBBY_ID) == SteamHustle.STEAM_ID:
		button.show()
		button.text = "Start Game"

func on_challenge_pressed():
	emit_signal("start_game_pressed")
	SteamLobby.host_game_vs_all()

func _loaded_Avatar(id:int, size:int, buffer:PoolByteArray)->void :
	if id != member.steam_id:
		return 
		
	var AVATAR = Image.new()
	var AVATAR_TEXTURE:ImageTexture = ImageTexture.new()
	AVATAR.create_from_data(size, size, false, Image.FORMAT_RGBA8, buffer)
		
	AVATAR_TEXTURE.create_from_image(AVATAR)
		
	$"%AvatarIcon".set_texture(AVATAR_TEXTURE)
	emit_signal("avatar_loaded")
