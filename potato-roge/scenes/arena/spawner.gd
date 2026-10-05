extends Node2D
class_name Spawner

signal on_wave_completed


@export var spawn_area_size := Vector2(1000,500)
@export var waves_data: Array[WaveData]
@export var enemy_collection: Array[UnitStats]


@onready var spawner_timer: Timer = $SpawnerTimer
@onready var wave_timer: Timer = $WaveTimer

var wave_index := 1
var current_wave_data : WaveData
var spawned_enemies: Array[Enemy] = []


func find_wave_data()-> WaveData:
	for wave in waves_data:
		if wave and wave.is_valid_index(wave_index):
			return wave
			
	return null

func start_wave() -> void:
	current_wave_data = find_wave_data()
	if not current_wave_data:
		spawner_timer.stop()
		wave_timer.stop()
		return
	
	wave_timer.wait_time = current_wave_data.wave_time
	wave_timer.start()
	
	set_spawn_timer()
	
func set_spawn_timer()-> void:
	match current_wave_data.spawn_type:
		WaveData.SpawnType.FIXED:
			spawner_timer.wait_time = current_wave_data.fixed_spawn_time
		WaveData.SpawnType.RANOOM:
			var min_t := current_wave_data.min_spawn_time
			var max_t := current_wave_data.max_spawn_time
			spawner_timer.wait_time = randf_range(min_t, max_t)
	
	if spawner_timer.is_stopped():
		spawner_timer.start()
		
		
func get_random_spawn_position() ->Vector2:
	var random_x = randf_range(-spawn_area_size.x,spawn_area_size.x)
	var random_y = randf_range(-spawn_area_size.y,spawn_area_size.y)
	return Vector2(random_x,random_y)

func spawn_enemy()-> void:
	var enemy_scene := current_wave_data.get_random_unit_scene()
	if enemy_scene:
		var spawn_pos := get_random_spawn_position()
		var enemy_instance := enemy_scene.instantiate() as Enemy
		enemy_instance.global_position = spawn_pos
		get_parent().add_child(enemy_instance)
		spawned_enemies.append(enemy_instance)
		
		
	set_spawn_timer()
	
func update_enemies_new_wave()->void:
	for stat: UnitStats in enemy_collection:
		stat.health += stat.health_increase_per_wave
		stat.damage += stat.damage_increase_per_wave

func clear_enemies()->void:
	if spawned_enemies.size()>0:
		for enemy:Enemy in spawned_enemies:
			if is_instance_valid(enemy):
				enemy.destroy_enemy()
	
	spawned_enemies.clear()

func get_wave_text()->String:
	return "Wave %s" % wave_index
	
func get_wave_timer_text() -> String:
	return str(max(0,int(wave_timer.time_left)))


func _on_spawner_timer_timeout() -> void:
	if not current_wave_data or wave_timer.is_stopped():
		spawner_timer.stop()
		return
	spawn_enemy()


func _on_wave_timer_timeout() -> void:
	Global.game_paused= true
	Global.get_harvesting_coins()
	on_wave_completed.emit()
	spawner_timer.stop()
	clear_enemies()
	update_enemies_new_wave()
