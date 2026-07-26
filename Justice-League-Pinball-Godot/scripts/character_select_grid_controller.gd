extends Control
class_name CharacterSelectGridController

signal character_selected(character_id: String)

@export_category("Highlight")
@export var highlight_node_name: String = "highlight"

@export_category("Selection Rules")
@export var only_select_completed: bool = true
@export var auto_fallback_to_all_when_completed_empty: bool = true
@export var fallback_to_first_selectable_when_mpf_current_blank: bool = true

@export_category("Completion Var Nodes")
@export var status_node_suffix: String = "_status"
@export var completion_complete_string: String = "complete"

@export_category("Input Actions")
@export var action_next_1: String = "ui_right"
@export var action_next_2: String = "ui_down"
@export var action_prev_1: String = "ui_left"
@export var action_prev_2: String = "ui_up"
@export var action_select: String = "ui_accept"

@export_category("MPF Event Names")
@export var carousel_name: String = "character_select"
@export var mpf_event_attempt_next: String = "character_select_attempt_next"
@export var mpf_event_attempt_prev: String = "character_select_attempt_prev"
@export var mpf_event_attempt_select: String = "character_select_attempt_select"

@export_category("MPF Current Item Var")
@export var mpf_current_item_var_candidates: PackedStringArray = PackedStringArray([
	"character_select_current_item",
	"player_character_select_current_item",
	"current_item",
	"player_current_item"
])

@export_category("Sync")
@export var poll_interval_sec: float = 0.25

@export_category("Debug")
@export var debug_print: bool = true

var _tiles: Array[Control] = []
var _highlights: Dictionary = {}
var _status_nodes: Dictionary = {}
var _selectable: PackedStringArray = PackedStringArray()
var _current_id: String = ""
var _poll_timer: Timer = null
var _skip_guard: int = 0
var _received_mpf_highlight_signal: bool = false

const _SKIP_GUARD_MAX: int = 40


func get_current_id() -> String:
	return _current_id


func _ready() -> void:
	print("[CharacterSelectGridController] READY on node: ", get_path())

	_build_tiles()
	_refresh_selectable()
	_hide_all_highlights()

	call_deferred("_connect_mpf_signals")
	call_deferred("_sync_from_mpf")

	_poll_timer = Timer.new()
	_poll_timer.wait_time = poll_interval_sec
	_poll_timer.one_shot = false
	_poll_timer.autostart = true
	add_child(_poll_timer)
	_poll_timer.timeout.connect(_sync_from_mpf)


func _connect_mpf_signals() -> void:
	if typeof(MPF) == TYPE_NIL or not MPF:
		print("[CharacterSelectGridController] MPF not available yet.")
		return

	if not ("server" in MPF) or not MPF.server:
		print("[CharacterSelectGridController] MPF.server not available yet.")
		return

	var server: Variant = MPF.server

	if server is Object:
		if "item_highlighted" in server:
			var sig: Signal = server.item_highlighted

			if not sig.is_connected(_on_mpf_item_highlighted):
				sig.connect(_on_mpf_item_highlighted)

			print("[CharacterSelectGridController] Connected to MPF item_highlighted signal.")
		else:
			print("[CharacterSelectGridController] MPF.server.item_highlighted signal not found.")


func _on_mpf_item_highlighted(payload: Dictionary) -> void:
	if debug_print:
		print("[CharacterSelectGridController] item_highlighted payload: ", payload)

	var payload_carousel := str(payload.get("carousel", ""))

	if payload_carousel != "" and payload_carousel != carousel_name:
		return

	var item := str(payload.get("item", "")).strip_edges().to_lower()

	if item == "":
		return

	_received_mpf_highlight_signal = true
	_refresh_selectable()

	if only_select_completed and _selectable.size() > 0 and not _selectable.has(item):
		if debug_print:
			print("[CharacterSelectGridController] Signal item is locked/incomplete, ignoring: ", item)
		return

	_set_current(item)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(action_next_1) or event.is_action_pressed(action_next_2):
		_post_mpf_event(mpf_event_attempt_next)
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed(action_prev_1) or event.is_action_pressed(action_prev_2):
		_post_mpf_event(mpf_event_attempt_prev)
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed(action_select):
		_post_mpf_event(mpf_event_attempt_select)
		get_viewport().set_input_as_handled()
		return


