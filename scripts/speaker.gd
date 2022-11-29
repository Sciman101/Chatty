class_name Speaker
extends SpriteFrames

enum VoiceMode {
	PER_CHAR,
	WAIT,
	ONCE
}

@export var speaker_name : String
@export var talksound : AudioStream
@export var ui_atlas_override : ImageTexture

@export_enum(VoiceMode) var voice_mode
