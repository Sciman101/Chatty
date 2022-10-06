@tool
extends RichTextEffect
class_name RichTextGlitch

# Define the tag name.
var bbcode = "glitch"

func _process_custom_fx(char_fx):
	char_fx.glyph_index += randi_range(-2,2)
	char_fx.offset.y += randi_range(-1,1)
	return true
