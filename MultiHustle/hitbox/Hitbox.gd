extends "res://mechanics/Hitbox.gd"

const MH_HITBOX_DATA = preload("res://MultiHustle/hitbox/HitboxData.gd")

export (int) var team = 0


func to_data():
	Network.log("to_data -> team="+str(team))
	var data = MH_HITBOX_DATA.new(self)
	data.team = team
	Network.log("to_data -> data.team="+str(data.team))
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
