extends Control

const DEFAULT_TRANSITION_DURATION := 1

@onready var current_bg : TextureRect = $CurrentBg
@onready var temp_bg : TextureRect = $TempBg
@onready var transitions : AnimationPlayer = $BackroundAnimations

var transition_types = {
	linear = Tween.TRANS_LINEAR,
	sine = Tween.TRANS_SINE,
	quint = Tween.TRANS_QUINT,
	quart = Tween.TRANS_QUART,
	quad = Tween.TRANS_QUAD,
	expo = Tween.TRANS_EXPO,
	elastic = Tween.TRANS_ELASTIC,
	cubic = Tween.TRANS_CUBIC,
	circ = Tween.TRANS_CIRC,
	bounce = Tween.TRANS_BOUNCE,
	back = Tween.TRANS_BACK
}
var ease_types = {
	'in': Tween.EASE_IN,
	'out': Tween.EASE_OUT,
	'inout': Tween.EASE_IN_OUT,
	'outin': Tween.EASE_OUT_IN,
}

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
	var transition = Tween.TRANS_LINEAR if args.size() < 4 else transition_types[args[3].to_lower()]
	var ease = Tween.EASE_IN if args.size() < 5 else ease_types[args[4].to_lower()]
	var async = false if args.size() < 6 else args[5] == 'async'
	
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
		transitions.play(animation)
		
		var tween = get_tree().create_tween()
		tween.tween_method(transitions.seek.bind(true),0.0,1.0,duration).set_ease(ease).set_trans(transition)
		if not async:
			await tween.finished
