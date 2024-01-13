extends Node
class_name ChattyParser

var error = false

var choice_queue = []
var line_num := 0

const FlagSchema = {
	'pos':{
		'type':TYPE_ARRAY,
		'values':['bottom','right','left','center','top']
	},
	'name':{
		'type':TYPE_STRING
	},
	'duration':{
		'type':TYPE_FLOAT,
		'min': 0.01,
		'max': 1000
	},
	'frame':{
		'type':TYPE_FLOAT,
		'min': 0,
		'max': 9999
	},
	'speed':{
		'type':TYPE_FLOAT,
		'min': 0.01,
		'max': 10
	},
	'volume':{
		'type':TYPE_FLOAT,
		'min': 0,
		'max': 1
	},
	'pitch':{
		'type':TYPE_FLOAT,
		'min': 0,
		'max': 2
	},
	'noanim':{'type':TYPE_BOOL},
	'nosound':{'type':TYPE_BOOL},
	'noportrait':{'type':TYPE_BOOL},
	'noname':{'type':TYPE_BOOL},
	'skip':{'type':TYPE_BOOL},
}

func parse_script(script_text:String) -> ChattyScript:
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
	line = line.substr(1).strip_edges()
	var cmd_name = line.split(' ')[0]
	
	if not Commands.commands.has(cmd_name):
		return _parser_error("Unknown command " + cmd_name)
	var command = Commands.commands[cmd_name]
	
	line = line.substr(cmd_name.length()).strip_edges(true,false)
	
	var args = line.split(' ')
	
	if not command.get('vararg',false) and args.size() < command.argc:
		return _parser_error("Not enough arguments for command " + cmd_name)
	
	var optionals = {}
	if command.has('optionals'):
		optionals = command.optionals.duplicate()
		if not command.get('vararg',false) and args.size() > command.argc:
			var extra_args = args.slice(command.argc-1)
			args = args.slice(0,command.argc)
			for arg in extra_args:
				var key = null
				var value = null
				var index = arg.find('=')
				if index != -1:
					if index == 0 or index == arg.length()-1:
						_parser_error("Malformed optional argument " + arg)
					else:
						key = arg.substr(0,index)
						value = arg.substr(index+1)
				else:
					key = arg
					value = true
				
				if command.optionals.has(key):
					var type = typeof(command.optionals[key])
					if type == TYPE_FLOAT or type == TYPE_INT:
						value = value.to_float()
					elif type == TYPE_BOOL:
						if (typeof(value) == TYPE_BOOL and value) or value == 'true':
							value = true
						else:
							value = false
					elif type == TYPE_VECTOR2:
						pass
						# TODO write vector2 parser
					optionals[key] = value
	
	var event = {
		'type':&'command',
		'cmd_name': cmd_name,
		'args': args,
		'optionals': optionals
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
	for flag_text in flag_list:
		flag_text = flag_text.strip_edges()
		var key = null
		var value = null
		var index = flag_text.find('=')
		if index != -1:
			if index == 0 or index == flag_text.length()-1:
				_parser_error("Malformed flag")
			else:
				key = flag_text.substr(0,index)
				value = flag_text.substr(index+1)
		else:
			key = flag_text
			value = true
		
		if FlagSchema.has(key):
			var schema = FlagSchema[key]
			match schema.type:
				
				TYPE_BOOL:
					if (typeof(value) == TYPE_BOOL and value) or value == 'true':
						value = true
					else:
						value = false
				TYPE_ARRAY:
					if not value in schema.values:
						_parser_error("Invalid flag option '%s' for flag %s" % [value,key])
				TYPE_STRING:
					pass # Nothing
				TYPE_FLOAT:
					value = value.to_float()
					if schema.has('min'):
						value = max(schema.min,value)
					if schema.has('max'):
						value = min(schema.max,value)
				_:
					pass
			flags[key] = value
		else:
			_parser_error("Unknown dialogue flag " + key)
	return flags

# Converts a markdown-esque syntax into bbcode
# Also parses events
func _strip_triggers_from_bbcode(bbcode:String) -> Dictionary:
	var result = {bbcode="",triggers={}}
	
	var raw_string_index = 0
	var displayed_string_index = 0
	
	bbcode = bbcode.replace('\\n','\n')
	
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
