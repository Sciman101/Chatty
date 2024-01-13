extends CanvasLayer

@onready var label = $Messages

func _ready():
	visible = false

func print(message:String):
	_push_message(message,Color.WHITE)

func warn(message:String):
	_push_message(message,Color.YELLOW)

func error(message:String):
	visible = true
	push_error(message)
	_push_message(message,Color.RED)

func _input(_event):
	if Input.is_action_just_pressed("toggle_console"):
		visible = not visible

func _push_message(text:String,color:Color) -> void:
	
	label.text += '[color=%s]%s\n' % [color.to_html(),text]
	
	#var tween = get_tree().create_tween()
	#tween.tween_property(inst,'modulate',Color(1,1,1,0),MESSAGE_FADE_DURATION).set_delay(MESSAGE_FADE_DELAY)
	#tween.tween_callback(inst.queue_free)

func _on_clear_button_pressed():
	label.text = ""
