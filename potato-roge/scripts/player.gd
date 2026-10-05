extends Unit
class_name Player

@export var dash_duration := 0.5
@export var dash_speed_multi := 0.5
@export var dash_cooldown := 0.5

@onready var dash_timer: Timer = $DashTimer
@onready var dash_cooldown_timer: Timer = $DashCooldownTimer
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var trail: Trail = %Trail
@onready var weapon_container: WeaponContainer = $WeaponContainer

var current_weapons: Array[Weapon]= []

var move_dir:Vector2
var is_dash := false
var dash_available := true

func _ready() -> void:
	super._ready()
	dash_timer.wait_time = dash_duration
	dash_cooldown_timer.wait_time = dash_cooldown
	add_weapon(preload("uid://bv0o060v0ikpp"))
	#add_weapon(preload("uid://bv0o060v0ikpp"))
	#add_weapon(preload("uid://bv0o060v0ikpp"))
	#add_weapon(preload("uid://bv0o060v0ikpp"))
	#add_weapon(preload("uid://on2iapoty0p8"))
	
func _process(delta: float) -> void:
	if Global.game_paused: return
	
	move_dir = Input.get_vector("move_left","move_right","move_up","move_down")
	
	var current_velocity := move_dir * stats.speed
	if is_dash:
		current_velocity *= dash_speed_multi
	position += current_velocity * delta 
	position.x = clamp(position.x,-950,950)
	position.y = clamp(position.y,-500,500)
	if can_dash():
		start_dash()
	update_animations()
	update_rotation()
	
func add_weapon(data: ItemWeapon) -> void:
	var weapon := data.scene.instantiate() as Weapon
	add_child(weapon)
	
	weapon.setup_weapon(data)
	current_weapons.append(weapon)
	weapon_container.update_weapons_position(current_weapons)
	
func update_animations() -> void:
	if move_dir.length() > 0:
		animation_player.play("run")
	else:
		animation_player.play("idle")
		
func update_rotation() -> void:
	if move_dir == Vector2.ZERO:
		return
		
	if move_dir.x >= 0.1:
		visuals.scale = Vector2(-0.5,0.5)
	else:
		visuals.scale = Vector2(0.5,0.5)
		
		
func start_dash() -> void:
	is_dash = true
	dash_timer.start()
	trail.start_trail()
	visuals.modulate.a = 0.5
	collision.set_deferred("disabled",true)
	
func can_dash() -> bool:
	return not is_dash and dash_cooldown_timer.is_stopped() and Input.is_action_just_pressed("dash") and move_dir != Vector2.ZERO
	
func is_facing_right() -> bool:
	return visuals.scale.x == -0.5
	
func update_player_new_wave()->void:
	stats.health += stats.health_increase_per_wave
	health_component.setup(stats)

func _on_dash_timer_timeout() -> void:
	is_dash = false
	visuals.modulate.a = 1.0
	move_dir = Vector2.ZERO
	collision.set_deferred("disabled",false)
	dash_cooldown_timer.start()


func _on_hp_regen_timer_timeout() -> void:
	if health_component.current_health <= 0:
		return
	
	if health_component.current_health < stats.health:
		var heal := stats.hp_regen
		health_component.heal(heal)
		Global.on_create_heal_text.emit(self,heal)
