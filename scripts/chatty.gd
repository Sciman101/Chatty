extends Node

const SpeechBubble = preload("res://scene/speech_bubble.tscn")
const Speakers = {
	'jnfr': preload("res://speakers/speaker_jnfr.tres")
}

var current_dialouge_bubble = null
var actors = {}

var script_events = []
var script_active = false

signal event_started(num,event)

func run_script(start:int=0) -> void:
	script_active = true
	var index := 0
	for event in script_events:
		
		if index >= start:
			if not script_active:
				break
			event_started.emit(index,event)
			if event.type == &'dialouge':
				await _run_dialouge_event(event)
			elif event.type == &'instruction':
				pass
		
		index += 1
	
	if current_dialouge_bubble:
		current_dialouge_bubble.disappear()
	
	script_active = false

func stop_script() -> void:
	current_dialouge_bubble.stop_dialouge()
	script_active = false

func _run_dialouge_event(event) -> void:
	if current_dialouge_bubble == null:
		current_dialouge_bubble = SpeechBubble.instantiate()
		add_child(current_dialouge_bubble)
		current_dialouge_bubble.position = current_dialouge_bubble.get_viewport_rect().position + current_dialouge_bubble.get_viewport_rect().size / 2 + Vector2.RIGHT * 100
		current_dialouge_bubble.disappearImmediate()
	
	current_dialouge_bubble.set_dialouge(event.dialouge)
	
	if current_dialouge_bubble.speaker != event.speaker:
		current_dialouge_bubble.set_speaker(event.speaker)
		if current_dialouge_bubble.is_bubble_visible():
			# Animate the bubble tweening over
			pass
	
	if event.has('animation_name'):
		current_dialouge_bubble.set_speaker_animation(event.animation_name)
	
	var animate_portrait = true
	var play_sound = true
	
	if event.has('args'):
		for arg in event.args:
			# Duration
			if arg[-1] == 's':
				current_dialouge_bubble.set_dialouge_duration(arg.substr(0,arg.length()-1).to_float())
			elif arg == 'noanimate':
				animate_portrait = false
			elif arg == 'nosound':
				play_sound = false
	
	if not current_dialouge_bubble.is_bubble_visible():
		await current_dialouge_bubble.appear()
	
	await current_dialouge_bubble.present(animate_portrait,play_sound)

# Load a script into the chatty system
func load_script(script_text:String) -> void:
	script_events = []
	var lines = script_text.split("\n")
	for line in lines:
		if line.length() > 0:
			_parse_line(line)

func _parse_line(line:String) -> void:
	if line[0] == '*':
		line = line.substr(1)
		var event = {
			'type':&'instruction',
			'args': Array(line.split(',')).map(func(item): return item.strip_edges())
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
				event['args'] = params.slice(2)
			script_events.append(event)

# Actor control

func register_actor(node:Node2D, actor_name:String) -> void:
	if actors.has(actor_name):
		push_warning("Overriding actor " + actor_name)
	actors[actor_name] = node

func deregister_actor(actor_name:String) -> void:
	actors.erase(actor_name)
