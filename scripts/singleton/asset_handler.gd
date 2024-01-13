extends Node

var PROJECT_TEMPLATE = ['name','version','start_script']
var SPEAKER_TEMPLATE = ['name','animations']
var ANIM_TEMPLATE = ['spritesheet','frames','fps']
var TALKSOUND_TEMPLATE = ['clips','pitch_variance']

# Public assets
var speakers = {}
var backgrounds = {}
var scripts = {}
var sounds = {}
var music = {}
var sprites = {}

var defaults = {}

var start_script = null

var _project_dir : String
var _project

var _sprite_load_cache = {}

func load_project(project_dir:String) -> void:
	_project_dir = project_dir
	_load_project_data()
	# Clear
	speakers = {}
	backgrounds = {}
	scripts = {}
	sounds = {}
	
	_load_defaults()
	
	_load_from_folder('scripts',_load_script)
	_load_from_folder('speakers',_load_speaker,true)
	_load_from_folder('backgrounds',_load_background)
	_load_from_folder('sounds',_load_sound)
	_load_from_folder('music',_load_music)
	_load_from_folder('sprites',_load_sprite)
	
	Console.print("Looking for starting script '%s'" % _project.start_script)
	if not scripts.has(_project.start_script):
		_project_load_error("Start script is missing!")
	else:
		start_script = scripts[_project.start_script]

func _load_defaults() -> void:
	defaults.ui_atlas = load("res://graphics/ui/atlas/atlas_ui.png")

func _load_project_data() -> void:
	var project = _read_jsonfile(_project_dir+"/chatty.json")
	if project:
		_validate_json(project,PROJECT_TEMPLATE)
		_project = project
		Console.print("Loaded chatty.json!")
	else:
		_project_load_error("Can't read chatty.json!",true)

func _load_from_folder(folder_name:String,load_func:Callable,load_dirs:bool=false) -> void:
	var path = _project_dir + "/" + folder_name
	var dir = DirAccess.open(path)
	if dir:
		Console.print("Loading %s" % folder_name)
		dir.list_dir_begin()
		var file_name = "z"
		while file_name != "":
			file_name = dir.get_next()
			if (dir.current_is_dir() == load_dirs) and file_name != "":
				load_func.call(file_name)
				
		dir.list_dir_end()
	else:
		_project_load_error("No %s directory present!" % folder_name,true)

func _load_script(script_file:String) -> void:
	var script_path = _project_dir + "/scripts/" + script_file
	var script_text = _read_textfile(script_path)
	if script_text:
		Console.print("\tParsing script " + script_file)
		
		var parser = ChattyParser.new()
		var script_object = parser.parse_script(script_text)
		if parser.error:
			Console.print("\tError loading script! " + parser.error)
		else:
			scripts[script_file.get_basename()] = script_object
			Console.print("\tSuccess!")

func _load_background(bg_file:String) -> void:
	var bg_path = _project_dir + "/backgrounds/" + bg_file
	var bg = _read_texture(bg_path)
	if bg:
		backgrounds[bg_file.get_basename()] = bg
		Console.print("\tLoaded background " + bg_file)

func _load_sound(sound_file:String) -> void:
	var sound_path = _project_dir + "/sounds/" + sound_file
	var sound = _read_audio(sound_path)
	if sound:
		sounds[sound_file.get_basename()] = sound
		Console.print("\tLoaded sound " + sound_file)

func _load_music(sound_file:String) -> void:
	var sound_path = _project_dir + "/music/" + sound_file
	var sound = _read_audio(sound_path)
	if sound:
		music[sound_file.get_basename()] = sound
		Console.print("\tLoaded music " + sound_file)

func _load_sprite(sprite_name:String) -> void:
	var sprite_path = _project_dir + "/sprites/" + sprite_name
	var tex = _read_texture(sprite_path)
	if tex:
		sprites[sprite_name] = tex
		Console.print("\tLoaded sprite " + sprite_name)

func _load_speaker(speaker_name:String) -> void:
	var speaker_path = _project_dir + "/speakers/" + speaker_name
	
	var data = _read_jsonfile(speaker_path+"/speaker.json")
	_validate_json(data,SPEAKER_TEMPLATE)
	
	var speaker = Speaker.new()
	speaker.speaker_name = data.name
	
	Console.print("Loading speaker " + data.name)
	for anim_name in data.animations:
		_load_speaker_animation(speaker,anim_name,data.animations[anim_name],speaker_path)
	
	if data.has('talksound'):
		_load_speaker_talksound(speaker,data.talksound,speaker_path)
	
	if data.has('text_color'):
		speaker.text_color = Color.from_string(data.text_color.to_upper(),Color.BLACK)
	
	if data.has('ui_atlas_override'):
		speaker.ui_atlas_override = _read_texture(speaker_path+'/'+data.ui_atlas_override)
	
	speakers[speaker_name] = speaker
	Console.print("Done!")

