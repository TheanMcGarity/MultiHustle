extends "res://mechanics/Hitbox.gd"

export (int) var team = 0


func to_data():
	Network.log("to_data -> team="+str(team))
	var data = HitboxData.new(self)
	Network.temp_hitbox_teams[data] = team
	return data

func hit(obj):
	if not obj.get("opponent") == null:
		var opponentTemp = obj.opponent
		if host.is_in_group("Fighter"):
			obj.opponent = host
		elif host.fighter_owner:
			obj.opponent = host.fighter_owner
		.hit(obj)
		obj.opponent = opponentTemp
	else:
		.hit(obj)
