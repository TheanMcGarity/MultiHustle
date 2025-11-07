extends "res://characters/states/ThrowState.gd"

var hit_opponents = []

var team:int = 0

const MH_HB_DATA:Script = preload("res://MultiHustle/hitbox/HitboxData.gd")

var grabbed_targets:Array = []
var primary_target = null
var previous_opponent = null

func _enter():
	_gather_initial_targets()
	_ensure_throw_target()
	_force_targets_grabbed()
	._enter()

func _frame_0_shared():
	_ensure_throw_target()
	._frame_0_shared()
	_force_targets_grabbed()
	_align_secondary_targets()

func _tick_shared():
	_ensure_throw_target()
	._tick_shared()
	_update_secondary_collisions()

func _tick_after():
	_ensure_throw_target()
	._tick_after()
	_align_secondary_targets()

func _exit():
	._exit()
	_restore_original_opponent()

func _on_hit_something(obj, hitbox):
	if obj and obj.is_in_group("Fighter") and (hitbox.throw or hitbox is ThrowBox):
		_add_grabbed_target(obj)
	._on_hit_something(obj, hitbox)

func _release():
	throw = false
	var pos = _prepare_release_position()
	if not _apply_release_to_targets(pos):
		_apply_release_to_target(host.opponent, pos)

	if screenshake_amount > 0 and screenshake_frames > 0 and not host.is_ghost:
		var camera = get_tree().get_nodes_in_group("Camera")[0]
		camera.bump(Vector2(), screenshake_amount, screenshake_frames / 60.0)
	if release_sfx and not ReplayManager.resimulating:
		release_sfx_player.play()
	if play_release_sfx_bass:
		host.play_sound("HitBass")

func _gather_initial_targets():
	grabbed_targets.clear()
	_merge_targets_from_game()
	if grabbed_targets.empty() and _is_valid_target(host.opponent):
		_add_grabbed_target(host.opponent, false)

func _merge_targets_from_game():
	for target in _lookup_targets_from_game():
		_add_grabbed_target(target)

func _prepare_release_position():
	if use_release_throw_pos:
		host.throw_pos_x = release_throw_pos_x
		host.throw_pos_y = release_throw_pos_y
	else:
		update_throw_position()
	var throw_pos = host.get_global_throw_pos()
	if throw_pos is Vector2:
		return throw_pos
	return Vector2(throw_pos.x, throw_pos.y)

func _apply_release_to_targets(pos: Vector2) -> bool:
	var applied = false
	for target in grabbed_targets:
		if _apply_release_to_target(target, pos):
			applied = true
	return applied

func _apply_release_to_target(target, pos: Vector2) -> bool:
	if not _is_valid_target(target):
		return false
	target.set_pos(pos.x, pos.y)
	target.update_facing()
	var throw_data = MH_HB_DATA.new(self)
	var original_opponent = target.opponent
	if target.opponent != host:
		target.opponent = host
	target.hit_by(throw_data, true)
	if target.current_state().state_name == "Grabbed":
		_force_post_release_state(target, throw_data)
	if target.opponent != original_opponent:
		target.opponent = original_opponent
	return true

func _force_post_release_state(target, hitbox):
	var next_state = grounded_hit_state if target.is_grounded() else aerial_hit_state
	target.colliding_with_opponent = false
	target.state_machine._change_state(next_state, {"hitbox": hitbox})

func _ensure_throw_target():
	_merge_targets_from_game()
	_prune_invalid_targets()
	var target = _pick_throw_target()
	if target and host.opponent != target:
		if previous_opponent == null:
			previous_opponent = host.opponent
		host.opponent = target
	primary_target = target
	if target:
		_add_grabbed_target(target)
	return target

func _pick_throw_target():
	var from_list = _first_valid_from(grabbed_targets)
	if from_list:
		return from_list
	var last_hit_target = _resolve_last_hit_target()
	if last_hit_target:
		return last_hit_target
	var cached_target = _resolve_cached_target()
	if cached_target:
		return cached_target
	if _is_valid_target(host.opponent) and host.opponent.current_state().state_name == "Grabbed":
		return host.opponent
	return null

func _resolve_last_hit_target():
	var obj_name = host.last_object_hit
	if obj_name is String and obj_name != "":
		var obj = host.obj_from_name(obj_name)
		if _is_valid_target(obj):
			_add_grabbed_target(obj)
			return obj
	return null

func _resolve_cached_target():
	for i in range(hit_opponents.size() - 1, -1, -1):
		var candidate = hit_opponents[i]
		if _is_valid_target(candidate):
			return candidate
		hit_opponents.remove(i)
	return null

func _add_grabbed_target(target, prioritize := true):
	if not _is_valid_target(target):
		return
	var already = grabbed_targets.has(target)
	if prioritize:
		if already:
			grabbed_targets.erase(target)
		grabbed_targets.insert(0, target)
	elif not already:
		grabbed_targets.append(target)
	if not already:
		_cache_hit_target(target)

func _cache_hit_target(target):
	if target and not hit_opponents.has(target):
		hit_opponents.append(target)

func _lookup_targets_from_game():
	var results = []
	var game = Network.game
	if game == null:
		return results
	if not game.players_getting_throwed.has(host.id):
		return results
	for target_id in game.players_getting_throwed[host.id]:
		if game.players.has(target_id):
			var player = game.players[target_id]
			if _is_valid_target(player):
				results.append(player)
	return results

func _force_targets_grabbed():
	if released:
		return
	for target in grabbed_targets:
		_force_single_target_grabbed(target)

func _force_single_target_grabbed(target):
	if not _is_valid_target(target):
		return
	if target.current_state().state_name != "Grabbed":
		target.change_state("Grabbed")
	target.colliding_with_opponent = false

func _align_secondary_targets():
	if released:
		return
	if grabbed_targets.empty():
		return
	var pos = host.get_global_throw_pos()
	for target in grabbed_targets:
		if target == host.opponent:
			continue
		_force_single_target_grabbed(target)
		target.set_pos(pos.x, pos.y)
		target.update_facing()

func _update_secondary_collisions():
	if released:
		return
	for target in grabbed_targets:
		if not _is_valid_target(target):
			continue
		target.colliding_with_opponent = false

func _prune_invalid_targets():
	for i in range(grabbed_targets.size() - 1, -1, -1):
		if not _is_valid_target(grabbed_targets[i]):
			grabbed_targets.remove(i)

func _first_valid_from(list):
	for entry in list:
		if _is_valid_target(entry):
			return entry
	return null

func _is_valid_target(target):
	return target \
		and is_instance_valid(target) \
		and not target.disabled \
		and target != host \
		and target.is_in_group("Fighter")

func _restore_original_opponent():
	if previous_opponent and host.opponent == primary_target:
		host.opponent = previous_opponent
	if Network.game and Network.game.players_getting_throwed.has(host.id):
		Network.game.players_getting_throwed.erase(host.id)
	previous_opponent = null
	primary_target = null
	grabbed_targets.clear()
	hit_opponents.clear()
