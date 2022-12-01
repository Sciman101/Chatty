extends TextureButton

@onready var label_node = $Label

var label_text = ''

signal option_pressed(label)

func _ready():
	pressed.connect(_press_handler)

func set_option(option) -> void:
	visible = true
	label_node.text = option.prompt
	label_text = option.label

func _press_handler() -> void:
	option_pressed.emit(label_text)
