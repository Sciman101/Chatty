extends Node
class_name ChattyParser

const VALID_FLAGS = {
	'pos':['bottom','right','left','center','top'],
	'name':&'string',
	'duration':[0.01,1000],
	'frame':[0.0,9999],
	'speed':[0.001,10],
	'volume':[0.0,1],
	'pitch':[0.0,2.0],
	'noanim':&'bool',
	'nosound':&'bool',
	'noportrait':&'bool',
	'noname':&'bool',
	'skip':&'bool'
}

var error = false

class ChattyScript:
	var events = []
	var label_indices = {}
	var raw_text : String = ""
	
	func add_event(event) -> void:
		events.append(event)
	func add_label(label_text) -> void:
		label_indices[label_text] = events.size()
	
	func size() -> int: return events.size()
	
	func debug_string() -> String:
		return "====\nChattyScript:\nEvents: %s\nLabels: %s\n====" % [events,label_indices]

var choice_queue = []
var line_num := 0

func compile_script(script_text:String) -> ChattyScript:
	error = false
	
	var lines = Array(script_text.split('\n')).map(func(s): return s.strip_edges())
	var script = ChattyScript.new()
	script.raw_text = script_text
	choice_queue = []
	
	line_num = 0
	for line in lines:
		_parse_line(line,script)
		line_num += 1
	
	# Add dangling choice event
	_resolve_choice_event(script)
	
	return script

func _parser_error(message:String) -> void:
	error = message + " @ line " + str(line_num)
	Console.error(error)

func _determine_event_type(line:String) -> StringName:
	if line.begins_with('?'):
		return &'choice'
	elif line.begins_with('#'):
		return &'label'
	elif line.begins_with('>'):
		return &'command'
	else:
		var index = line.find(':')
		if index != -1:
			return &'dialogue'
		return &'none'

func _resolve_choice_event(script:ChattyScript) -> void:
	# Add choice event
	if choice_queue.size() > 0:
		var event = {
			'type':&'choice',
			'options': choice_queue
		}
		choice_queue = []
		script.add_event(event)

func _parse_line(line:String,script:ChattyScript) -> void:
	line = line.strip_edges()
	var event_type = _determine_event_type(line)
	
	if event_type == &'choice':
		_parse_choice_event(line)
	else:
		# Add choice event if we have more than 1 in the queue
		_resolve_choice_event(script)
	
		if line.begins_with('(') and line.ends_with(')'):
			pass # Do nothing. comment
		elif line.length() == 0:
			pass # Empty line. do nothing
		
		elif event_type == &'label':
			_parse_label_event(line,script)
		elif event_type == &'command':
			_parse_command_event(line,script)
		elif event_type == &'dialogue':
			_parse_dialogue_event(line,script)

func _parse_label_event(line:String,script:ChattyScript):
	var label_name = line.substr(1).strip_edges()
	script.add_label(label_name)
	var event = {
		'type':&'label'
	}
	script.add_event(event)

func _parse_command_event(line:String,script:ChattyScript):
	var args = line.substr(1).split(' ')
	var cmd_name = args[0]
	args = args.slice(1)
	var event = {
		'type':&'command',
		'cmd_name': cmd_name,
		'args': args
	}
	script.add_event(event)

func _parse_choice_event(line:String):
	var choice_line = line.substr(1).strip_edges(true,false)
	var colon_index = choice_line.find(':')
	var label = ''
	var prompt = ''
	if colon_index == -1:
		label = choice_line
		prompt = label
	else:
		label = choice_line.substr(0,colon_index)
		prompt = choice_line.substr(colon_index+1)
	choice_queue.append({
		'label': label,
		'prompt': prompt
	})

