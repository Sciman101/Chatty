@tool
extends RichTextEffect
class_name RichTextAppear

# Define the tag name.
var bbcode = "appear"

var visible_characters := -1

func _process_custom_fx(char_fx):
	
	if char_fx.range.x == visible_characters - 1:
		char_fx.offset.y -= 1
	
	return true
