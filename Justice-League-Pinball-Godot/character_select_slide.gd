class_name CharacterSelectSlide
extends MPFSceneBase

var _widgets: Control

## A scene root node for creating a Slide that can be added to a display stack using events and the slide_player.

## If true, this slide will not be considered "active" in the slide stack
@export var mask_from_active: bool = false


var current_character := ""


@onready var character_nodes = {
	"wonder_woman": $character_select/wonder_woman,
	"flash": $character_select/flash,
	"batman": $character_select/batman,
	"cyborg": $character_select/cyborg,
	"superman": $character_select/superman,
	"aquaman": $character_select/aquaman
}


@onready var info_nodes = {
	"wonder_woman": $info_panel/wonder_woman_info,
	"flash": $info_panel/flash_info,
	"batman": $info_panel/batman_info,
	"cyborg": $info_panel/cyborg_info,
	"superman": $info_panel/superman_info,
	"aquaman": $info_panel/aquaman_info
}


func initialize(n: String, settings: Dictionary, c: String, p: int = 0, kwargs: Dictionary = {}) -> void:
	# The node name attribute is the name of the root node, which could be
	# anything or case-sensitive. Set an explicit key instead, using the name.
	super(n, settings, c, p, kwargs)

	# Defer this so MPF/GMC has time to finish setting up the slide first.
	call_deferred("_initialize_character_select")


func _initialize_character_select() -> void:
	print("Character select slide initialized")

	_hide_all_highlights()
	_hide_all_info()

	# TEMPORARY TEST:
	# Uncomment this line ONLY while testing the border/info panel.
	# Once it works, comment it back out.
	# set_selected_character("batman")


func process_widget(widget_name: String, action: String, settings: Dictionary, c: String, p: int = 0, kwargs: Dictionary = {}) -> void:
	if not self._widgets:
		self._widgets = Control.new()
		self._widgets.name = "_%s_widgets" % self.name
		self._widgets.set_anchors_preset(PRESET_FULL_RECT)
		self.add_child(self._widgets)

	self.process_action(widget_name, self._widgets.get_children(), action, settings, c, p, kwargs)


func action_play(widget_name: String, settings: Dictionary, c: String, p: int = 0, kwargs: Dictionary = {}) -> MPFWidget:
	var widget: Node = MPF.media.get_widget_instance(widget_name)
	assert(widget is MPFWidget, "Widget scenes must use (or extend) the MPFWidget script on the root node.")

	widget.initialize(widget_name, settings, c, p, kwargs)
	self._widgets.add_child(widget)
	self._sort_widgets()
	self.register_updater(widget)

	# Copy the original kwargs and remove 'name' before sending active event
	var evt_kwargs = kwargs.duplicate()
	evt_kwargs.erase("name")
	MPF.server.send_event_with_args("widget_%s_active" % widget_name, evt_kwargs)

	return widget


func action_remove(widget: Node, kwargs: Dictionary = {}) -> void:
	self._widgets.remove_child(widget)
	self.remove_updater(widget)
	MPF.server.send_event_with_args("widget_%s_removed" % widget.name, kwargs)
	widget.queue_free()


func clear(context_name: String) -> void:
	if not self._widgets:
		return

	for w in self._widgets.get_children():
		if w.context == context_name:
			self.action_remove(w)


func _sort_widgets() -> void:
	var new_order: Array[Node] = self._widgets.get_children()

	new_order.sort_custom(
		func(a: MPFWidget, b: MPFWidget): return a.priority < b.priority
	)

	for i in range(0, new_order.size()):
		self._widgets.move_child(new_order[i], i)


func set_selected_character(character_name: String) -> void:
	character_name = character_name.strip_edges()

	print("Selected character is: ", character_name)

	current_character = character_name

	_hide_all_highlights()
	_hide_all_info()

	if character_nodes.has(character_name):
		var highlight = character_nodes[character_name].get_node("highlight")
		print("Turning on highlight for: ", character_name)
		highlight.visible = true
	else:
		print("Character not found in character_nodes: ", character_name)

	if info_nodes.has(character_name):
		print("Turning on info for: ", character_name)
		info_nodes[character_name].visible = true
	else:
		print("Character not found in info_nodes: ", character_name)


func _hide_all_highlights() -> void:
	for character in character_nodes.values():
		if character.has_node("highlight"):
			character.get_node("highlight").visible = false


func _hide_all_info() -> void:
	for info in info_nodes.values():
		info.visible = false


# Connect current_item_var's value changed signal to this function.
# This should run whenever MPF changes character_select_current_item.
func _on_current_item_var_value_changed(value) -> void:
	print("current_item_var changed to: ", value)
	set_selected_character(str(value))


func _to_string() -> String:
	return "<%s:CharacterSelectSlide:pri=%s:%s" % [self.name, self.priority, self.get_instance_id()]
