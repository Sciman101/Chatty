extends CanvasLayer

const MESSAGE_FADE_DURATION := 1.0
const MESSAGE_FADE_DELAY := 2.0
const ConsoleMessage = preload("res://scene/console_message.tscn")

@onready var message_list = $Contents/List
@onready var scroll = $Contents

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

func _input(event):
	if Input.is_action_just_pressed("toggle_console"):
		visible = not visible

func _push_message(text:String,color:Color) -> void:
	print(text)
	
	var at_beginning = scroll.scroll_vertical == 0
	
	var inst = ConsoleMessage.instantiate()
	message_list.add_child(inst)
	message_list.move_child(inst,0)
	
	var label = inst.get_node("Label")
	label.text = text
	label.modulate = color
	
	if at_beginning:
		scroll.scroll_vertical = 0
	
	#var tween = get_tree().create_tween()
	#tween.tween_property(inst,'modulate',Color(1,1,1,0),MESSAGE_FADE_DURATION).set_delay(MESSAGE_FADE_DELAY)
	#tween.tween_callback(inst.queue_free)

func _on_clear_button_pressed():
	for n in message_list.get_children():
		n.queue_free()
