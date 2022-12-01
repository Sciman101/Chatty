extends NinePatchRect

@onready var label = $SpeakerNameLabel

func set_name_display(name:String,color:Color=Color.BLACK) -> void:
	label.text = name
	visible = name != ""
	size.x = label.get_minimum_size().x + 8
