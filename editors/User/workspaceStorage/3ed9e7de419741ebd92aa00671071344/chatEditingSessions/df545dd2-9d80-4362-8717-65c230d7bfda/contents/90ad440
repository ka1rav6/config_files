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

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	score = 0
	powerMode = false
	refresh_player()
	throwDistance = 150
	elixir = max_elixir

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