func _load_speaker_animation(speaker:Speaker,anim_name:String,anim:Dictionary,speaker_path:String) -> void:
	_validate_json(anim,ANIM_TEMPLATE)
	var atlas = _read_texture(speaker_path+"/"+anim.spritesheet)
	
	if anim_name != "default":
		speaker.add_animation(anim_name)
	speaker.set_animation_speed(anim_name,anim.fps)
	
	speaker.set_animation_loop(anim_name,true)
	if anim.has('loop'):
		speaker.set_animation_loop(anim_name,anim.loop)
	
	if not atlas:
		_project_load_error("No atlas for animation " + anim_name)
		return
	
	var w = int(atlas.get_width()) / 48
	var h = int(atlas.get_height()) / 48
	
	var frames = anim.frames
	for frame in frames:
		frame = int(frame)
		var rect = Rect2(floor(frame % w) * 48,floor(frame/w) * 48,48,48)
		var at = AtlasTexture.new()
		at.atlas = atlas
		at.region = rect
		speaker.add_frame(anim_name,at)
	Console.print("\tLoaded animation " + anim_name)

func _load_speaker_talksound(speaker:Speaker,talksound:Dictionary,speaker_path:String) -> void:
	_validate_json(talksound,TALKSOUND_TEMPLATE)
	
	var stream = AudioStreamRandomizer.new()
	stream.random_pitch = 1 + talksound.pitch_variance
	
	speaker.voice_mode = Speaker.VoiceMode.PER_CHAR
	if talksound.has('mode'):
		var mode = talksound.mode.to_lower()
		match mode:
			'character': pass
			'wait': speaker.voice_mode = Speaker.VoiceMode.WAIT
			'once': speaker.voice_mode = Speaker.VoiceMode.ONCE
			_: _project_load_error("Unknown talksound mode " + mode)
	
	for clip in talksound.clips:
		var strm = _read_audio(speaker_path+"/"+clip)
		if strm:
			stream.add_stream(0)
			stream.set_stream(0,strm)
	speaker.talksound = stream
	Console.print("\tLoaded " + str(stream.streams_count) + " talksounds")

func _project_load_error(message:String,fatal:bool=false) -> void:
	Console.error(message)

func _read_texture(path:String) -> ImageTexture:
	if _sprite_load_cache.has(path):
		return _sprite_load_cache[path]
	var img = Image.new()
	if img.load(path) == OK:
		var tex = ImageTexture.create_from_image(img)
		_sprite_load_cache[path] = tex
		return tex
	else:
		_project_load_error("Cannot find file " + path)
		return null

func _read_textfile(path:String):
	var f = FileAccess.open(path,FileAccess.READ)
	if f:
		var text = ""
		while not f.eof_reached():
			text += f.get_line() + "\n"
		return text
	else:
		return false

func _read_jsonfile(path:String):
	var text = _read_textfile(path)
	if text:
		return JSON.parse_string(text)
	else:
		return false

func _read_audio(path:String) -> AudioStream:
	var f = FileAccess.open(path,FileAccess.READ)
	if not f:
		_project_load_error("Error loading sound file " + path)
		return null
	
	var bytes = f.get_buffer(f.get_length())
	var stream = null
	
	var extension = path.get_extension().to_lower()
	match extension:
		'wav':
			stream = AudioStreamWAV.new()
			
			# Strip out the wav header
			var header = bytes.slice(0,44)
			
			# Get actual data
			var audio_data_size = header[40] + (header[41] << 8) + (header[42] << 16) + (header[43] << 32)
			bytes = bytes.slice(44, 44 + audio_data_size - 1)
			
			stream.set_data(bytes)
			
			stream.mix_rate = header[24] + (header[25] << 8) + (header[26] << 16) + (header[27] << 32)
			
			var bps = header[34] + (header[35] << 8)
			match bps:
				8:
					stream.format = AudioStreamWAV.FORMAT_8_BITS
				16:
					stream.format = AudioStreamWAV.FORMAT_16_BITS
				32:
					stream.format = AudioStreamWAV.FORMAT_IMA_ADPCM
			
			stream.stereo = (header[22] + (header[23] << 8)) == 2
		'mp3':
			stream = AudioStreamMP3.new()
			stream.set_data(bytes)
		_:
			_project_load_error("Unsupported file type, " + extension)
			return null
	f = null
	return stream

func _validate_json(json:Dictionary,template:Array):
	for key in template:
		if not json.has(key):
			_project_load_error("Missing key %s" % [key],true)
			return
