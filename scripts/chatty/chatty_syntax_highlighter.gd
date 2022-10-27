@tool
extends SyntaxHighlighter
class_name ChattySyntaxHighlighter


func _get_line_syntax_highlighting(line_num:int) -> Dictionary:
	
	var line = get_text_edit().text.split('\n')[line_num].strip_edges()
	
	if line.length() > 0:
		if line[0] == '#':
			return {0:{color = Color.ORANGE}}
		elif line[0] == '(':
			return {0:{color = Color.GRAY}}
		elif line[0] == '>':
			
			var space_index = line.find(' ')
			var highlight = {0:{color = Color.YELLOW}}
			if space_index > 0:
				highlight[space_index] = {color = Color.CADET_BLUE}
			
			return highlight
		else:
			# Dialouge highlighting
			if line.find(':') == -1:
				return {0:{color=Color.WHITE}}
			else:
				var colon_index = line.find(':')
				var highlight = {0:{color=Color.DARK_SEA_GREEN},colon_index+1:{color=Color.WHITE}}
				var bracket_index = line.find('[')
				if bracket_index != -1 and bracket_index < colon_index:
					highlight[bracket_index] = {color=Color.CADET_BLUE}
				return highlight
	else:
		return {}
