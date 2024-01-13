extends Control

const TRANSITIONS = {
	'linear': Tween.TRANS_LINEAR,
	'sine': Tween.TRANS_SINE,
	'quint': Tween.TRANS_QUINT,
	'quart': Tween.TRANS_QUART,
	'quad': Tween.TRANS_QUAD,
	'expo': Tween.TRANS_EXPO,
	'elastic': Tween.TRANS_ELASTIC,
	'cubic': Tween.TRANS_CUBIC,
	'circ': Tween.TRANS_CIRC,
	'bounce': Tween.TRANS_BOUNCE,
	'back': Tween.TRANS_BACK
}
const EASES = {
	'in': Tween.EASE_OUT,
	'out': Tween.EASE_IN,
	'inout': Tween.EASE_IN_OUT,
	'outin': Tween.EASE_OUT_IN,
}

var ANIMATIONS = {
	'fade': _anim_fade,
	'fade-zoomin': _anim_zoom_fade.bind(2),
	'fade-zoomout': _anim_zoom_fade.bind(0.5),
	
	'slide-right': _anim_slide.bind(Vector2.RIGHT),
	'slide-left': _anim_slide.bind(Vector2.LEFT),
	'slide-up': _anim_slide.bind(Vector2.UP),
	'slide-down': _anim_slide.bind(Vector2.DOWN),
	
	'uncover-right': _anim_uncover.bind(Vector2.RIGHT),
	'uncover-left': _anim_uncover.bind(Vector2.LEFT),
	'uncover-up': _anim_uncover.bind(Vector2.UP),
	'uncover-down': _anim_uncover.bind(Vector2.DOWN),
	
	'cover-right': _anim_cover.bind(Vector2.RIGHT),
	'cover-left': _anim_cover.bind(Vector2.LEFT),
	'cover-up': _anim_cover.bind(Vector2.UP),
	'cover-down': _anim_cover.bind(Vector2.DOWN),
	
	'custom': _anim_shader
}

@onready var current_bg : TextureRect = $CurrentBg
@onready var temp_bg : TextureRect = $TempBg
@onready var player = get_parent()

var tween = null
var _cached_color_bgs = {}

func _ready():
	temp_bg.visible = false
	current_bg.visible = true

func set_background(bg_name:String,options:Dictionary) -> void:
	# Get background texture
	var bg = _get_background(bg_name)
	if bg != null:
		if options.duration == 0 or options.animation == 'none':
			current_bg.texture = bg
		else:
			# We need to animate the bg
			if ANIMATIONS.has(options.animation):
				_prep_bgs()
				var trans = _get_transition_values(options.transition)
				current_bg.texture = bg
				if tween != null and tween.is_running():
					tween.kill()
				if options.animation == 'custom':
					if options.transition_mask == 'none':
						player._player_error("No transition texture specified!")
					else:
						# load texture
						var tex = AssetHandler.backgrounds.get(options.transition_mask,null)
						if tex:
							temp_bg.material.set_shader_parameter('transition_texture',tex)
						else:
							player._player_error("Unknown transition texture '%s'" % options.transition_mask)
					
				await ANIMATIONS[options.animation].call(options.duration,trans[0],trans[1])
			else:
				player._player_error("Unknown background animation '%s'" % bg_name)
				current_bg.texture = bg
			
	else:
		player._player_error("Unknown background '%s'" % bg_name)


# == ANIMATIONS ==
func _anim_fade(duration,trans,ease):
	tween = get_tree().create_tween().set_trans(trans).set_ease(ease)
	tween.tween_property(temp_bg,'modulate',Color(1,1,1,0),duration)
	await tween.finished

func _anim_zoom_fade(duration,trans,ease,zoom):
	tween = get_tree().create_tween().set_trans(trans).set_ease(ease).set_parallel(true)
	tween.tween_property(temp_bg,'modulate',Color(1,1,1,0),duration)
	tween.tween_property(temp_bg,'scale',Vector2.ONE * zoom,duration)
	await tween.finished

func _anim_slide(duration,trans,ease,direction):
	current_bg.position = -direction * Vector2(320,256)
	tween = get_tree().create_tween().set_trans(trans).set_ease(ease).set_parallel(true)
	tween.tween_property(temp_bg,'position',direction * Vector2(320,256),duration)
	tween.tween_property(current_bg,'position',Vector2.ZERO,duration)
	await tween.finished

func _anim_uncover(duration,trans,ease,direction):
	tween = get_tree().create_tween().set_trans(trans).set_ease(ease)
	tween.tween_property(temp_bg,'position',direction * Vector2(320,256),duration)
	await tween.finished

func _anim_cover(duration,trans,ease,direction):
	_swap_bgs()
	temp_bg.position = -direction * Vector2(320,256)
	tween = get_tree().create_tween().set_trans(trans).set_ease(ease)
	tween.tween_property(temp_bg,'position',Vector2.ZERO,duration)
	await tween.finished
	_swap_bgs()
	_prep_bgs()

func _anim_shader(duration,trans,ease):
	tween = get_tree().create_tween().set_trans(trans).set_ease(ease)
	tween.tween_method(_set_shader_progress,0.0,1.0,duration)
	await tween.finished

# == HELPERS ==
func _set_shader_progress(amt:float) -> void:
	temp_bg.material.set_shader_parameter('transition_amount',amt)

func _prep_bgs():
	temp_bg.visible = true
	current_bg.visible = true
	temp_bg.scale = Vector2.ONE
	current_bg.scale = Vector2.ONE
	current_bg.modulate = Color.WHITE
	temp_bg.modulate = Color.WHITE
	current_bg.position = Vector2.ZERO
	temp_bg.position = Vector2.ZERO
	temp_bg.texture = current_bg.texture
	temp_bg.material.set_shader_parameter('transition_amount',0)

func _swap_bgs() -> void:
	var temp = temp_bg.texture
	temp_bg.texture = current_bg.texture
	current_bg.texture = temp

func _get_background(bgname:String):
	if AssetHandler.backgrounds.has(bgname):
		return AssetHandler.backgrounds[bgname]
	elif Color.find_named_color(bgname) != -1:
		if _cached_color_bgs.has(bgname):
			return _cached_color_bgs[bgname]
		# Create a gradient texture
		var color = Color.get_named_color(Color.find_named_color(bgname))
		var bg = GradientTexture1D.new()
		bg.width = 1
		var gradient = Gradient.new()
		gradient.add_point(0,color)
		bg.gradient = gradient
		_cached_color_bgs[bgname] = bg
		return bg
	else:
		return null

func _get_transition_values(transition_string:String) -> Array:
	if transition_string == 'none':
		return [Tween.TRANS_LINEAR,Tween.EASE_OUT]
	
	var trans_name = 'linear'
	var ease_name = 'out'
	
	var hyphen_index = transition_string.find('-')
	if hyphen_index != -1 and hyphen_index != len(transition_string)-1:
		trans_name = transition_string.substr(0,hyphen_index).to_lower()
		ease_name = transition_string.substr(hyphen_index+1).to_lower()
	else:
		trans_name = transition_string
	
	if not TRANSITIONS.has(trans_name) or not EASES.has(ease_name):
		player._player_error("Unknown transition " + transition_string)
		return [Tween.TRANS_LINEAR,Tween.EASE_IN]
	
	return [TRANSITIONS[trans_name],EASES[ease_name]]
