extends Control
class_name MPFGridHighlight

@export var carousel_name: String = "character_select"
var log

func _enter_tree():
	log = preload("res://addons/mpf-gmc/scripts/log.gd").new("GridHighlight<%s:%s>" % [name, carousel_name])

func _ready():
	# Fallback if you forget to set carousel_name in Inspector
	if carousel_name == "":
		carousel_name = name

	# Hide ALL highlights on startup
	for character in get_children():
		var highlight := character.get_node_or_null("highlight")
		if highlight:
			highlight.hide()

	MPF.server.item_highlighted.connect(_on_item_highlighted)
	log.debug("GridHighlight ready for '%s'", carousel_name)

func _on_item_highlighted(payload: Dictionary) -> void:
	if payload.get("carousel", "") != carousel_name:
		return

	# Avoid Variant typing warnings by forcing a String
	var selected: String = str(payload.get("item", ""))

	log.debug("Highlighting '%s'", selected)

	for character in get_children():
		var highlight := character.get_node_or_null("highlight")
		if not highlight:
			continue

		highlight.visible = (character.name == selected)
