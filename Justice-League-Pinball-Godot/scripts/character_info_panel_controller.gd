extends Control
class_name CharacterInfoPanelController

@export var carousel_name: String = "character_select"

# Optional: show this when locked (node path should be inside info_panel)
@export var locked_info_path: NodePath

# Gate rule:
# - Before initial pick (initial_character_selected == 0): show info for ANY highlighted character
# - After initial pick (== 1): show info only for completed characters, otherwise show locked_info
@export var gate_after_initial_pick: bool = true

@export var complete_values: Array[String] = ["complete", "completed"]

var _current_item: String = ""

func _ready() -> void:
	_hide_all_info()

	# Listen for MPF carousel highlight changes
	if MPF.server and MPF.server.item_highlighted:
		MPF.server.item_highlighted.connect(_on_item_highlighted)
	else:
		push_warning("CharacterInfoPanelController: MPF.server.item_highlighted not available yet.")

func _on_item_highlighted(payload: Dictionary) -> void:
	if payload.get("carousel") != carousel_name:
		return

	var item := str(payload.get("item", ""))
	if item == "":
		return

	_current_item = item
	_refresh()

func _refresh() -> void:
	_hide_all_info()

	# If you named your nodes like "batman_info", this finds them automatically.
	var info_node_name := "%s_info" % _current_item
	var info_node := get_node_or_null(info_node_name)

	# If the info node doesn’t exist, just show nothing.
	if info_node == null:
		_show_locked_info(false)
		return

	# If we’re not gating, always show the info node.
	if not gate_after_initial_pick:
		info_node.visible = true
		_show_locked_info(false)
		return

	# Gate logic based on initial_character_selected + <character>_mode_status
	var initial_selected := int(_get_player_var("initial_character_selected", 0))

	# Before initial pick: show any character info
	if initial_selected == 0:
		info_node.visible = true
		_show_locked_info(false)
		return

	# After initial pick: show only if completed
	var status_key := "%s_mode_status" % _current_item
	var status_val := str(_get_player_var(status_key, "incomplete")).strip_edges().to_lower()
	var is_complete := complete_values.has(status_val)

	if is_complete:
		info_node.visible = true
		_show_locked_info(false)
	else:
		info_node.visible = false
		_show_locked_info(true)

func _hide_all_info() -> void:
	# Hide all children that end with "_info"
	for child in get_children():
		if child is CanvasItem:
			var n := str(child.name)
			if n.ends_with("_info"):
				(child as CanvasItem).visible = false

	_show_locked_info(false)

func _show_locked_info(show: bool) -> void:
	if locked_info_path == NodePath():
		return
	var node := get_node_or_null(locked_info_path)
	if node and node is CanvasItem:
		(node as CanvasItem).visible = show

func _get_player_var(var_name: String, default_value):
	# Try several common GMC locations for current player vars
	if MPF.game and MPF.game.has_method("get_player_var"):
		var v = MPF.game.get_player_var(var_name)
		return v if v != null else default_value

	if MPF.game and ("player_vars" in MPF.game):
		var pv = MPF.game.player_vars
		if typeof(pv) == TYPE_DICTIONARY and pv.has(var_name):
			return pv[var_name]

	if MPF.game and ("current_player_vars" in MPF.game):
		var cpv = MPF.game.current_player_vars
		if typeof(cpv) == TYPE_DICTIONARY and cpv.has(var_name):
			return cpv[var_name]

	return default_value