func _build_tiles() -> void:
	_tiles.clear()
	_highlights.clear()
	_status_nodes.clear()

	for child in get_children():
		if child is Control:
			var tile: Control = child
			var id: String = str(tile.name).to_lower()
			_tiles.append(tile)

			var hl_node: Node = tile.get_node_or_null(NodePath(highlight_node_name))

			if hl_node != null and hl_node is CanvasItem:
				_highlights[id] = hl_node

				var highlight := hl_node as CanvasItem
				highlight.visible = false
				highlight.z_index = 100
				highlight.show_behind_parent = false

				if highlight is Control:
					var h_control := highlight as Control
					h_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
			else:
				print("[CharacterSelectGridController] Missing highlight for: ", id)

			var status_name: String = id + status_node_suffix
			var st: Node = tile.get_node_or_null(NodePath(status_name))

			if st != null:
				_status_nodes[id] = st

	var ids: PackedStringArray = PackedStringArray()

	for t in _tiles:
		ids.append(str(t.name).to_lower())

	print("[CharacterSelectGridController] tiles found: ", ids)
	print("[CharacterSelectGridController] highlights found: ", _highlights.keys())


func _hide_all_highlights() -> void:
	for k in _highlights.keys():
		var n_any: Variant = _highlights[k]

		if n_any != null and n_any is CanvasItem:
			(n_any as CanvasItem).visible = false


func _apply_highlight(id: String) -> void:
	_hide_all_highlights()

	var n_any: Variant = _highlights.get(id, null)

	if n_any != null and n_any is CanvasItem:
		var highlight := n_any as CanvasItem
		highlight.visible = true
		highlight.z_index = 100
		highlight.show_behind_parent = false

		if highlight is Control:
			var h_control := highlight as Control
			h_control.mouse_filter = Control.MOUSE_FILTER_IGNORE

		print("[CharacterSelectGridController] highlight ON for: ", id)
	else:
		print("[CharacterSelectGridController] Could not apply highlight. Missing highlight for: ", id)


func _refresh_selectable() -> void:
	var selectable: PackedStringArray = PackedStringArray()

	for tile in _tiles:
		var id: String = str(tile.name).to_lower()

		if not only_select_completed:
			selectable.append(id)
		else:
			if _is_completed(id):
				selectable.append(id)

	if only_select_completed and selectable.size() == 0 and auto_fallback_to_all_when_completed_empty:
		for tile in _tiles:
			selectable.append(str(tile.name).to_lower())

	_selectable = selectable

	if debug_print:
		print("[CharacterSelectGridController] selectable: ", _selectable)


func _is_completed(character_id: String) -> bool:
	var complete_text := completion_complete_string.strip_edges().to_lower()

	var st_any: Variant = _status_nodes.get(character_id, null)

	if st_any != null and st_any is Node:
		var st: Node = st_any as Node
		var v: Variant = null

		if st.has_method("get_value"):
			v = st.call("get_value")
		elif "value" in st:
			v = st.get("value")
		elif st is Label:
			v = (st as Label).text

		if typeof(v) == TYPE_STRING:
			return String(v).strip_edges().to_lower() == complete_text

	var key: String = character_id + "_mode_status"
	var v2: Variant = _get_player_var(key, "")

	if typeof(v2) == TYPE_STRING:
		return String(v2).strip_edges().to_lower() == complete_text

	return false


