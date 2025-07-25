extends "res://characters/BaseChar.gd"

var damage_sources = []

var team_script = preload("res://MultiHustle/Teams/TeamsManager.gd")

var HB_SCRIPT:Script = preload("res://mechanics/Hitbox.gd")

var team:int = 0

var display_name:RichTextLabel

#var set_name:bool = false

func init_team(player):
	pass

func init(pos = null):
	.init(pos)
	
	team = Network.get_team(id)
	
	
	Network.game.players[id].team = team
	
	Network.teams[team][id] = Network.game.players[id]


	var hitbox_nodes = get_nodes_with_script(Network.game.players[id], HB_SCRIPT)
	for hitbox in hitbox_nodes:
		hitbox.team = team
	
	if (is_ghost):
		display_name = load("res://MultiHustle/Teams/TeamDisplayGhost.tscn").instance()
		add_child(display_name)
		if Network.game.player_names_rich.has(id):
			var username = Network.game.player_names_rich[id]

			if not username is String:
				return
			# any rich text stuff
			if "[" in username:
				display_name.bbcode_text = username 
		return
	
	display_name = load("res://MultiHustle/Teams/TeamDisplay.tscn").instance()
	add_child(display_name)
	if Network.game.player_names_rich.has(id):
		display_name.bbcode_text = Network.game.player_names_rich[id]

# inner function please work please work please work please work please please :sob:
func get_inner_nodes_with_script(current_array, parent, script_type):
	for child in parent.get_children():
		if child.get_script() != null and child is script_type:
			print("append")
			current_array.append(child)
		get_inner_nodes_with_script(current_array, child, script_type)
func get_nodes_with_script(root: Node, script_type: Script):
	var result = []
	
		
	for child in root.get_children():
		if child.get_script() != null and child is script_type:
			print("append")
			result.append(child)
		get_inner_nodes_with_script(result, child, script_type)

	return result
	



func hit_by(hitbox, force_hit = false):
	Network.log("player was hit!")
	
	if (hitbox == null):
		Network.log("NULL hitbox!")
		.hit_by(hitbox, force_hit)
		return

	var self_team = team
	var hb_team = Network.temp_hitbox_teams[hitbox]
	
	Network.log("hit_by -> self_team="+str(self_team)+", hb_team="+str(hb_team))
	
	if (self_team == 0):	
		Network.log("FFA Hit")
		.hit_by(hitbox, force_hit)
		return
	if (hb_team == 0):	
		Network.log("FFA Hit")
		.hit_by(hitbox, force_hit)
		return
	
	if self_team != hb_team:
		Network.log("Non Teammate Hit")
		.hit_by(hitbox, force_hit)
		return
	
	Network.log("Friendly Fire Hit")

func spawn_object(projectile: PackedScene, pos_x: int, pos_y: int, relative = true, data = null, local = true):
	var obj = projectile.instance()
	obj.creator_name = obj_name

	obj.objs_map = objs_map
	obj.is_ghost = is_ghost
	obj.obj_name = str(objs_map.size() + 1)
	obj.spawn_data = data
	obj.stage_width = stage_width

	var pos = get_pos()
	if local:
		obj.set_pos(pos.x + pos_x * (get_facing_int() if relative else 1), pos.y + pos_y)
	else:
		obj.set_pos(pos_x, pos_y)
	obj.set_facing(get_facing_int())
	obj.id = id
	
	var hitbox_nodes = get_nodes_with_script(obj, HB_SCRIPT)
	for hitbox in hitbox_nodes:
		hitbox.team = team
	
	obj.obj_name = str(objs_map.size() + 1)
	emit_signal("object_spawned", obj)
	return obj

func tick():
	.tick()
	var name = Network.game.player_names_rich[id]
		
	if name is String and "center" in name:
		display_name.bbcode_text = name
		#set_name = true
