extends "res://mechanics/HitboxData.gd"

var owner_team = 0

func _init(state:Hitbox):
	.init(state)
	owner_team = state.owner_team
