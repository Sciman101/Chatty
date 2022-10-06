extends Node

const SpeechBubble = preload("res://scene/speech_bubble.tscn")
const Speakers = {
	'jnfr': preload("res://speakers/speaker_jnfr.tres")
}

var current_dialouge_bubble = null
var actors = {}

var script_events = []
var script_labels = {}
var script_active = false
var script_index := 0

signal event_started(num,event)
signal script_completed

func run_script(start:int=0) -> void:
	script_active = true
	script_index = start
	
	if current_dialouge_bubble:
		current_dialouge_bubble.set_speaker_animation()
	
	while script_index < script_events.size():
		var event = script_events[script_index]

		if not script_active:
			break
		event_started.emit(script_index,event)
		match event.type:
			&'dialouge':
				await _run_dialouge_event(event)
			&'instruction':
				await _run_instruction_event(event)
			&'label':
				pass # Labels do nothing. this is just here for completeness
		
		script_index += 1
	
	if current_dialouge_bubble:
		current_dialouge_bubble.disappear()
	
	script_active = false
	
	script_completed.emit()

func stop_script() -> void:
	if current_dialouge_bubble:
		current_dialouge_bubble.stop_dialouge()
	script_active = false

func _run_dialouge_event(event) -> void:
	
	if current_dialouge_bubble == null:
		_create_dialouge_bubble()
	
	current_dialouge_bubble.set_dialouge(event.dialouge)
	
	if current_dialouge_bubble.speaker != event.speaker:
		current_dialouge_bubble.set_speaker(event.speaker)
	
	if event.has('animation_name') and event.animation_name.length() > 0:
		current_dialouge_bubble.set_speaker_animation(event.animation_name)
	
	if not current_dialouge_bubble.is_bubble_visible():
		await current_dialouge_bubble.appear()
	
	var args = {}
	if event.has('args'): args = event.args
	await current_dialouge_bubble.present(args)

func _create_dialouge_bubble() -> void:
	current_dialouge_bubble = SpeechBubble.instantiate()
	add_child(current_dialouge_bubble)
	current_dialouge_bubble.position = current_dialouge_bubble.get_viewport_rect().position + current_dialouge_bubble.get_viewport_rect().size / 2 + Vector2.RIGHT * 100
	current_dialouge_bubble.disappearImmediate()

func _run_instruction_event(event) -> void:
	var params = event.params
	if params.size() == 0:
		push_warning("Empty instruction!")
		return
	match params[0]:
		'goto':
			# Jump to the labeled section
			if params.size() > 1:
				var label = params[1]
				if script_labels.has(label):
					script_index = script_labels[label]-1
				else:
					push_warning("Insufficient params!")
		'fin':
			# Stop after this command
			script_index = script_events.size()+1
		'gotor':
			# Go to a random label
			if params.size() > 1:
				var label_index = randi_range(1,params.size()-1)
				print(label_index)
				var label = params[label_index]
				if script_labels.has(label):
					script_index = script_labels[label]-1
			else:
				push_warning("Insufficient params!")

# Load a script into the chatty system
func load_script(script_text:String) -> void:
	script_events = []
	var lines = script_text.split("\n")
	var idx : =0
	for line in lines:
		if line.length() > 0 and line[0] != '(':
			_parse_line(line,idx)
			idx += 1

func _parse_line(line:String,event_index:int) -> void:
	if line[0] == '>':
		# Parse action
		line = line.substr(1)
		var event = {
			'type':&'instruction',
			'params': Array(line.split(' ')).map(func(item): return item.strip_edges())
		}
		script_events.append(event)
	elif line[0] == '#':
		# Parse label
		var label_name = line.substr(1).strip_edges()
		script_labels[label_name] = event_index
		var event = {
			'type':&'label'
		}
		script_events.append(event)
	else:
		# Dialouge line
		# Format: [name]:[dialouge]
		var colon_index = line.find(':')
		if colon_index == -1:
			push_error("Malformed dialouge line: " + line)
		else:
			var params = Array(line.substr(0,colon_index).strip_edges().split(',')).map(func(item): return item.strip_edges().to_lower())
			var dialouge = line.substr(colon_index+1).strip_edges()
			
			var event = {
				'type': &'dialouge',
				'speaker': Speakers[params[0]],
				'dialouge': dialouge
			}
			if params.size() > 1:
				event['animation_name'] = params[1]
			if params.size() > 2:
				event['args'] = _parse_args(params.slice(2))
			script_events.append(event)

func _parse_args(arg_list:Array) -> Dictionary:
	var args = {}
	for a in arg_list:
		var equals_index = a.find('=')
		if equals_index == -1:
			args[a] = true
		else:
			var key = a.substr(0,equals_index)
			var val = a.substr(equals_index+1)
			args[key] = val
	return args

# Actor control

func register_actor(node:Node2D, actor_name:String) -> void:
	if actors.has(actor_name):
		push_warning("Overriding actor " + actor_name)
	actors[actor_name] = node

func deregister_actor(actor_name:String) -> void:
	actors.erase(actor_name)
