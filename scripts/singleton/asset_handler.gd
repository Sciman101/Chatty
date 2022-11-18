extends Node

var speakers = {
	jnfr = preload("res://speakers/speaker_jnfr.tres"),
	ru_b = preload("res://speakers/speaker_ru_b.tres"),
	iekika = preload("res://speakers/speaker_iekika.tres"),
}

var backgrounds = {
	white = preload("res://graphics/backgrounds/white.png"),
	black = preload("res://graphics/backgrounds/black.png"),
	windowsxp = preload("res://graphics/backgrounds/windowsxp.png"),
	den = preload("res://graphics/backgrounds/gamer_den.png"),
	dencup = preload("res://graphics/backgrounds/gamer_den_cup.png"),
}

var PROJECT_TEMPLATE = ['name','version','start_script']
var SPEAKER_TEMPLATE = ['name','animations']
var ANIM_TEMPLATE = ['spritesheet','frames','fps']

var _project_dir : String
var _project

var _sprite_load_cache = {}

func _ready():
	_load_project("res://test_project")

func _load_project(project_dir:String) -> void:
	_project_dir = project_dir
	_load_project_data()
	_load_speakers()

func _load_project_data() -> void:
	var project = _read_jsonfile(_project_dir+"/chatty.json")
	if project:
		_validate_json(project,PROJECT_TEMPLATE)
		_project = project
		print("Loaded chatty.json!")
	else:
		_project_load_error("Can't read chatty.json!",true)

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

func _validate_json(json:Dictionary,template:Array):
	for key in template:
		if not json.has(key):
			_project_load_error("Missing key %s" % [key],true)
			return
