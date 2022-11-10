extends Control

const DEFAULT_TRANSITION_DURATION := 1

@onready var current_bg : TextureRect = $CurrentBg
@onready var temp_bg : TextureRect = $TempBg
@onready var transitions : AnimationPlayer = $BackroundAnimations

func _ready():
	current_bg.position = Vector2.ZERO
	temp_bg.position = Vector2.ZERO
	current_bg.modulate = Color.WHITE
	temp_bg.modulate = Color.WHITE
	temp_bg.visible = false

func transition_background(args) -> void:
	
	var next = '' if args.size() < 1 else args[0]
	var animation = '' if args.size() < 2 else args[1]
	var duration = -1 if args.size() < 3 else args[2].to_float()
	var async = false if args.size() < 4 else args[3] == 'async'
	
	if next == '': return
	
	temp_bg.texture = current_bg.texture
	temp_bg.visible = false
	temp_bg.modulate = Color.WHITE
	temp_bg.position = Vector2.ZERO
	
	if AssetHandler.backgrounds.has(next):
		current_bg.texture = AssetHandler.backgrounds[next]
	else:
		push_error("No such background '%s'!" % [next])
		return
	
	if animation != '':
		if duration <= 0: duration = 1
		temp_bg.visible = true
		transitions.playback_speed = 1.0/duration
		transitions.play(animation)
		if not async:
			await transitions.animation_finished
