extends Node2D

@onready var sfx_fade_in = preload("res://sounds/jump.wav")
@onready var sfx_fade_out = preload("res://sounds/jump_backwards.wav")

@onready var graphic : Sprite2D = $Graphic
@onready var portrait : AnimatedSprite2D = $Graphic/Portrait
@onready var dialouge_label : RichTextLabel = $Graphic/Dialouge
@onready var tail : Sprite2D = $Graphic/Tail
@onready var timer : Timer = $Timer
@onready var fade_sfx : AudioStreamPlayer = $FadeInSound
@onready var talk_sfx : AudioStreamPlayer = $TalkSoundPlayer

const BUBBLE_MARGINS := Vector2(192/2 + 8,32 + 8)
const BUBBLE_TAIL_Y_OFFSET := 48
const BUBBLE_TAIL_X_LIMIT := 192/2 - 32

const DEFAULT_CHARACTER_DELAY := 0.05
const DEFAULT_SPEECH_DELAY := 1
const DEFAULT_SHOW_DURATION := 0.5

var character_delay := DEFAULT_CHARACTER_DELAY
var num_characters := 0
var parsed_dialouge := ""
var speaker = null

var is_presenting = false

func appear() -> void:
	graphic.visible = true
	
	var tween = get_tree().create_tween().set_parallel(true).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(graphic,'position',Vector2.ZERO,DEFAULT_SHOW_DURATION).from(Vector2(0,32))
	tween.tween_property(graphic,'modulate',Color.WHITE,DEFAULT_SHOW_DURATION).from(Color(1,1,1,0))
	tween.play()
	
	fade_sfx.stream = sfx_fade_in
	fade_sfx.play()
	
	await tween.finished

func disappear() -> void:
	var tween = get_tree().create_tween().set_parallel(true).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	tween.tween_property(graphic,'position',Vector2(0,32),DEFAULT_SHOW_DURATION).from(Vector2.ZERO)
	tween.tween_property(graphic,'modulate',Color(1,1,1,0),DEFAULT_SHOW_DURATION).from(Color.WHITE)
	tween.play()
	
	fade_sfx.stream = sfx_fade_out
	fade_sfx.play()
	
	await tween.finished
	graphic.visible = false

func appearImmediate() -> void:
	graphic.visible = true
	graphic.position = Vector2.ZERO
	graphic.modulate = Color.WHITE

func disappearImmediate() -> void:
	graphic.visible = false

func is_bubble_visible() -> bool:
	return graphic.visible

func set_dialouge(dialouge:String) -> void:
	dialouge_label.text = "[appear]"+dialouge
	parsed_dialouge = dialouge_label.get_parsed_text()
	num_characters = parsed_dialouge.length()
	_set_visible_characters(0)
	character_delay = DEFAULT_CHARACTER_DELAY

func set_speaker(new_speaker:Speaker) -> void:
	speaker = new_speaker
	portrait.frames = speaker
	portrait.animation = &'default'
	portrait.frame = 0
	portrait.stop()
	
	talk_sfx.stream = speaker.talksound

func set_dialouge_duration(duration:float) -> void:
	if duration > 0 and num_characters > 0:
		character_delay = duration / num_characters

func set_speaker_animation(anim:StringName) -> void:
	if speaker:
		if portrait.frames.has_animation(anim):
			portrait.animation = anim
		else:
			portrait.animation = &'default'
			push_warning("Unknown animation for speaker " + speaker.speaker_name + " '" + str(anim) + "'")
	else:
		push_warning("No active speaker!")

# Actually do the thing
func present(animate:bool=true,sfx:bool=true) -> void:
	
	is_presenting = true
	portrait.frame = 0
	if animate: portrait.play()
	_set_visible_characters(0)
	
	for i in range(num_characters):
		_set_visible_characters(i)
		
		if sfx and parsed_dialouge[i] != ' ':
			talk_sfx.play()
		
		timer.start(character_delay)
		await timer.timeout
	
	jump_to_end()
	
	# Wait a second
	timer.start(DEFAULT_SPEECH_DELAY)
	await timer.timeout

func jump_to_end() -> void:
	
	if not is_bubble_visible():
		appearImmediate()
	
	_set_visible_characters(-1)
	
	portrait.stop()
	portrait.frame = 0
	
	is_presenting = false

func set_bubble_position(target_pos:Vector2) -> void:
	target_pos.x = round(target_pos.x)
	target_pos.y = round(target_pos.y) - BUBBLE_TAIL_Y_OFFSET
	
	var rect = get_viewport_rect()
	
	position.x = clamp(
		target_pos.x,
		rect.position.x + BUBBLE_MARGINS.x,
		rect.end.x - BUBBLE_MARGINS.x
	)
	position.y = clamp(
		target_pos.y,
		rect.position.y + BUBBLE_MARGINS.y,
		rect.end.y - BUBBLE_MARGINS.y
	)
	
	var tail_x = target_pos.x - position.x
	tail.position.x = clamp(tail_x,-BUBBLE_TAIL_X_LIMIT,BUBBLE_TAIL_X_LIMIT)

func _set_visible_characters(num:int) -> void:
	dialouge_label.visible_characters = num
	dialouge_label.custom_effects[0].visible_characters = num
