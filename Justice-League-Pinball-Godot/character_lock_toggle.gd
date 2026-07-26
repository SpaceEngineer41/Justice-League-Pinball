extends Node
class_name CharacterLockToggle

@export var status_label: Label

@export var locked_overlay: CanvasItem
@export var locked_label: CanvasItem
@export var character_sprite: CanvasItem
@export var locked_material: Material

var _unlocked_material: Material = null
var _last_value: String = ""

func _ready() -> void:
	# Cache the "normal" material the art currently has (this is the UNLOCKED look)
	if character_sprite and character_sprite is CanvasItem:
		_unlocked_material = (character_sprite as CanvasItem).material

	# MPFVariable often updates after _ready(), so apply now + next frame
	_apply_from_status()
	call_deferred("_apply_from_status")

func _process(_delta: float) -> void:
	if not is_instance_valid(status_label):
		return

	var current := status_label.text.strip_edges().to_lower()
	if current != _last_value:
		_apply_from_status()

func _apply_from_status() -> void:
	if not is_instance_valid(status_label):
		return

	_last_value = status_label.text.strip_edges().to_lower()

	# Treat these as unlocked
	var is_unlocked := _last_value in ["complete", "completed", "collected", "true", "1"]

	# Toggle overlay + NOT ASSEMBLED
	if locked_overlay:
		locked_overlay.visible = not is_unlocked
	if locked_label:
		locked_label.visible = not is_unlocked

	# Grayscale only when locked
	if character_sprite and character_sprite is CanvasItem:
		var cs := character_sprite as CanvasItem
		if is_unlocked:
			cs.material = _unlocked_material
		else:
			if locked_material:
				cs.material = locked_material
