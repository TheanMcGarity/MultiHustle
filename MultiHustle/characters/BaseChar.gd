extends "res://characters/BaseChar.gd"

var damage_sources = []

#var team_script = preload("res://MultiHustle/Teams/TeamsManager.gd")

const HB_SCRIPT:Script = preload("res://mechanics/Hitbox.gd")
const MH_HB_SCRIPT:Script = preload("res://MultiHustle/hitbox/Hitbox.gd")
const THROWBOX_SCRIPT:Script = preload("res://characters/ThrowBox.gd") # Check if compatible?

var team:int = 0

var display_name:RichTextLabel

var sent_name:bool = false

var set_name:bool = false



func init_team(player):
	pass

func init(pos = null):
	.init(pos)
	
	team = Network.get_team(id)
	
	
	Network.game.players[id].team = team
	
	Network.teams[team][id] = Network.game.players[id]


	var hitbox_nodes = get_nodes_with_script(Network.game.players[id], HB_SCRIPT)
	for hitbox in hitbox_nodes:
		if hitbox is THROWBOX_SCRIPT:
			continue
		elif hitbox is MH_HB_SCRIPT:
			hitbox.team = team
		else:
			#print("Failed to assign team; Hitbox nodes aren't compatible! - %s" % hitbox.get_path())
			continue

	if display_name == null:
		init_display_name()

# inner function please work please work please work please work please please :sob:
func get_inner_nodes_with_script(current_array, parent, script_type) -> void:
	for child in parent.get_children():
		if child.get_script() != null and child is script_type:
			current_array.append(child)
		get_inner_nodes_with_script(current_array, child, script_type)
func get_nodes_with_script(root: Node, script_type: Script) -> Array:
	var result = []
	
		
	for child in root.get_children():
		if child.get_script() != null and child is script_type:
			print("append")
			result.append(child)
		get_inner_nodes_with_script(result, child, script_type)

	return result
	
func change_state(state_name, state_data = null, enter = true, exit = true):
	.change_state(state_name, state_data, enter, exit)
	
	update_facing() # Facing fixes?

func hit_by(hitbox, force_hit = false):
	Network.log("player was hit!")
	
	if (hitbox == null):
		Network.log("NULL hitbox!")
		.hit_by(hitbox, force_hit)
		return

	var self_team = team
	
	var hb_team = hitbox.team #Network.temp_hitbox_teams[hitbox]
	
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

func init_display_name():
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

func tick():
	.tick()
	if not Network.game.match_data.has("selector_char_names"):
		if Network.multiplayer_active:
			# Basically
			# !sent_name && id == Network.player_id
			if not sent_name and id == Network.player_id:
				Network.rpc_("set_display_name", [Steam.getPersonaName(), Network.player_id])
				sent_name = true
		else:
			if not sent_name:
				singleplayer_set_display_name()
		
	if display_name == null:
		init_display_name()

	
	var name := ""

	if (Network.game.player_names_rich.has(id)):
		name = Network.game.player_names_rich[id]
	
	if name is String and "center" in name and not set_name:
		set_name_text(name)
		set_name = true

func set_name_text(txt):
	if (is_ghost):
		var main_player = Network.game.players[id]
		if (is_instance_valid(main_player)):
			if main_player.display_name == null:
				main_player.init_display_name()

			main_player.display_name.bbcode_text = txt
				
	display_name.bbcode_text = txt


