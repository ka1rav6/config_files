extends Node


var score: int
var powerMode: bool
var player: CharacterBody2D
var throwDistance: int
var enemy_count :=0
var kill_count := 0
var max_elixir := 100.0
var elixir := 100.0
var elixir_gain_speed := 20.0
var power_mode_drain_rate := 30.0
var enemy_freeze_elixir_cost := 25.0
const ULTRAINSTINCT_SLOWDOWN = 0.1
const LEVEL_TIME_LIMIT := 100.0

var level_timer_canvas: CanvasLayer = null
var level_timer_label: Label = null
var level_time_remaining: float = LEVEL_TIME_LIMIT
var level_timer_active: bool = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	score = 0
	powerMode = false
	refresh_player()
	throwDistance = 150
	elixir = max_elixir
	get_tree().connect("scene_changed", Callable(self, "_on_scene_changed"))
	setup_level_timer_if_needed()

func _on_scene_changed(new_scene: Node) -> void:
	print("Scene changed to:", new_scene, "path=", new_scene.scene_file_path)
	setup_level_timer_if_needed()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if not is_instance_valid(player):
		refresh_player()
	if powerMode:
		elixir -= power_mode_drain_rate * delta
		if elixir <= 0:
			elixir = 0
			toggle_all()
	else:
		elixir = min(max_elixir, elixir + elixir_gain_speed * delta)

	if level_timer_active:
		level_time_remaining -= delta
		if level_time_remaining <= 0.0:
			level_time_remaining = 0.0
			level_timer_active = false
			trigger_level_timeout()
		else:
			_update_level_timer_display()

func refresh_player() -> void:
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("Player")

# Resets every piece of persistent state Global tracks. Scene-local state
# (player, enemies, collectibles, timers, etc.) lives in the level scene
# itself, so reloading/swapping that scene resets it for free — this only
# has to clean up what actually survives a scene change.
func reset_state() -> void:
	score = 0
	powerMode = false
	enemy_count = 0
	kill_count = 0
	player = null
	elixir = max_elixir
	level_time_remaining = LEVEL_TIME_LIMIT
	level_timer_active = false

# Used by both the start menu and the pause menu so "Start" and "Restart"
# never fall out of sync with each other.
func start_level(level_scene: PackedScene) -> void:
	reset_state()
	get_tree().paused = false
	get_tree().change_scene_to_packed(level_scene)

# Restarts whatever level is currently running, fresh, regardless of
# whether it's paused or the player has already died.
func restart_current_level() -> void:
	reset_state()
	get_tree().paused = false
	get_tree().reload_current_scene()

func setup_level_timer_if_needed() -> void:
	if not is_instance_valid(get_tree().current_scene):
		return

	var current_scene_path: String = get_tree().current_scene.scene_file_path
	print("setup timer check", current_scene_path)
	if not current_scene_path.begins_with("res://scenes/levels/"):
		if is_instance_valid(level_timer_canvas):
			level_timer_canvas.queue_free()
			level_timer_canvas = null
			level_timer_label = null
		level_timer_active = false
		return

	if is_instance_valid(level_timer_canvas):
		level_timer_canvas.queue_free()

	level_time_remaining = LEVEL_TIME_LIMIT
	level_timer_active = true
	level_timer_canvas = CanvasLayer.new()
	level_timer_canvas.layer = 200

	var timer_label := Label.new()
	timer_label.name = "LevelTimerLabel"
	timer_label.custom_minimum_size = Vector2(180, 60)
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	timer_label.text = "100"
	timer_label.add_theme_color_override("font_color", Color.WHITE)
	timer_label.add_theme_font_size_override("font_size", 32)
	timer_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	timer_label.anchor_left = 0.5
	timer_label.anchor_right = 0.5
	timer_label.anchor_top = 0.0
	timer_label.anchor_bottom = 0.0
	timer_label.margin_left = int(-timer_label.custom_minimum_size.x * 0.5)
	timer_label.margin_right = int(timer_label.custom_minimum_size.x * 0.5)
	timer_label.margin_top = 20
	timer_label.margin_bottom = int(timer_label.custom_minimum_size.y + 20)

	level_timer_canvas.add_child(timer_label)
	get_tree().current_scene.add_child(level_timer_canvas)
	level_timer_label = timer_label
	_update_level_timer_display()

func _update_level_timer_display() -> void:
	if not is_instance_valid(level_timer_label):
		return
	var seconds := int(ceil(level_time_remaining))
	if seconds < 0:
		seconds = 0
	level_timer_label.text = str(seconds)
	if seconds <= 10:
		level_timer_label.add_theme_color_override("font_color", Color.RED)
		level_timer_label.add_theme_font_size_override("font_size", 42)
	else:
		level_timer_label.add_theme_color_override("font_color", Color.WHITE)
		level_timer_label.add_theme_font_size_override("font_size", 32)

func trigger_level_timeout() -> void:
	_update_level_timer_display()
	refresh_player()
	if is_instance_valid(player):
		player.trigger_game_over()
	else:
		get_tree().paused = true
		print("Level timeout without a player instance")
	
func toggle_all() -> void:
	refresh_player()
	if not powerMode and elixir <= 0:
		return
	powerMode = !powerMode
	if is_instance_valid(player):
		player.bgm.visible = powerMode
		if powerMode:
			player.velocity *= ULTRAINSTINCT_SLOWDOWN
		player.currentTimeFactor = ULTRAINSTINCT_SLOWDOWN if powerMode else 1.0
	var nodes = get_tree().get_nodes_in_group("selectable")
	for node in nodes:
		if not is_instance_valid(node):
			continue
		if node.has_method("toggle_sprite"):
			node.toggle_sprite()
		if "currentTimeFactor" in node:
			if "isAffectedBy" in node and node.isAffectedBy > 0:
				continue
			if powerMode and "velocity" in node:
				node.velocity *= ULTRAINSTINCT_SLOWDOWN
			node.currentTimeFactor = ULTRAINSTINCT_SLOWDOWN if powerMode else 1.0
