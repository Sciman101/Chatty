extends CanvasLayer

@onready var dialouge_input = $MarginContainer/VBoxContainer/DialougeInput
@onready var btn_stop = $MarginContainer/VBoxContainer/HBoxContainer/Stop
@onready var btn_run = $MarginContainer/VBoxContainer/HBoxContainer/Run

var start_from_line := false

func _ready():
	Chatty.event_started.connect(self._on_chatty_event)

func _input(event):
	if event is InputEventKey:
		if event.keycode == KEY_SHIFT:
			start_from_line = event.pressed
			btn_run.text = "From Line" if start_from_line else "Run Script"
			

func _on_run_pressed():
	var script = dialouge_input.text
	if not Chatty.script_active:
		Chatty.load_script(script)
		Chatty.run_script(0 if not start_from_line else dialouge_input.get_caret_line())
		
		btn_stop.disabled = false

func _on_chatty_event(num,event):
	dialouge_input.set_caret_line(num)

func _on_stop_pressed():
	btn_stop.disabled = false
	
	Chatty.stop_script()
