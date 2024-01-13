extends Node2D

@onready var sfx_fade_in = preload("res://sounds/speechbubble_appear.wav")
@onready var sfx_fade_out = preload("res://sounds/speechbubble_disappear.wav")

@onready var ui_atlas_redirect_texture = preload("res://graphics/ui/atlas/atlas_ui_redirect.tres")

@onready var tex_default = preload("res://graphics/ui/ui_speechbubble_default.tres")
@onready var tex_wide = preload("res://graphics/ui/ui_speechbubble_wide.tres")

@onready var graphic : Sprite2D = $Graphic
@onready var portrait : AnimatedSprite2D = $Graphic/Portrait
@onready var advance_arrow : AnimatedSprite2D = $Graphic/AdvanceArrow
@onready var dialouge_label : RichTextLabel = $Graphic/Dialouge

@onready var speaker_name_container := $Graphic/SpeakerNameBadge

@onready var timer : Timer = $Timer
@onready var fade_sfx : AudioStreamPlayer = $FadeInSound
@onready var talk_sfx : AudioStreamPlayer = $TalkSoundPlayer

const BUBBLE_MARGINS := Vector2(192/2 + 8,32 + 8)

const DEFAULT_CHARACTER_DELAY := 0.05
const DEFAULT_SPEECH_DELAY := 0.2
const DEFAULT_SHOW_DURATION := 0.5

var num_characters := 0
var parsed_dialouge := ""
var speaker = null

var skip_event := false
var talk_speed_multiplier := 1.0
var instant_text = false

var is_presenting = false

func appear() -> void:
	graphic.visible = true
	advance_arrow.visible = false
	
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
	dialouge_label.text = ''

func appearImmediate() -> void:
	graphic.visible = true
	advance_arrow.visible = false
	graphic.position = Vector2.ZERO
	graphic.modulate = Color.WHITE

func disappearImmediate() -> void:
	dialouge_label.text = ''
	graphic.visible = false

func is_bubble_visible() -> bool:
	return graphic.visible

# Listen for click so we can skip
func _input(event):
	if Input.is_action_just_pressed("advance_dialouge"):
		skip_event = true

# Actually do the thing
func present(event) -> void:
	# Reset
	skip_event = false
	
	if event.type != &'dialouge':
		Console.error('Attempting to run a non-dialouge event on a speech bubble!')
		return
	
	advance_arrow.visible = false
	is_presenting = true
	_set_visible_characters(0)
	
	# Set time from args
	var time = event.flags.get('duration',DEFAULT_CHARACTER_DELAY*num_characters)
	var character_delay = max(0.01,time/num_characters)
	
	talk_speed_multiplier = event.flags.get('speed',1)
	instant_text = false
	
	# Other flags
	if not event.flags.get('noanim',false):
		portrait.play()
	var play_sound = not event.flags.get('nosound',false)
	
	talk_sfx.pitch_scale = event.flags.get('pitch',1)
	talk_sfx.volume_db = linear_to_db(event.flags.get('volume',1))
	
	# Play once
	if speaker.voice_mode == Speaker.VoiceMode.ONCE and play_sound:
		play_sound = false
		talk_sfx.play()
	
	var triggers = event.triggers
	
	for i in range(num_characters):
		
		if triggers.has(i):
			await _handle_trigger(triggers[i])
		
		# If we're told to skip, end the event
		if skip_event and i > 1:
			skip_event = false
			break
		
		_set_visible_characters(i)
		
		if play_sound and parsed_dialouge[i] != ' ':
			if not (speaker.voice_mode == Speaker.VoiceMode.WAIT and talk_sfx.playing):
				talk_sfx.play()
		
		if not instant_text:
			if talk_speed_multiplier == 0: talk_speed_multiplier = 0.01
			timer.start(character_delay / talk_speed_multiplier)
			await timer.timeout
	
	jump_to_end()
	
	if speaker.voice_mode == Speaker.VoiceMode.WAIT and talk_sfx.playing:
		talk_sfx.stop()
	
	# Wait a second
	if not event.flags.get('skip',false):
		timer.start(DEFAULT_SPEECH_DELAY)
		await timer.timeout
		advance_arrow.visible = true

func _handle_trigger(trigger) -> void:
	match trigger[0]:
		'pause':
			var was_playing = portrait.playing
			portrait.stop()
			portrait.frame = 0
			timer.start(trigger[1].to_float())
			await timer.timeout
			if was_playing:
				portrait.play()
		
		'speed':
			instant_text = false
			if trigger.size() >= 2:
				talk_speed_multiplier = clamp(trigger[1].to_float(),0.01,10)
		
		'pitch':
			if trigger.size() >= 2:
				talk_sfx.pitch_scale = clamp(trigger[1].to_float(),0.0,2.0)
			
		'volume':
			if trigger.size() >= 2:
				talk_sfx.volume_db = linear_to_db(clamp(trigger[1].to_float(),0.0,1.0))
		
		'instant':
			instant_text = true
		
		'animation':
			if trigger.size() >= 2:
				var anim_name = trigger[1]
				set_speaker_animation(anim_name)

func set_dialouge(dialouge:String) -> void:
	if speaker.text_color:
		dialouge = '[color=%s]%s' % [speaker.text_color.to_html(),dialouge]
	dialouge_label.text = dialouge
	parsed_dialouge = dialouge_label.get_parsed_text()
	num_characters = parsed_dialouge.length()
	_set_visible_characters(0)

func set_speaker(new_speaker) -> bool:
	if AssetHandler.speakers.has(new_speaker):
		new_speaker = AssetHandler.speakers[new_speaker]
	else:
		return false
	
	speaker = new_speaker
	portrait.frames = speaker
	portrait.animation = &'default'
	portrait.frame = 0
	portrait.stop()
	
	talk_sfx.stream = speaker.talksound
	
	set_speaker_name(speaker.speaker_name,speaker.text_color)
	
	# Change ui atlas
	if speaker.ui_atlas_override:
		ui_atlas_redirect_texture.atlas = speaker.ui_atlas_override
	else:
		ui_atlas_redirect_texture.atlas = AssetHandler.defaults.ui_atlas
	
	return true

func set_speaker_name(name:String,color:Color=Color.BLACK) -> void:
	speaker_name_container.set_name_display(name,color)

func set_speaker_animation(anim:StringName=&'default') -> void:
	if anim == &'': anim = &'default'
	if speaker:
		if portrait.frames.has_animation(anim):
			portrait.animation = anim
		else:
			portrait.animation = &'default'
			push_warning("Unknown animation for speaker " + speaker.speaker_name + " '" + str(anim) + "'")
	else:
		push_warning("No active speaker!")

func set_frame(frame:int) -> void:
	portrait.frame = frame

func set_wide(wide:bool) -> void:
	graphic.texture = tex_wide if wide else tex_default
	portrait.visible = !wide
	if wide: portrait.stop()
	
	dialouge_label.position.x = -70 if not wide else -122
	dialouge_label.size.x = 192 if not wide else 244

func jump_to_end() -> void:
	
	if not is_bubble_visible():
		appearImmediate()
	
	_set_visible_characters(-1)
	
	if portrait.playing:
		portrait.stop()
		portrait.frame = 0
	
	is_presenting = false

func set_bubble_position(target_pos:Vector2) -> void:
	target_pos.x = round(target_pos.x)
	target_pos.y = round(target_pos.y)
	
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

func _set_visible_characters(num:int) -> void:
	dialouge_label.visible_characters = num
