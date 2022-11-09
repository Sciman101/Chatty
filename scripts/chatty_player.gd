extends Control

@onready var speech_bubble = $SpeechBubble
var _speech_bubble_positions = {}

var current_script = []
var script_event_index := -1
var interrupt := false

func _ready() -> void:
	# Get speech bubble positions
	for child in $SpeechBubblePositions.get_children():
		_speech_bubble_positions[str(child.name).to_lower()] = child.position

func run_script(script) -> void:
	current_script = script
	script_event_index = 0
	
	while script_event_index < current_script.size():
		if interrupt: break
		
		await _run_current_script_event()
		script_event_index += 1

func _run_current_script_event() -> void:
	var event = current_script[script_event_index]
	
	match event.type:
		&'dialouge':
			await _run_dialouge_event(event)
		&'instruction':
			await _run_instruction_event(event)
		&'label':
			pass # Labels do nothing. this is just here for completeness

func _run_dialouge_event(event) -> void:
	pass

func _run_instruction_event(event) -> void:
	pass

func interrupt_script() -> void:
	interrupt = true
	current_script = null