func _sync_from_mpf() -> void:
	_refresh_selectable()

	var mpf_id: String = _get_current_item_from_mpf()

	if debug_print and mpf_id != "":
		print("[CharacterSelectGridController] MPF current item read as: ", mpf_id)

	if mpf_id == "":
		# Only use fallback if we do not already have a current selection.
		# This prevents the controller from constantly forcing Wonder Woman.
		if _current_id == "" and fallback_to_first_selectable_when_mpf_current_blank and _selectable.size() > 0:
			var fallback_id := String(_selectable[0])

			if debug_print:
				print("[CharacterSelectGridController] MPF current item blank. Initial fallback to: ", fallback_id)

			_set_current(fallback_id)

		return

	if only_select_completed and _selectable.size() > 0 and not _selectable.has(mpf_id):
		_skip_guard += 1

		if _skip_guard <= _SKIP_GUARD_MAX:
			if debug_print:
				print("[CharacterSelectGridController] MPF on incomplete ", mpf_id, " -> nudging next")

			_post_mpf_event(mpf_event_attempt_next)

		return

	_skip_guard = 0
	_set_current(mpf_id)


func _set_current(id: String) -> void:
	if id == "":
		return

	id = id.strip_edges().to_lower()

	if _current_id == id:
		_apply_highlight(_current_id)
		return

	_current_id = id
	_apply_highlight(_current_id)
	character_selected.emit(_current_id)

	if debug_print:
		print("[CharacterSelectGridController] selected: ", _current_id)


func _get_current_item_from_mpf() -> String:
	for k in mpf_current_item_var_candidates:
		var key := String(k)
		var v: Variant = _get_player_var(key, "")

		if typeof(v) == TYPE_STRING:
			var s: String = String(v).strip_edges().to_lower()

			if s != "":
				return s

	return ""


func _post_mpf_event(event_name: String) -> void:
	if event_name == "":
		return

	if typeof(MPF) == TYPE_NIL or not MPF:
		return

	if MPF.has_method("post_event"):
		MPF.call("post_event", event_name)
		return

	if MPF.has_method("send_event"):
		MPF.call("send_event", event_name)
		return

	if ("server" in MPF) and MPF.server:
		var s: Variant = MPF.server

		if s is Object and s.has_method("send_event"):
			s.call("send_event", event_name)
			return

		if s is Object and s.has_method("post_event"):
			s.call("post_event", event_name)
			return


func _get_player_var(var_name: String, default_value: Variant) -> Variant:
	if typeof(MPF) == TYPE_NIL or not MPF:
		return default_value

	if ("server" in MPF) and MPF.server:
		var s: Variant = MPF.server

		if s is Object:
			if s.has_method("get_player_var"):
				var v1: Variant = s.call("get_player_var", var_name, default_value)

				if v1 != default_value:
					return v1

				var v1_prefixed: Variant = s.call("get_player_var", "player_" + var_name, default_value)

				if v1_prefixed != default_value:
					return v1_prefixed

			var player_vars: Variant = _get_object_property(s, "player_vars")

			if typeof(player_vars) == TYPE_DICTIONARY:
				if player_vars.has(var_name):
					return player_vars[var_name]

				if player_vars.has("player_" + var_name):
					return player_vars["player_" + var_name]

			var player: Variant = _get_object_property(s, "player")

			if typeof(player) == TYPE_DICTIONARY:
				if player.has(var_name):
					return player[var_name]

				if player.has("player_" + var_name):
					return player["player_" + var_name]

	if MPF.has_method("get_player_var"):
		var v2: Variant = MPF.call("get_player_var", var_name, default_value)

		if v2 != default_value:
			return v2

		return MPF.call("get_player_var", "player_" + var_name, default_value)

	return default_value


func _get_object_property(obj: Object, property_name: String) -> Variant:
	for property in obj.get_property_list():
		if property.has("name") and property["name"] == property_name:
			return obj.get(property_name)

	return null
