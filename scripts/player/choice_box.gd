extends Node2D

const MAX_OPTIONS := 8

@onready var ButtonScene = preload("res://scene/option_button.tscn")
var buttons = []

var presenting = false

signal on_choice_made(label)

# Called when the node enters the scene tree for the first time.
func _ready():
	var list = $OptionList
	for i in range(MAX_OPTIONS):
		var btn = ButtonScene.instantiate()
		buttons.append(btn)
		list.add_child(btn)
		btn.option_pressed.connect(_on_button_pressed)
		btn.visible = false
	visible = false

func present_choice(event) -> void:
	if not presenting:
		presenting = true
		visible = true
		_hide_all_buttons()
		for i in range(min(event.options.size(),MAX_OPTIONS)):
			var btn = buttons[i]
			btn.set_option(event.options[i])

func _hide_all_buttons() -> void:
	for btn in buttons: btn.visible = false

func _on_button_pressed(label) -> void:
	if presenting:
		on_choice_made.emit(label)
		presenting = false
		visible = false