func _parse_dialogue_event(line:String,script:ChattyScript):
	var colon_index = line.find(':')
	if colon_index == -1:
		_parser_error("Malformed dialouge line")
	else:
		
		#name:dialogue
		#name,anim:dialogue
		#name,anim[flags]:dialogue
		var slice_start := 0
		var slice_end := 0
		var chr = line[0]
		# figure out the speaker name
		while slice_end < line.length()-1 and chr != ',' and chr != ':' and chr != '[':
			slice_end += 1
			chr = line[slice_end]
		if slice_end == line.length()-1:
			_parser_error("Malformed dialogue line")
			return
		
		var speaker_name = line.substr(slice_start,slice_end-slice_start).strip_edges()
		slice_start = slice_end+1
		
		# figure out the animation name, if one exists
		var animation_name = ''
		if chr == ',':
			while slice_end < line.length()-1 and chr != ':' and chr != '[':
				slice_end += 1
				chr = line[slice_end]
			if slice_end == line.length()-1:
				_parser_error("Malformed dialogue line")
				return
			animation_name = line.substr(slice_start,slice_end-slice_start).strip_edges()
			slice_start = slice_end+1
		
		var flags = []
		# figure out flags, if they exist
		if chr == '[':
			var closing_bracket_index = line.find(']',slice_start)
			if closing_bracket_index == -1:
				_parser_error("Malformed dialogue line, no closing bracket")
				return
			flags = line.substr(slice_start,closing_bracket_index-slice_start).strip_edges().split(',')
		
		var raw_dialogue = line.substr(colon_index+1).strip_edges()
		var result = _strip_triggers_from_bbcode(raw_dialogue)
		
		var event = {
			'type': &'dialouge',
			'speaker': speaker_name,
			'flags': _parse_flags(flags),
			'dialouge': result.bbcode,
			'triggers': result.triggers
		}
		if animation_name != '':
			event['animation_name'] = animation_name
		script.add_event(event)

func _parse_flags(flag_list:Array) -> Dictionary:
	var flags = {}
	for f in flag_list:
		f = f.strip_edges()
		var equals_index = f.find('=')
		var key = f
		var val = true
		if equals_index != -1:
			key = f.substr(0,equals_index).strip_edges()
			val = f.substr(equals_index+1).strip_edges()
		
		if not VALID_FLAGS.has(key):
			_parser_error("Unknown flag '%s'" % [key])
		else:
			var accepted = VALID_FLAGS[key]
			var ok = true
			if accepted is StringName:
				if accepted == &'bool':
					if val or val == 'true': val = true
					else: val = false
					ok = true
				elif accepted == &'string':
					ok = true
			elif accepted[0] is float or accepted[0] is int:
				var _min = accepted[0]
				var _max = accepted[1]
				val = val.to_float()
				if val < _min or val > _max:
					_parser_error("Flag value out of range for flag '%s', [%f,%f]" % [key,_min,_max])
					ok = false
			elif not val in accepted:
				_parser_error("Invalid flag value for flag '%s' (Accepted values are %s)" % [key,accepted])
				ok = false
		
			if ok:
				flags[key] = val
		
	return flags

# Converts a markdown-esque syntax into bbcode
# Also parses events
func _strip_triggers_from_bbcode(bbcode:String) -> Dictionary:
	var result = {bbcode="",triggers={}}
	
	var raw_string_index = 0
	var displayed_string_index = 0
	
	while raw_string_index < bbcode.length():
		var chr = bbcode[raw_string_index]
		
		# bbcode tags
		if chr == '[':
			var temp_string_index = raw_string_index
			while bbcode[temp_string_index] != ']' and temp_string_index < bbcode.length():
				temp_string_index += 1
			if temp_string_index != bbcode.length():
				# Jump index ahead
				result.bbcode += bbcode.substr(raw_string_index,temp_string_index-raw_string_index+1)
				raw_string_index = temp_string_index
		
		elif chr == '<':
			var temp_string_index = raw_string_index
			while bbcode[temp_string_index] != '>' and temp_string_index < bbcode.length():
				temp_string_index += 1
			if temp_string_index != bbcode.length():
				# Get the trigger
				var trigger = bbcode.substr(raw_string_index+1,temp_string_index-raw_string_index-1)
				result.triggers[displayed_string_index] = trigger.split(' ')
				raw_string_index = temp_string_index
		else:
			# Just add the character
			displayed_string_index += 1
			result.bbcode += bbcode[raw_string_index]
		
		raw_string_index += 1
	
	return result
