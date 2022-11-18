extends Node

var PROJECT_TEMPLATE = ['name','version','start_script']
var SPEAKER_TEMPLATE = ['name','animations']
var ANIM_TEMPLATE = ['spritesheet','frames','fps']
var TALKSOUND_TEMPLATE = ['clips','pitch_variance']

# Public assets
var speakers = {}
var backgrounds = {}

var _project_dir : String
var _project

var _sprite_load_cache = {}

func _ready():
	_load_project("res://.test_project")

func _load_project(project_dir:String) -> void:
	_project_dir = project_dir
	_load_project_data()
	_load_backgrounds()
	_load_speakers()

func _load_project_data() -> void:
	var project = _read_jsonfile(_project_dir+"/chatty.json")
	if project:
		_validate_json(project,PROJECT_TEMPLATE)
		_project = project
		print("Loaded chatty.json!")
	else:
		_project_load_error("Can't read chatty.json!",true)

func _load_backgrounds() -> void:
	var bg_dir = _project_dir + "/backgrounds"
	var dir = DirAccess.open(bg_dir)
	if dir:
		backgrounds = {}
		print("Loading backgrounds")
		dir.list_dir_begin()
		var file_name = "z"
		while file_name != "":
			file_name = dir.get_next()
			if not dir.current_is_dir() and file_name != "":
				_load_background(file_name)
				
		dir.list_dir_end()
	else:
		_project_load_error("No backgrounds directory present!",false)

func _load_background(bg_file:String) -> void:
	var bg_path = _project_dir + "/backgrounds/" + bg_file
	var bg = _read_texture(bg_path)
	if bg:
		backgrounds[bg_file.get_basename()] = bg
		print("\tLoaded background " + bg_file)

func _load_speakers() -> void:
	var dir = DirAccess.open(_project_dir+"/speakers")
	if dir:
		speakers = {}
		
		dir.list_dir_begin()
		var file_name = "z"
		while file_name != "":
			file_name = dir.get_next()
			if dir.current_is_dir() and file_name != "":
				_load_speaker(file_name)
				
		dir.list_dir_end()
	else:
		_project_load_error("No speakers directory present!",true)

func _load_speaker(speaker_name:String) -> void:
	var speaker_path = _project_dir + "/speakers/" + speaker_name
	
	var data = _read_jsonfile(speaker_path+"/speaker.json")
	_validate_json(data,SPEAKER_TEMPLATE)
	
	var speaker = Speaker.new()
	speaker.speaker_name = data.name
	
	print("Loading speaker " + data.name)
	for anim_name in data.animations:
		_load_speaker_animation(speaker,anim_name,data.animations[anim_name],speaker_path)
	
	if data.has('talksound'):
		_load_speaker_talksound(speaker,data.talksound,speaker_path)
	
	speakers[speaker_name] = speaker
	print("Done!")

func _load_speaker_animation(speaker:Speaker,anim_name:String,anim:Dictionary,speaker_path:String) -> void:
	_validate_json(anim,ANIM_TEMPLATE)
	var atlas = _read_texture(speaker_path+"/"+anim.spritesheet)
	
	if anim_name != "default":
		speaker.add_animation(anim_name)
	speaker.set_animation_speed(anim_name,anim.fps)
	speaker.set_animation_loop(anim_name,true)
	
	var w = atlas.get_width() / 48
	var h = atlas.get_height() / 48
	
	var frames = anim.frames
	for frame in frames:
		frame = int(frame)
		var rect = Rect2(floor(frame % w) * 48,floor(frame/w) * 48,48,48)
		var at = AtlasTexture.new()
		at.atlas = atlas
		at.region = rect
		speaker.add_frame(anim_name,at)
	print("\tLoaded animation " + anim_name)

func _load_speaker_talksound(speaker:Speaker,talksound:Dictionary,speaker_path:String) -> void:
	_validate_json(talksound,TALKSOUND_TEMPLATE)
	
	var stream = AudioStreamRandomizer.new()
	stream.random_pitch = 1 + talksound.pitch_variance
	
	for clip in talksound.clips:
		var strm = _read_audio(speaker_path+"/"+clip)
		if strm:
			stream.add_stream(0)
			stream.set_stream(0,strm)
	print("Loaded " + str(stream.streams_count) + " talksounds")

func _project_load_error(message:String,fatal:bool=false) -> void:
	push_error(message)

func _read_texture(path:String) -> ImageTexture:
	if _sprite_load_cache.has(path):
		return _sprite_load_cache[path]
	var img = Image.new()
	img.load(path)
	var tex = ImageTexture.create_from_image(img)
	_sprite_load_cache[path] = tex
	return tex

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
	
	# Get filesize
	f.seek_end()
	var fsize = f.get_position() + 1
	f.seek(0)
	var bytes = f.get_buffer(fsize)
	
	var stream = null
	
	var extension = path.get_extension().to_lower()
	match extension:
		'wav':
			stream = AudioStreamWAV.new()
		'mp3':
			stream = AudioStreamMP3.new()
		'ogg':
			stream = AudioStreamOggVorbis.new()
	if stream:
		stream.set_data(bytes)
	return stream

func _validate_json(json:Dictionary,template:Array):
	for key in template:
		if not json.has(key):
			_project_load_error("Missing key %s" % [key],true)
			return
