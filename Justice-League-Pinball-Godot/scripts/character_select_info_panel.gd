extends Control
class_name CharacterSelectInfoPanel

@export_category("Grid Controller (recommended)")
@export var grid_path: NodePath

@export_category("Info Panel")
@export var info_container_path: NodePath = NodePath(".") # where *_info nodes live
@export var default_panel_name: String = ""               # optional, e.g. "batman_info"
@export var debug_print: bool = false

var _grid: CharacterSelectGridController = null
var _info_container: Node = null
var _info_panels: Dictionary = {} # character_id -> CanvasItem


func _ready() -> void:
	_info_container = get_node_or_null(info_container_path)
	if _info_container == null:
		_info_container = self

	_cache_info_panels()
	_hide_all_info()

	_grid = get_node_or_null(grid_path) as CharacterSelectGridController
	if _grid == null:
		push_warning("CharacterSelectInfoPanel: grid_path not set or grid not found.")
		return

	_grid.character_selected.connect(_on_character_selected)

	if debug_print:
		print("[InfoPanel] Connected to grid controller.")

	# Show current selection if grid already has one
	call_deferred("_show_initial")


func _cache_info_panels() -> void:
	_info_panels.clear()
	for child in _info_container.get_children():
		if child is CanvasItem:
			var node_name: String = (child as Node).name.to_lower()
			if node_name.ends_with("_info"):
				var id: String = node_name.replace("_info", "")
				_info_panels[id] = child as CanvasItem


func _hide_all_info() -> void:
	for key_any in _info_panels.keys():
		var node_any: Variant = _info_panels[key_any]
		if node_any != null and node_any is CanvasItem:
			(node_any as CanvasItem).visible = false

	# Optional default
	if default_panel_name != "":
		var d: Node = _info_container.get_node_or_null(default_panel_name)
		if d != null and d is CanvasItem:
			(d as CanvasItem).visible = true


func _on_character_selected(character_id: String) -> void:
	_hide_all_info()

	var key: String = character_id.to_lower()
	if _info_panels.has(key):
		var panel_any: Variant = _info_panels[key]
		if panel_any != null and panel_any is CanvasItem:
			(panel_any as CanvasItem).visible = true

	if debug_print:
		print("[InfoPanel] showing ", key)


func _show_initial() -> void:
	if _grid == null:
		return
	var id: String = _grid.get_current_id()
	if id != "":
		_on_character_selected(id)
