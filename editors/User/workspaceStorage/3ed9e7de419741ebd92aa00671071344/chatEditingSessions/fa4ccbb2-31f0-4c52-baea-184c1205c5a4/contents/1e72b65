extends CharacterBody2D

@export var SPEED: float = 300.0
@export var JUMP_VELOCITY: float = -400.0
@export var MAX_HEALTH: int = 100
@export var WALL_SLIDE_GRAVITY_MULT: float = 0.3
@export var WALL_JUMP_KICK_MULT: float = 1.5

@onready var bgm: Sprite2D = $CanvasLayer/bg_display_on_mode
@onready var actArea: Area2D = $activeArea
@onready var currentTimeFactor: float = 1.0
@onready var health: int = MAX_HEALTH
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var _isTreePaused: bool = false
var wall_jump_timer: float = 0.0
var wall_jump_direction: float = 0.0
var grabbed_enemy: CollisionObject2D
var facing_direction: int = 1

func _ready() -> void:
	Global.reset_state()
	Global.score = 0
	bgm.visible = Global.powerMode
	sprite.play("idle_right")

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("ability_fast"):
		Global.toggle_all()
	if Input.is_action_just_pressed("grab"):
		if grabbed_enemy == null:
			try_grab()
		else:
			release_grab()

func try_grab() -> void:
	var enemies: Array[Node] = get_tree().get_nodes_in_group("selectable")
	var closest: CollisionObject2D
	var closest_dist_sq: float = float(Global.throwDistance) ** 2.0
	for enemy in enemies:
		if not is_instance_valid(enemy) or enemy.get("is_grabbed"):
			continue
		var dist_sq: float = global_position.distance_squared_to(enemy.global_position)
		if dist_sq < closest_dist_sq:
			closest_dist_sq = dist_sq
			closest = enemy
	if closest == null:
		return
	grabbed_enemy = closest
	if grabbed_enemy.get("is_grabbed") == null:
		grabbed_enemy.queue_free()
		return
	grabbed_enemy.is_grabbed = true
	grabbed_enemy.set_physics_process(false)
	grabbed_enemy.velocity = Vector2.ZERO
	var col = grabbed_enemy.get_node_or_null("CollisionShape2D")
	if col:
		col.set_deferred("disabled", true)
	grabbed_enemy.reparent(self)
	grabbed_enemy.global_position = global_position + Vector2(facing_direction * 40, -20)

func release_grab() -> void:
	if grabbed_enemy == null:
		return
	grabbed_enemy.reparent(get_parent())
	grabbed_enemy.global_position = global_position + Vector2(facing_direction * 40, 0)
	var col = grabbed_enemy.get_node_or_null("CollisionShape2D")
	if col:
		col.set_deferred("disabled", false)
	grabbed_enemy.is_grabbed = false
	grabbed_enemy.set_physics_process(true)
	grabbed_enemy.velocity = Vector2.ZERO
	grabbed_enemy = null

func set_pause(val: bool) -> void:
	_isTreePaused = val
	for body in actArea.get_overlapping_bodies():
		body.set_physics_process(not val)

func set_speed(mult: float) -> void:
	currentTimeFactor *= mult
	if mult < 1.0:
		velocity *= mult

func show_game_over() -> void:
	release_grab()
	var menu = get_node_or_null("PauseMenu")
	if menu:
		menu.reparent(get_tree().current_scene)
		menu.show_death_screen()
	queue_free()

func trigger_game_over() -> void:
	health = 0
	show_game_over()

func take_damage(amount: int) -> void:
	health -= amount
	if health <= 0:
		show_game_over()

func _update_animation() -> void:
	var on_floor: bool = is_on_floor()
	var dir: float = sign(velocity.x) if abs(velocity.x) > 10.0 else 0.0
	var moving: bool = dir != 0.0 and on_floor

	sprite.speed_scale = 0.25
	if not on_floor:
		if facing_direction > 0:
			if velocity.y < 0:
				sprite.play("jump_right")
			else:
				if sprite.animation != "jump_right":
					sprite.play("jump_right")
			var t: float = clamp(abs(velocity.y) / 600.0, 0.0, 1.0)
			sprite.frame = int(lerp(1.0, 3.0, t))
		else:
			if velocity.y < 0:
				sprite.play("jump_left")
			else:
				if sprite.animation != "jump_left":
					sprite.play("jump_left")
				var t2: float = clamp(abs(velocity.y) / 600.0, 0.0, 1.0)
				sprite.frame = int(lerp(1.0, 3.0, t2))
	elif moving:
		var speed_ratio: float = clamp(abs(velocity.x) / SPEED, 0.0, 1.0)
		if dir > 0:
			sprite.play("walk_right")
		else:
			sprite.play("walk_left")
		sprite.speed_scale = 0.25 * (speed_ratio * 8.0 + 1.0)
	else:
		if facing_direction > 0:
			sprite.play("idle_right")
		else:
			sprite.play("idle_left")
		sprite.speed_scale = 0.25

func _physics_process(delta: float) -> void:
	var tDelta: float = delta * currentTimeFactor
	var tSpeed: float = SPEED * currentTimeFactor
	var tJumpVelocity: float = JUMP_VELOCITY * sqrt(currentTimeFactor)
	if not is_on_floor():
		velocity += get_gravity() * tDelta
		if is_on_wall():
			velocity.y *= WALL_SLIDE_GRAVITY_MULT

	wall_jump_timer = max(wall_jump_timer - tDelta, 0.0)
	if Input.is_action_just_pressed("jump"):
		if is_on_floor():
			velocity.y = tJumpVelocity
		elif is_on_wall():
			velocity.y = tJumpVelocity
			velocity.x = get_wall_normal().x * tSpeed * WALL_JUMP_KICK_MULT
			wall_jump_timer = 0.7
			wall_jump_direction = get_wall_normal().x

	if Input.is_action_just_pressed("down") and not is_on_floor():
		velocity.y -= tJumpVelocity

	var direction: float = Input.get_axis("left", "right")
	if direction != 0:
		facing_direction = int(sign(direction))
	if wall_jump_timer > 0.0:
		var toward_wall: float = sign(direction) == -sign(wall_jump_direction)
		if direction != 0.0 and toward_wall:
			velocity.x = move_toward(velocity.x, 0, tSpeed * (0.7 - wall_jump_timer))
		elif direction:
			velocity.x = direction * tSpeed
		else:
			velocity.x = move_toward(velocity.x, 0, tSpeed * 0.07)
	elif direction:
		velocity.x = direction * tSpeed
	else:
		velocity.x = move_toward(velocity.x, 0, tSpeed)

	move_and_slide()
	_update_animation()

	if grabbed_enemy and is_instance_valid(grabbed_enemy):
		grabbed_enemy.global_position = global_position + Vector2(facing_direction * 40, -20)
	elif grabbed_enemy:
		grabbed_enemy = null

func _on_active_area_body_entered(body: Node2D) -> void:
	if body == grabbed_enemy:
		return
	body.set_physics_process(not _isTreePaused)

func _on_active_area_body_exited(body: Node2D) -> void:
	if body == grabbed_enemy:
		return
	body.set_physics_process(false)
