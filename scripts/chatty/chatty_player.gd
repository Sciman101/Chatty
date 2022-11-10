extends Control

@onready var speech_bubble = $SpeechBubble
@onready var bg_handler = $Background
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
		&'command':
			await _run_command_event(event)
		&'label':
			pass # Labels do nothing. this is just here for completeness

func _run_dialouge_event(event) -> void:
	# Show speech bubble, if it's not present already
	speech_bubble.set_speaker(event.speaker)
	speech_bubble.set_speaker_animation(event.animation_name)
	speech_bubble.set_dialouge(event.dialouge)
	
	if not speech_bubble.is_bubble_visible():
		await speech_bubble.appear()
	await speech_bubble.present(event)
	
	if not (event.flags.has('nopause') or event.flags.has('np')):
		await _wait_for_input()

func _run_command_event(event) -> void:
	var cmd = event.cmd_name
	var args = event.args
	print(cmd)
	match cmd:
		
		'goto':
			if args.size() >= 1:
				_goto_label(args[0])
		
		'gotor':
			if args.size() >= 1:
				_goto_label(args.pick_random())
		
		'wait':
			if args.size() >= 1:
				var duration = args[0].to_float()
				await get_tree().create_timer(duration).timeout
		
		'bg':
			await bg_handler.transition_background(args)
		
		'appear':
			if not speech_bubble.is_bubble_visible():
				if args.size() > 0 and args[0] == 'now':
					speech_bubble.appearImmediate()
				else:
					await speech_bubble.appear()
		
		'disappear':
			if speech_bubble.is_bubble_visible():
				if args.size() > 0 and args[0] == 'now':
					speech_bubble.disappearImmediate()
				else:
					await speech_bubble.disappear()

func _goto_label(label_string:String) -> void:
	script_event_index = current_script.label_indices[label_string] - 1

func interrupt_script() -> void:
	interrupt = true
	current_script = null
