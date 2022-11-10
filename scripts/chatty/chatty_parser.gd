extends Node

class ChattyScript:
	var events = []
	var label_indices = {}
	
	func add_event(event) -> void:
		events.append(event)
	func add_label(label_text) -> void:
		label_indices[label_text] = events.size()
	
	func size() -> int: return events.size()
	
	func debug_string() -> String:
		return "====\nChattyScript:\nEvents: %s\nLabels: %s\n====" % [events,label_indices]

func compile_script(script_text:String) -> ChattyScript:
	var lines = Array(script_text.split('\n')).map(func(s): return s.strip_edges())
	var script = ChattyScript.new()
	
	var line_num := 0
	for line in lines:
		_parse_line(line,line_num,script)
		line_num += 1
	
	return script

func _parser_error(message:String,line_num:int) -> void:
	push_error(message + " @ line " + str(line_num))

func _parse_line(line:String,line_num:int,script:ChattyScript) -> void:
	
	if line.begins_with('(') and line.ends_with(')'):
		pass # Do nothing. comment
	
	elif line.length() == 0:
		pass # Empty line. do nothing
	
	elif line.begins_with('#'):
		# Label
		var label_name = line.substr(1).strip_edges()
		script.add_label(label_name)
		var event = {
			'type':&'label'
		}
		script.add_event(event)
	
	elif line.begins_with('>'):
		# Command
		var args = line.substr(1).split(' ')
		var cmd_name = args[0]
		args = args.slice(1)
		var event = {
			'type':&'command',
			'cmd_name': cmd_name,
			'args': args
		}
		script.add_event(event)
		pass
	
	elif line.begins_with('?'):
		# Selection
		# Format: TBD
		pass
	
	else:
		# Dialouge line
		# Format: [name]:[dialouge]
		var colon_index = line.find(':')
		if colon_index == -1:
			_parser_error("Malformed dialouge line",line_num)
		else:
			var params_string = line.substr(0,colon_index).strip_edges()
			
			# Extract params
			var comma_index = params_string.find(',')
			var bracket_index = params_string.find('[')
			
			var speaker_name = ''
			var animation_name = ''
			var flags = []
			if comma_index != -1:
				if comma_index != 0:
					speaker_name = params_string.substr(0,comma_index).strip_edges(false)
				if bracket_index != -1:
					animation_name = params_string.substr(comma_index+1,bracket_index-comma_index-1).strip_edges()
				else:
					animation_name = params_string.substr(comma_index+1).strip_edges(true,false)
			elif bracket_index != -1:
				speaker_name = params_string.substr(0,bracket_index).strip_edges(false)
			else:
				speaker_name = params_string
			
			if bracket_index != -1:
				if params_string[len(params_string)-1] != ']':
					# parse error
					pass
				flags = params_string.substr(bracket_index+1,len(params_string)-bracket_index-2).strip_edges().split(',')
			
			var dialouge = line.substr(colon_index+1).strip_edges()
			
			var event = {
				'type': &'dialouge',
				'speaker': speaker_name,
				'animation_name': animation_name,
				'flags': _parse_flags(flags),
				'dialouge': dialouge
			}
			script.add_event(event)

func _parse_flags(flag_list:Array) -> Dictionary:
	var flags = {}
	for f in flag_list:
		f = f.strip_edges()
		var equals_index = f.find('=')
		if equals_index == -1:
			flags[f] = true
		else:
			var key = f.substr(0,equals_index).strip_edges()
			var val = f.substr(equals_index+1).strip_edges()
			flags[key] = val
	return flags
