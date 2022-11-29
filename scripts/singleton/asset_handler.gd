extends Node

var PROJECT_TEMPLATE = ['name','version','start_script']
var SPEAKER_TEMPLATE = ['name','animations']
var ANIM_TEMPLATE = ['spritesheet','frames','fps']
var TALKSOUND_TEMPLATE = ['clips','pitch_variance']

# Public assets
var speakers = {}
var backgrounds = {}
var scripts = {}

var start_script = null

var _project_dir : String
var _project

var _sprite_load_cache = {}

func _ready():
	var project_path = "res://.chatty_project"
	if OS.has_feature('standalone'):
		project_path = OS.get_executable_path().get_base_dir() + "/project"
	_load_project(project_path)

func _load_project(project_dir:String) -> void:
	_project_dir = project_dir
	_load_project_data()
	# Clear
	speakers = {}
	backgrounds = {}
	scripts = {}
	
	_load_from_folder('scripts',_load_script)
	_load_from_folder('speakers',_load_speaker,true)
	_load_from_folder('backgrounds',_load_background)
	
	print("Looking for starting script '%s'" % _project.start_script)
	if not scripts.has(_project.start_script):
		print("Start script is missing!")
	else:
		start_script = scripts[_project.start_script]

func _load_project_data() -> void:
	var project = _read_jsonfile(_project_dir+"/chatty.json")
	if project:
		_validate_json(project,PROJECT_TEMPLATE)
		_project = project
		print("Loaded chatty.json!")
	else:
		_project_load_error("Can't read chatty.json!",true)

func _load_from_folder(folder_name:String,load_func:Callable,load_dirs:bool=false) -> void:
	var path = _project_dir + "/" + folder_name
	var dir = DirAccess.open(path)
	if dir:
		print("Loading %s" % folder_name)
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
		print("\tParsing script " + script_file)
		var script_object = ChattyParser.compile_script(script_text)
		if ChattyParser.error:
			print("\tError loading script! " + ChattyParser.error)
		else:
			scripts[script_file.get_basename()] = script_object
			print("\tSuccess!")
	

func _load_background(bg_file:String) -> void:
	var bg_path = _project_dir + "/backgrounds/" + bg_file
	var bg = _read_texture(bg_path)
	if bg:
		backgrounds[bg_file.get_basename()] = bg
		print("\tLoaded background " + bg_file)

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
	
	if not atlas:
		_project_load_error("No atlas for animation " + anim_name)
		return
	
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
	speaker.talksound = stream
	print("\tLoaded " + str(stream.streams_count) + " talksounds")

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
	
	var bytes = f.get_buffer(f.get_length())
	var stream = null
	
	var extension = path.get_extension().to_lower()
	match extension:
		'wav':
			stream = AudioStreamWAV.new()
			stream.format = AudioStreamWAV.FORMAT_16_BITS
		'mp3':
			stream = AudioStreamMP3.new()
		_:
			_project_load_error("Unsupported file type, " + extension)
			return null
	if stream:
		stream.set_data(bytes)
	return stream

func _validate_json(json:Dictionary,template:Array):
	for key in template:
		if not json.has(key):
			_project_load_error("Missing key %s" % [key],true)
			return
