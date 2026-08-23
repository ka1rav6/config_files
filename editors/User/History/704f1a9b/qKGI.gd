extends Control

@export var back_scene: PackedScene

var rebinding_action: String = ""

@onready var master_slider: HSlider = $ColorRect/VBoxContainer/MasterVolumeRow/MasterSlider
@onready var master_label: Label = $ColorRect/VBoxContainer/MasterVolumeRow/MasterLabel
@onready var fullscreen_check: CheckButton = $ColorRect/VBoxContainer/FullscreenRow/FullscreenCheck
@onready var back_button: Button = $ColorRect/BackButton
@onready var rebind_prompt: Label = $ColorRect/RebindPrompt

var action_names := {
	"left": "Move Left",
	"right": "Move Right",
	"jump": "Jump",
	"down": "Fast Fall",
	"ability_fast": "Power Mode",
	"grab": "Grab / Release"
}

func _ready() -> void:
	rebind_prompt.visible = false
	_load_settings()
	master_slider.value_changed.connect(_on_master_volume_changed)
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	back_button.pressed.connect(_on_back_pressed)
	_populate_keybinds()

func _load_settings() -> void:
	var vol = ConfigFile.new()
	if vol.load("user://options.cfg") == OK:
		var db = vol.get_value("audio", "master_db", 0.0)
		AudioServer.set_bus_volume_db(0, db)
		master_slider.value = db
		var fs = vol.get_value("display", "fullscreen", false)
		fullscreen_check.button_pressed = fs
		_apply_fullscreen(fs)
		if vol.has_section("keybinds"):
			for action in action_names.keys():
				if vol.has_section_key("keybinds", action):
					var pk = vol.get_value("keybinds", action, 0)
					_remap_action(action, pk)
	else:
		master_slider.value = AudioServer.get_bus_volume_db(0)
		fullscreen_check.button_pressed = false

func _save_settings() -> void:
	var cfg = ConfigFile.new()
	cfg.set_value("audio", "master_db", AudioServer.get_bus_volume_db(0))
	cfg.set_value("display", "fullscreen", fullscreen_check.button_pressed)
	for action in action_names.keys():
		var events = InputMap.action_get_events(action)
		if events.size() > 0 and events[0] is InputEventKey:
			cfg.set_value("keybinds", action, events[0].physical_keycode)
	cfg.save("user://options.cfg")

func _on_master_volume_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(0, value)
	master_label.text = "%d%%" % int(db_to_linear(value) * 100)
	_save_settings()

func _on_fullscreen_toggled(pressed: bool) -> void:
	_apply_fullscreen(pressed)
	_save_settings()

func _apply_fullscreen(fullscreen: bool) -> void:
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func _populate_keybinds() -> void:
	var container = $ColorRect/VBoxContainer/KeybindsContainer
	for action in action_names:
		var row = HBoxContainer.new()
		var label = Label.new()
		label.text = action_names[action]
		label.custom_minimum_size = Vector2(140, 0)
		label.add_theme_font_size_override("font_size", 14)
		row.add_child(label)
		var btn = Button.new()
		btn.text = _get_key_name(action)
		btn.custom_minimum_size = Vector2(120, 30)
		btn.pressed.connect(func(): _start_rebind(action, btn))
		row.add_child(btn)
		container.add_child(row)

func _get_key_name(action: String) -> String:
	var events = InputMap.action_get_events(action)
	if events.size() > 0 and events[0] is InputEventKey:
		return OS.get_keycode_string(events[0].get_keycode_with_modifiers())
	return "Unbound"

func _start_rebind(action: String, btn: Button) -> void:
	rebinding_action = action
	btn.text = "Press a key..."
	rebind_prompt.visible = true

func _input(event: InputEvent) -> void:
	if rebinding_action == "":
		return
	if event is InputEventKey and event.pressed:
		_remap_action(rebinding_action, event.physical_keycode)
		_populate_keybinds()
		_save_settings()
		rebinding_action = ""
		rebind_prompt.visible = false
		get_viewport().set_input_as_handled()

func _remap_action(action: String, physical_keycode: int) -> void:
	InputMap.action_erase_events(action)
	var ev := InputEventKey.new()
	ev.physical_keycode = physical_keycode
	InputMap.action_add_event(action, ev)

func _on_back_pressed() -> void:
	if back_scene:
		get_tree().change_scene_to_packed(back_scene)
	else:
		get_tree().change_scene_to_file("res://scenes/ui/StartMenu.tscn")
