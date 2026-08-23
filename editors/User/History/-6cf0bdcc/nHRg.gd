extends CanvasLayer

@export var next_scene: PackedScene
@export var options_scene: PackedScene

@onready var start_button: Button = $ColorRect/StartButton
@onready var how_to_play_button: Button = $ColorRect/HowToPlayButton
@onready var options_button: Button = $ColorRect/OptionsButton
@onready var quit_button: Button = $ColorRect/QuitButton
@onready var how_to_play_overlay: CanvasLayer = $HowToPlayOverlay

func _ready() -> void:
	visible = true
	if is_instance_valid(start_button):
		start_button.pressed.connect(_on_start_button_pressed)
	if is_instance_valid(how_to_play_button):
		how_to_play_button.pressed.connect(_on_how_to_play_button_pressed)
	if is_instance_valid(options_button):
		options_button.pressed.connect(_on_options_button_pressed)
	if is_instance_valid(quit_button):
		quit_button.pressed.connect(_on_quit_button_pressed)
	if is_instance_valid(how_to_play_overlay) and how_to_play_overlay.has_method("open"):
		how_to_play_overlay.closed.connect(_on_how_to_play_closed)

func _on_start_button_pressed() -> void:
	if next_scene:
		Global.start_level(next_scene)
	else:
		visible = false

func _on_how_to_play_button_pressed() -> void:
	_set_menu_buttons_disabled(true)
	if is_instance_valid(how_to_play_overlay) and how_to_play_overlay.has_method("open"):
		how_to_play_overlay.open()

func _on_how_to_play_closed() -> void:
	_set_menu_buttons_disabled(false)

func _set_menu_buttons_disabled(is_disabled: bool) -> void:
	if is_instance_valid(start_button):
		start_button.disabled = is_disabled
	if is_instance_valid(how_to_play_button):
		how_to_play_button.disabled = is_disabled
	if is_instance_valid(options_button):
		options_button.disabled = is_disabled
	if is_instance_valid(quit_button):
		quit_button.disabled = is_disabled

func _on_options_button_pressed() -> void:
	if options_scene:
		get_tree().paused = false
		get_tree().change_scene_to_packed(options_scene)
	else:
		print("Options button clicked!")

func _on_quit_button_pressed() -> void:
	get_tree().quit()
