extends Node2D
class_name WeaponBehavior

@export var weapon: Weapon

var critical:= false

func execute_attack() -> void:
	pass
	
func get_damage() -> float:
	var damage := weapon.data.stats.damage + Global.player.stats.damage
	var crit_chance := weapon.data.stats.crit_channce
	if Global.get_chance_sucesss(crit_chance):
		critical = true
		damage = ceil(damage * weapon.data.stats.crit_damage)
	return damage

func apply_life_steal() -> void:
	var steal_chance := (Global.player.stats.life_steal / 100) + weapon.data.stats.life_steal
	var can_steal := Global.get_chance_sucesss(steal_chance)
	
	if can_steal and is_instance_valid(Global.player):
		Global.player.health_component.heal(1.0)
		Global.on_create_block_text.emit(Global.player,1.0) 
