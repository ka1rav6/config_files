extends Area2D

var damage:= 30
var damage_enemies:=true
var direction:= Vector2.RIGHT
var SPEED:= 0
var ignore_body: Node2D = null
var currentTimeFactor := 1.0

var onHoverScaleFactor := 1.25
var slowDownTimeFactor := 0.1
var isAffectedBy := 0

@onready var sels: Sprite2D = $select_sprite
@onready var mc: Area2D = $mouseCollider

func _ready() -> void:
	add_to_group("selectable")
	body_entered.connect(_on_body_entered)
	mc.input_event.connect(_on_input_event)
	mc.mouse_entered.connect(_on_mouse_entered)
	mc.mouse_exited.connect(_on_mouse_exited)
	get_tree().create_timer(30.0).timeout.connect(queue_free)
	if Global.powerMode:
		set_speed(Global.ULTRAINSTINCT_SLOWDOWN)
	toggle_sprite()

func toggle_sprite() -> void:
	sels.visible = Global.powerMode

func set_speed(mult: float) -> void:
	currentTimeFactor *= mult

func _physics_process(delta: float) -> void:
	rotation = direction.angle()
	global_position += direction * delta * currentTimeFactor * SPEED

func _on_body_entered(body: Node2D) -> void:
	if body == ignore_body:
		return
	if (body.is_in_group("Player") or damage_enemies) and body.has_method("take_damage"):
		body.take_damage(damage)
	queue_free()

func _on_mouse_entered() -> void:
	sels.scale *= onHoverScaleFactor

func _on_mouse_exited() -> void:
	sels.scale /= onHoverScaleFactor

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if not Global.powerMode:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			Global.toggle_all()
			set_speed(slowDownTimeFactor)
			isAffectedBy += 1
			damage_enemies = true
			get_tree().create_timer(5.0).timeout.connect(func():
				if is_instance_valid(self):
					set_speed(1.0 / slowDownTimeFactor)
					isAffectedBy -= 1
			)
