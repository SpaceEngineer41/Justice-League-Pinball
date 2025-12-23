extends Node

@export var playlist: Array[String] = [
	"batman_overlooking_gotham",
	"bat_signal_roof"
]

# seconds for each clip (must match playlist length)
@export var durations: Array[float] = [6.0, 6.0]

@export var force_mute := true

@onready var timer: Timer = $SwitchTimer

var _idx := 0
var _current: Node = null

func _ready() -> void:
	if playlist.is_empty():
		push_warning("BackgroundController: playlist is empty.")
		return
	if durations.size() != playlist.size():
		push_warning("BackgroundController: durations must match playlist length.")
		return

	timer.one_shot = true
	_play_named(playlist[_idx])

func _play_named(node_name: String) -> void:
	var node := get_parent().get_node_or_null(node_name)
	if node == null:
		push_warning("BackgroundController: Cannot find node '%s' under slide." % node_name)
		return

	# Stop/hide previous
	if _current and _current != node:
		_current.visible = false
		if _current.has_method("stop"):
			_current.stop()

	_current = node
	_current.visible = true

	# Mute background if desired
	if force_mute and _current.has_method("set_volume_db"):
		_current.set_volume_db(-80)
	elif force_mute and "volume_db" in _current:
		_current.volume_db = -80

	# Play
	if _current.has_method("play"):
		_current.play()
	else:
		push_warning("BackgroundController: Node '%s' has no play() method." % node_name)

	# Schedule next switch
	timer.stop()
	timer.wait_time = durations[_idx]
	if not timer.is_connected("timeout", Callable(self, "_on_timeout")):
		timer.connect("timeout", Callable(self, "_on_timeout"))
	timer.start()

func _on_timeout() -> void:
	_idx = (_idx + 1) % playlist.size()
	_play_named(playlist[_idx])
