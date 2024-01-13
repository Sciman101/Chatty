extends Object
class_name ChattyScript

var events = [] # List of events in order
var label_indices = {} # Table of label/event index pairs
var raw_text : String = ""

func add_event(event) -> void:
	events.append(event)
func add_label(label_text) -> void:
	label_indices[label_text] = events.size()

func size() -> int: return events.size()

func debug_string() -> String:
	return "====\nChattyScript:\nEvents: %s\nLabels: %s\n====" % [events,label_indices]
