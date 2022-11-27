extends Node

const VALID_FLAGS = {
	'pos':['bottom','right','left','center','top'],
	't':[0.01,1000],
	'noanim':[true,false],
	'nosound':[true,false],
	'wide':[true,false],
	'skip':[true,false]
}

const MD_TO_BBCODE = {
	'*': 'b',
	'^': 'wave',
	'_': 'u',
	'~': 's'
}

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
	var lines = Array(script_text.split('\n')).map(func(s): return s.strip_edges())
	var script = ChattyScript.new()
	script.raw_text = script_text
	choice_queue = []
	
	line_num = 0
	for line in lines:
		_parse_line(line,script)
		line_num += 1
	
	# Add choice event
	_resolve_choice_event(script)
	
	return script

func _parser_error(message:String) -> void:
	push_error(message + " @ line " + str(line_num))

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
	
	if line.begins_with('?'):
		# Add choice
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
	else:
		# Add choice event
		_resolve_choice_event(script)
	
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
		
		else:
			# Dialouge line
			# Format: [name]:[dialouge]
			var colon_index = line.find(':')
			if colon_index == -1:
				_parser_error("Malformed dialouge line")
			else:
				var params_string = line.substr(0,colon_index).strip_edges()
				
				# Extract params
				var comma_index = params_string.find(',')
				var bracket_index = params_string.find('[')
				
				var speaker_name = ''
				var animation_name = ''
				var flags = []
				if comma_index != -1 and (comma_index < bracket_index or bracket_index == -1):
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
				var result = _markdownish_to_bbcode(dialouge)
				
				var event = {
					'type': &'dialouge',
					'speaker': speaker_name,
					'animation_name': animation_name,
					'flags': _parse_flags(flags),
					'dialouge': result.bbcode,
					'triggers': result.triggers
				}
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
			if accepted[0] is float:
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
func _markdownish_to_bbcode(md:String) -> Dictionary:
	var result = {bbcode="",triggers={}}
	var final_index = 0
	var index = 0
	
	var open_tags = {}
	
	while index < md.length():
		var c = md[index]
		
		# Escape character
		if index != md.length() - 1 and c == '\\' and md[index+1] in MD_TO_BBCODE:
			result.bbcode += md[index+1]
			index += 1
		
		elif c in MD_TO_BBCODE:
			if open_tags.has(c) and open_tags[c]:
				result.bbcode += '[/%s]' % MD_TO_BBCODE[c]
				open_tags[c] = false
			else:
				# Mak tag as open
				result.bbcode += '[%s]' % MD_TO_BBCODE[c]
				open_tags[c] = true
		
		elif c == '<':
			
			var i = index
			while i < md.length() and md[i] != '>': i += 1
			if md[i] != '>':
				_parser_error("Unclosed dialouge event")
			
			var event_def = md.substr(index+1,i-index-1).strip_edges().split(' ')
			result.triggers[final_index] = event_def
			
			index = i
			
		else:
			result.bbcode += c
			final_index += 1
		
		index = index + 1
	
	return result
