extends Node
class_name CharacterState

@export var character_name: String = ""
@export var poll_interval: float = 0.25

var _poll_accum: float = 0.0
var _last_locked: bool = false
var _initialized: bool = false

@onready var _character_root: Node = get_parent()

@onready var locked_overlay: CanvasItem = _character_root.get_node_or_null("locked_overlay") as CanvasItem
@onready var locked_label: CanvasItem = _character_root.get_node_or_null("locked_label") as CanvasItem
@onready var highlight: CanvasItem = _character_root.get_node_or_null("highlight") as CanvasItem
@onready var sprite: CanvasItem = null


func _ready() -> void:
	if character_name.strip_edges() == "":
		character_name = str(_character_root.name).to_lower()

	var sprite_node := _character_root.get_node_or_null(NodePath(str(_character_root.name)))
	if sprite_node is CanvasItem:
		sprite = sprite_node as CanvasItem

	_update_state(true)


func _process(delta: float) -> void:
	_poll_accum += delta

	if _poll_accum < poll_interval:
		return

	_poll_accum = 0.0
	_update_state(false)


func _update_state(force: bool) -> void:
	var status_key := "%s_mode_status" % character_name
	var status := str(_get_player_var(status_key, "incomplete")).strip_edges().to_lower()
	var unlocked := status == "complete"
	var locked := not unlocked

	if not force and _initialized and locked == _last_locked:
		return

	_initialized = true
	_last_locked = locked

	if locked_overlay:
		locked_overlay.visible = locked

	if locked_label:
		locked_label.visible = locked

	if sprite and sprite.material:
		sprite.material.set_shader_parameter("locked", locked)

	# Highlight visibility is controlled by CharacterSelectGridController.


func _get_player_var(var_name: String, default_value: Variant) -> Variant:
	if typeof(MPF) != TYPE_NIL and MPF:
		if ("server" in MPF) and MPF.server:
			var s: Variant = MPF.server

			if s is Object:
				var player_vars: Variant = _get_object_property(s, "player_vars")
				if typeof(player_vars) == TYPE_DICTIONARY and player_vars.has(var_name):
					return player_vars[var_name]

				var player: Variant = _get_object_property(s, "player")
				if typeof(player) == TYPE_DICTIONARY and player.has(var_name):
					return player[var_name]

				if s.has_method("get_player_var"):
					return s.call("get_player_var", var_name, default_value)

		if MPF.has_method("get_player_var"):
			return MPF.call("get_player_var", var_name, default_value)

	return default_value


func _get_object_property(obj: Object, property_name: String) -> Variant:
	for property in obj.get_property_list():
		if property.has("name") and property["name"] == property_name:
			return obj.get(property_name)

	return null
