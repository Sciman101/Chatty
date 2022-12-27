extends Control

const DEFAULT_SPEECHBUBBLE_MOVE_DURATION = 0.5

@onready var ffwd_indicator = $FFWD

@onready var bg_handler = $BackgroundHandler
@onready var music_handler = $MusicHandler
@onready var sprite_handler = $SpriteHandler

@onready var speech_bubble = $SpeechBubble
@onready var choice_box = $ChoiceBox
var _speech_bubble_positions = {}

var current_script = null
var script_event_index := -1
var interrupt := false

var ffwd := false

var _return_stack = []
var _aliases = {}

func _ready() -> void:
	
	Engine.time_scale = 1
	
	# Get speech bubble positions
	for child in $SpeechBubblePositions.get_children():
		_speech_bubble_positions[str(child.name).to_lower()] = child.position
	speech_bubble.disappearImmediate()
	
	var project_path = "res://.chatty_project"
	if OS.has_feature('standalone'):
		project_path = OS.get_executable_path().get_base_dir() + "/project"
	AssetHandler.load_project(project_path)
	
	current_script = AssetHandler.start_script
	if current_script:
		run_script(current_script)

# DEBUGGING
# TODO clean this up
func _input(event):
	if event is InputEventKey:
		if Input.is_action_just_pressed("restart"):
			get_tree().reload_current_scene()
		
		elif Input.is_action_just_pressed("fast_forward"):
			ffwd_indicator.visible = true
			ffwd = true
			Engine.time_scale = 10
		elif Input.is_action_just_released("fast_forward"):
			ffwd_indicator.visible = false
			ffwd = false
			Engine.time_scale = 1

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

func _current_event():
	return current_script.events[script_event_index]

func _next_event():
	if script_event_index < current_script.events.size()-1:
		return current_script.events[script_event_index+1]
	return null

func _run_current_script_event() -> void:
	var event = _current_event()
	
	match event.type:
		&'dialouge':
			await _run_dialouge_event(event)
		&'command':
			await _run_command_event(event)
		&'choice':
			await _run_choice_event(event)
		&'label':
			pass # Labels do nothing. this is just here for completeness

func _run_dialouge_event(event) -> void:
	# Show speech bubble, if it's not present already
	speech_bubble.set_speaker(event.speaker)
	speech_bubble.set_speaker_animation(event.get('animation_name',&'default'))
	speech_bubble.set_dialouge(event.dialouge)
	speech_bubble.set_wide(event.flags.get('noportrait',false))
	speech_bubble.set_frame(event.flags.get('frame',0))
	
	if event.flags.get('noname'):
		speech_bubble.set_speaker_name("")
	elif event.flags.get('name'):
		speech_bubble.set_speaker_name(event.flags.get('name'))
	
	var target_pos = null
	var pos_name = event.flags.get('pos','bottom')
	if _speech_bubble_positions.has(pos_name):
		target_pos = _speech_bubble_positions[pos_name]
	
	if not speech_bubble.is_bubble_visible():
		if target_pos:
			speech_bubble.position = target_pos
			target_pos = null
		await speech_bubble.appear()
	
	if target_pos and speech_bubble.position != target_pos:
		var tween = get_tree().create_tween()
		tween.tween_property(speech_bubble,'position',target_pos,DEFAULT_SPEECHBUBBLE_MOVE_DURATION).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		await tween.finished
	
	await speech_bubble.present(event)
	
	if _should_wait_for_input(event):
		await _wait_for_input()

func _should_wait_for_input(event) -> bool:
	if ffwd: return false
	if event.flags.get('skip'): return false
	var next_event = _next_event()
	if next_event and next_event.type == &'choice': return false
	return true

func _run_choice_event(event) -> void:
	choice_box.present_choice(event)
	var choice = await choice_box.on_choice_made
	_goto_label(choice)

func _run_command_event(event) -> void:
	var cmd = event.cmd_name
	if Commands.commands.has(cmd):
		var command = Commands.commands[cmd]
		await command.exec.call(self,event.args,event.optionals)
	else:
		_player_error("Unknown command " + cmd)

func _goto_label(label_string:String) -> void:
	if current_script.label_indices.has(label_string):
		_return_stack.push_back(script_event_index)
		script_event_index = current_script.label_indices[label_string] - 1
	else:
		_player_error("No such label " + label_string)

func interrupt_script() -> void:
	interrupt = true
	current_script = null

func _player_error(message:String) -> void:
	Console.error(message)
	push_error(message)
