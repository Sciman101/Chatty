extends Node

class ChattyScript:
	var events = []
	var label_indices = {}
	
	func add_event(event) -> void:
		events.append(event)

func compile_script(script_text:String) -> ChattyScript:
	var lines = Array(script_text.split('\n')).map(func(s): return s.trim_edges())
	var script = ChattyScript.new()
	
	var line_num := 0
	for line in lines:
		_parse_line(line,line_num,script)
		line_num += 1
	
	return script

func _parse_line(line:String,line_num:int,script:ChattyScript) -> void:
	
	if line.begins_with('(') and line.ends_with(')'):
		pass # Do nothing. comment
	
	elif line.begins_with('#'):
		# Label
		var label_name = line.substr(1).strip_edges()
		script.label_indices[label_name] = script.events.size()
		var event = {
			'type':&'label'
		}
		script.add_event(event)
	
	elif line.begins_with('>'):
		# Command
		pass
	
	else:
		# Dialouge
		pass
	
