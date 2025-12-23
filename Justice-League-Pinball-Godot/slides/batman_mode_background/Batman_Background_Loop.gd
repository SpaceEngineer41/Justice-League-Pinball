extends Control

@onready var a: VideoStreamPlayer = $bg_a
@onready var b: VideoStreamPlayer = $bg_b

var _use_a := true

func _ready() -> void:
	# Make sure ONLY ONE is visible at a time
	a.visible = false
	b.visible = false

	# Ensure they do NOT self-loop (we control looping by swapping)
	a.loop = false
	b.loop = false

	# Mute background video audio (MPF should control audio/music)
	a.volume_db = -80
	b.volume_db = -80

	# Connect finished signals
	if not a.finished.is_connected(_on_a_finished):
		a.finished.connect(_on_a_finished)
	if not b.finished.is_connected(_on_b_finished):
		b.finished.connect(_on_b_finished)

	# Start the first clip
	_play_a()

func _play_a() -> void:
	_use_a = true
	b.stop()
	b.visible = false

	a.visible = true
	a.play()

func _play_b() -> void:
	_use_a = false
	a.stop()
	a.visible = false

	b.visible = true
	b.play()

func _on_a_finished() -> void:
	_play_b()

func _on_b_finished() -> void:
	_play_a()
