extends Control

@onready var speech_bubble = $SpeechBubble
var _speech_bubble_positions = {}

var current_script = null
var script_event_index := -1
var interrupt := false

@export_multiline var script_text : String

func _ready() -> void:
	# Get speech bubble positions
	for child in $SpeechBubblePositions.get_children():
		_speech_bubble_positions[str(child.name).to_lower()] = child.position
	speech_bubble.disappearImmediate()
	
	# DEBUG
	current_script = ChattyParser.compile_script(script_text)
	run_script(current_script)

func run_script(script) -> void:
	current_script = script
	script_event_index = 0
	
	while script_event_index < current_script.size():
		if interrupt: break
		
		await _run_current_script_event()
		script_event_index += 1
	
	# Hide speech bubble
	if speech_bubble.is_bubble_visible():
		speech_bubble.disappear()

func _wait_for_input() -> void:
	while not Input.is_action_pressed("advance_dialouge"):
		await get_tree().process_frame

func _run_current_script_event() -> void:
	var event = current_script.events[script_event_index]
	
	match event.type:
		&'dialouge':
			await _run_dialouge_event(event)
		&'instruction':
			await _run_instruction_event(event)
		&'label':
			pass # Labels do nothing. this is just here for completeness

func _run_dialouge_event(event) -> void:
	# Show speech bubble, if it's not present already
	if not speech_bubble.is_bubble_visible():
		await speech_bubble.appear()
	await speech_bubble.present(event)
	
	if not (event.flags.has('nopause') or event.flags.has('np')):
		await _wait_for_input()

func _run_instruction_event(event) -> void:
	pass

func interrupt_script() -> void:
	interrupt = true
	current_script = null
