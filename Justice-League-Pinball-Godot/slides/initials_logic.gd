extends Node

# Direct node references (no inspector wiring needed)
@onready var letter_1: Label = $"../initials_container/letter_1"
@onready var letter_2: Label = $"../initials_container/letter_2"
@onready var letter_3: Label = $"../initials_container/letter_3"
@onready var finish_sound: AudioStreamPlayer2D = $"../finish_sound"
@onready var animation_player: AnimationPlayer = $"../AnimationPlayer"

var letters: Array[Label] = []
var active_index: int = 0
var finished: bool = false   # once true, no more input

func _ready() -> void:
	# Put all three letters in an array for easy looping
	letters = [letter_1, letter_2, letter_3]

	# Only first letter visible and default all to "A"
	for i in range(letters.size()):
		letters[i].text = "A"
		letters[i].visible = (i == 0)

	active_index = 0
	finished = false
	_update_highlight()

	# Make sure _input() will be called
	set_process_input(true)

	# Start the blinking arrow animation
	if animation_player:
		animation_player.play("blink_info")
	else:
		print("initials_logic: AnimationPlayer not found")

func _update_highlight() -> void:
	# Reset all letters to white and normal size
	for i in range(letters.size()):
		letters[i].modulate = Color.WHITE
		letters[i].scale = Vector2.ONE

	# Highlight the active letter (if it's visible)
	var current := letters[active_index]
	if current.visible:
		current.modulate = Color(1, 0.4, 0.4)  # light red
		current.scale = Vector2(1.15, 1.15)

func shift_letter(direction: int) -> void:
	if finished:
		return  # do nothing once initials are finished

	var label := letters[active_index]
	if label.text.is_empty():
		label.text = "A"

	var code := label.text.unicode_at(0)
	code += direction

	if code < 65:      # 'A'
		code = 90      # 'Z'
	elif code > 90:    # 'Z'
		code = 65      # 'A'

	label.text = String.chr(code)

func _finalize_initials() -> void:
	finished = true
	print("Finished selecting initials")

	# Clear highlight so all letters look the same
	for i in range(letters.size()):
		letters[i].modulate = Color.WHITE
		letters[i].scale = Vector2.ONE

	# Build the initials string
	var initials := ""
	for l in letters:
		initials += l.text

	print("Final initials:", initials)

	# Play the finish sound
	if finish_sound:
		print("Playing finish sound")
		finish_sound.play()
	else:
		print("finish_sound not found!")

	# Send initials back to MPF high score mode
	# This posts the standard event: text_input_high_score_complete(text=INITIALS)
	if typeof(MPF) != TYPE_NIL and MPF.server:
		MPF.server.send_event_with_args(
			"text_input_high_score_complete",
			{"text": initials}
		)
		print("Sent initials to MPF")
	else:
		print("MPF not available - could not send initials")

func select_letter() -> void:
	if finished:
		return

	# If there is another letter, reveal it and move to it
	if active_index < letters.size() - 1:
		active_index += 1
		letters[active_index].visible = true
		_update_highlight()
	else:
		# All 3 letters chosen: finalize
		_finalize_initials()

func _input(event: InputEvent) -> void:
	if finished:
		return

	# Debug: see every key we get
	if event is InputEventKey and event.pressed and not event.echo:
		print("Key pressed:", event.as_text())

	if event.is_action_pressed("hs_left"):
		print("hs_left action")
		shift_letter(-1)
	elif event.is_action_pressed("hs_right"):
		print("hs_right action")
		shift_letter(1)
	elif event.is_action_pressed("hs_select"):
		print("hs_select action")
		select_letter()