# Vanilla function but with opponent select sync
func tick_before():
	if queued_action == "Forfeit":
		if forfeit:
			queued_action = "Continue"
	if clashing:
		if is_grounded():
			change_state("Wait")
		else:
			change_state("Fall")
		clashing = false
	turn_end_effects()
	dummy_interruptable = false
	clean_parried_hitboxes()
	busy_interrupt = false

	update_grounded()
	if ReplayManager.playback:
		var input = get_playback_input()
		if input:
			opponent = Network.game.players[input["opp"]]
			queued_action = input["action"]
			queued_data = input["data"]
			queued_extra = input["extra"]
			
			if queued_action == "Forfeit":

				forfeit = true
				Global.current_game.forfeit(id)
	else:
		if queued_action:
			actions += 1

			if queued_action == "Undo":
				queued_action = null
				queued_data = null
				return

			if queued_action == "Forfeit":
				forfeit = true

			if not is_ghost:
				ReplayManager.frames[id][current_tick] = {
					"action": queued_action, 
					"data": queued_data, 
					"extra": queued_extra, 
					"opp": opponent.id
				}
	previous_input = last_input.duplicate(true)
	feinted_last = feinting
	var pressed_feint = false
	if refresh_prediction:
		refresh_prediction = false



	blocked_last_turn = false
	if use_buffer:
		if buffered_input.has("action"):
			queued_action = buffered_input.action
		if buffered_input.has("data"):
			queued_data = buffered_input.data
		if buffered_input.has("extra"):
			queued_extra = buffered_input.extra
		use_buffer = false
		used_buffer = true
		clear_buffer()
	if queued_extra:
		turn_frames = 0
		opponent.turn_frames = 0
		last_input["extra"] = queued_extra
		process_extra(queued_extra)
		pressed_feint = feinting
	if queued_action:
		process_action(queued_action)
		turn_frames = 0
		opponent.turn_frames = 0
		turn_start_effects()
		counterhit_this_turn = false
		guard_broken_this_turn = false
		if current_state() is CounterAttack:
			current_state().bracing = false
		if brace_effect_applied_yet:
			brace_effect_applied_yet = false
			braced_attack = false
		last_input["action"] = queued_action
		last_input["data"] = queued_data
		feint_parriable = false
		if queued_action == "Continue":
			var current_state_name = current_state().name
			if process_continue():
				pass
			elif current_state().get_hold_restart() != "" and current_state().interruptible_on_opponent_turn:
				queued_action = current_state().get_hold_restart()
				queued_data = current_state().data
			elif current_state_name in HOLD_RESTARTS and current_state().interruptible_on_opponent_turn:
				queued_action = current_state_name
				queued_data = current_state().data
			elif current_state_name in HOLD_FORCE_STATES and current_state().interruptible_on_opponent_turn:
				queued_action = HOLD_FORCE_STATES[current_state_name]
			elif (was_my_turn or (current_state().interruptible_on_opponent_turn and current_state().next_state_on_hold_on_opponent_turn)\
			or (current_state().hit_fighter and combo_count == 0)) and not feinting and current_state().next_state_on_hold:
				queued_action = current_state().fallback_state
			if feinted_last:
				feint_parriable = true
			if not current_state().interruptible_on_opponent_turn:
				current_state().on_continue()

		if current_state().interruptible_on_opponent_turn:
			current_state().opponent_turn_interrupt()



		if queued_action in state_machine.states_map:

			if feinted_last:
				var particle_pos = get_hurtbox_center_float()
				spawn_particle_effect(preload("res://fx/FeintEffect.tscn"), particle_pos)
				
			state_machine._change_state(queued_action, queued_data)
			if not current_state().is_hurt_state:
				if not last_turn_block:
					hitlag_ticks = 0
				last_turn_block = false
			if not (current_state() is ParryState):
				if blocked_hitbox_plus_frames > 0:
					hitlag_ticks += blocked_hitbox_plus_frames
					blocked_hitbox_plus_frames = 0
			if pressed_feint:
				feinting = true
				current_state().feinting = true
		current_state().feinted_last = feinted_last
	queued_action = null
	queued_data = null
	queued_extra = null
	was_my_turn = false
	lowest_tick = current_state().current_real_tick

func singleplayer_set_display_name():
	Network.game.player_names_rich[id] = "[center][color=#"+Network.get_color(Network.get_team(id))+"]"+("p%d" % id)+"[/color][/center]"
	Network.game.player_names[id] = ("p%d" % id)
