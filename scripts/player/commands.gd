extends Node

# Define commands
var commands = {
	
	goto = {
		argc = 1,
		exec = _exec_goto
	},
	gotor = {
		vararg = true,
		exec = _exec_goto
	},
	
	wait = {
		argc = 1,
		exec = _exec_wait
	},
	
	appear = {
		vararg = true,
		exec = _exec_appear.bind(true)
	},
	disappear = {
		vararg = true,
		exec = _exec_appear.bind(false)
	},
	
	sound = {
		argc = 1,
		optionals = {
			'volume': 1,
			'pitch': 1,
			'async':false,
		},
		exec = _exec_sound
	},
	
	bg = {
		argc = 1,
		optionals = {
			'duration': 1,
			'animation': 'none',
			'transition': 'none',
			'async': false,
			'transition_mask': 'none'
		},
		exec = _exec_bg
	},
	
	music = {
		argc = 1,
		optionals = {
			'volume': 1,
			'pitch': 1,
			'fade_time': 0,
			'playback_start': 0,
			'align_playback': false,
			'async': false
		},
		exec = _exec_music
	},
	
	sprite = {
		argc = 2,
		optionals = {
			'id': '',
			'position': Vector2(160,128),
			'angle': 0,
			'depth': 0,
			'opacity': 1,
			'duration': 0,
			'transition': 'none',
			'async': false
		},
		exec = _exec_sprite
	}
}

func _ready():
	commands['return'] = {
		argc = 0,
		exec = _exec_return
	}

func _exec_goto(player,args,_optionals):
	if args.size() == 1:
		player._goto_label(args[0])
	else:
		var label = args[randi() % args.size()]
		player._goto_label(label)

func _exec_wait(player,args,_optionals):
	await get_tree().create_timer(args[0].to_float()).timeout

func _exec_appear(player,args,_optionals,visible):
	if args.size() == 1 and args[0] == 'now':
		if visible:
			player.speech_bubble.appearImmediate()
		else:
			player.speech_bubble.disappearImmediate()
	else:
		if visible:
			player.speech_bubble.appear()
		else:
			player.speech_bubble.disappear()

func _exec_sound(player,args,optionals):
	if AssetHandler.sounds.has(args[0]):
		var sound = AssetHandler.sounds[args[0]]
		var audio_player = AudioStreamPlayer.new()
		player.add_child(audio_player)
		audio_player.stream = sound
		audio_player.volume_db = linear_to_db(optionals.volume)
		audio_player.pitch_scale = optionals.pitch
		audio_player.finished.connect(audio_player.queue_free)
		audio_player.play()
		if not optionals.async:
			await audio_player.finished
	else:
		player._player_error("Trying to play unknown sound " + args[0])

func _exec_return(player,_args,_optionals):
	if player._return_stack.size() > 0:
		# Go back
		player.script_event_index = player._return_stack.pop_back()
	else:
		player._player_error("Nothing to return to!")

func _exec_bg(player,args,optionals):
	var bg_handler = player.bg_handler
	var target_bg_name = args[0]
	if optionals.async:
		bg_handler.set_background(target_bg_name,optionals)
	else:
		await bg_handler.set_background(target_bg_name,optionals)

func _exec_music(player,args,optionals):
	var music_handler = player.music_handler
	var target_music_name = args[0]
	if optionals.async:
		music_handler.set_music(target_music_name,optionals)
	else:
		await music_handler.set_music(target_music_name,optionals)

func _exec_sprite(player,args,optionals):
	var action = args[0]
	var sprite_identifier = args[1]
	var sprite_handler = player.sprite_handler
	
	if action == 'add':
		sprite_handler.add_sprite(sprite_identifier,optionals)
	elif action == 'remove':
		sprite_handler.remove_sprite(sprite_identifier,optionals)
	elif action == 'modify':
		if optionals.async:
			await sprite_handler.modify_sprite(sprite_identifier,optionals)
		else:
			sprite_handler.modify_sprite(sprite_identifier,optionals)
