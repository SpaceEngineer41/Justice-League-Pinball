extends Control
class_name MPFCharacterUnlocks

## Attach this to your Grid node (or the parent that contains the character tile nodes).
## It will show/hide each tile's "*_locked_overlay" and "*_locked_label" based on
## player variables like "batman_mode_status".
##
## UNLOCK RULE:
## - if <character>_mode_status is "complete" (or "completed"), tile is unlocked
## - otherwise tile is locked

@export var carousel_name: String = "character_select"
@export var unlocked_values: Array[String] = ["complete", "completed"]

# If you made a shared shader/material and want to toggle it via a shader param,
# set this to the uniform name you use (leave empty to do nothing).
@export var locked_shader_uniform_name: String = ""  # e.g. "locked"

func _ready() -> void:
	# Initial refresh (in case vars already exist when the slide appears)
	_refresh_all_tiles()

	# Listen for MPF item_highlighted (optional sanity check / not required for unlocks)
	if MPF.server and MPF.server.item_highlighted:
		MPF.server.item_highlighted.connect(_on_item_highlighted)

	# Listen for player variable changes
	# (Signal name depends on MPF-GMC version; try these in order.)
	if MPF.server:
		if MPF.server.has_signal("player_variable_changed"):
			MPF.server.player_variable_changed.connect(_on_player_variable_changed)
		elif MPF.server.has_signal("variable_changed"):
			MPF.server.variable_changed.connect(_on_any_variable_changed)

func _on_item_highlighted(payload: Dictionary) -> void:
	# Not needed for unlocks, but handy for debugging
	if payload.get("carousel") != carousel_name:
		return

func _on_player_variable_changed(payload: Dictionary) -> void:
	# Expected payload usually contains: name / value / player_num
	var var_name := str(payload.get("name", ""))
	if var_name.ends_with("_mode_status"):
		_update_one_tile_from_var(var_name, payload.get("value"))

func _on_any_variable_changed(payload: Dictionary) -> void:
	# Fallback for versions that emit a generic signal
	var var_name := str(payload.get("name", ""))
	if var_name.ends_with("_mode_status"):
		_update_one_tile_from_var(var_name, payload.get("value"))

func _refresh_all_tiles() -> void:
	# Try to read current player vars if available; if not, we still update as changes come in.
	var vars := {}
	if "game" in MPF and MPF.game:
		# Different MPF-GMC versions expose player vars differently, so we try a few.
		if MPF.game.has_method("get_player_vars"):
			vars = MPF.game.get_player_vars()
		elif "player_vars" in MPF.game:
			vars = MPF.game.player_vars
		elif "players" in MPF.game and MPF.game.players and MPF.game.players.size() > 0:
			var p = MPF.game.players[0]
			if "vars" in p:
				vars = p.vars

	# Update each child tile from the vars dict (if we got one)
	for tile in get_children():
		if tile == null:
			continue
		var character := str(tile.name)
		var key := "%s_mode_status" % character
		if vars.has(key):
			_apply_locked_state(character, vars[key])
		else:
			# Default to locked until we know otherwise
			_apply_locked_state(character, "incomplete")

func _update_one_tile_from_var(var_name: String, value) -> void:
	# "batman_mode_status" -> "batman"
	var character := var_name.replace("_mode_status", "")
	_apply_locked_state(character, value)

func _apply_locked_state(character: String, value) -> void:
	var is_unlocked := unlocked_values.has(str(value).to_lower())
	var tile := get_node_or_null(character)
	if tile == null:
		# Tile node might be nested; try find by name
		tile = _find_child_by_name(self, character)
	if tile == null:
		return

	var overlay := tile.get_node_or_null("%s_locked_overlay" % character)
	if overlay == null:
		overlay = _find_child_by_name(tile, "%s_locked_overlay" % character)

	var label := tile.get_node_or_null("%s_locked_label" % character)
	if label == null:
		label = _find_child_by_name(tile, "%s_locked_label" % character)

	# Sprite is usually named the same as the character (batman/flash/etc)
	var sprite := tile.get_node_or_null(character)
	if sprite == null:
		sprite = _find_child_by_name(tile, character)

	# Locked means overlay+label visible. Unlocked means hidden.
	if overlay:
		overlay.visible = not is_unlocked
	if label:
		label.visible = not is_unlocked

	# Optional: if you used a shared shader and want to toggle grayscale via uniform
	if locked_shader_uniform_name != "" and sprite and "material" in sprite and sprite.material:
		if sprite.material is ShaderMaterial:
			(sprite.material as ShaderMaterial).set_shader_parameter(locked_shader_uniform_name, not is_unlocked)

func _find_child_by_name(root: Node, target_name: String) -> Node:
	for c in root.get_children():
		if c.name == target_name:
			return c
		var found := _find_child_by_name(c, target_name)
		if found:
			return found
	return null
