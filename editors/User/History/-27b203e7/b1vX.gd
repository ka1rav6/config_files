@tool
extends Control

@export var num_levels: int = 5:
	set(val):
		num_levels = max(1, val)
		if level_scenes.size() < num_levels:
			level_scenes.resize(num_levels)
		_rebuild_grid()

@export var columns: int = 3:
	set(val):
		columns = max(1, val)
		if grid_container:
			grid_container.columns = columns

@export var level_scenes: Array[PackedScene] = []:
	set(val):
		level_scenes = val
		_rebuild_grid()

@export var back_scene: PackedScene

@onready var grid_container: GridContainer = $ColorRect/GridContainer
@onready var back_button: Button = $ColorRect/BackButton

func _ready() -> void:
	if Engine.is_editor_hint():
		_rebuild_grid()
		return
	
	if back_button and not back_button.pressed.is_connected(_on_back_pressed):
		back_button.pressed.connect(_on_back_pressed)
	
	_rebuild_grid()

func _rebuild_grid() -> void:
	if not grid_container:
		grid_container = get_node_or_null("ColorRect/GridContainer")
		if not grid_container:
			return
	
	grid_container.columns = columns
	
	for child in grid_container.get_children():
		child.queue_free()
	
	for i in range(num_levels):
		var btn = Button.new()
		btn.text = "Level %d" % (i + 1)
		btn.custom_minimum_size = Vector2(120, 60)
		
		if not Engine.is_editor_hint():
			var index = i
			btn.pressed.connect(func(): _on_level_button_pressed(index))
		
		grid_container.add_child(btn)

func _on_level_button_pressed(index: int) -> void:
	if index >= 0 and index < level_scenes.size() and level_scenes[index]:
		Global.start_level(level_scenes[index])
	else:
		print("Level scene not assigned for level %d" % (index + 1))

func _on_back_pressed() -> void:
	if back_scene:
		get_tree().change_scene_to_packed(back_scene)
	else:
		get_tree().change_scene_to_file("res://scenes/ui/StartMenu.tscn")
