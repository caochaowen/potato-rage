extends Panel
class_name StatsContainer

@onready var health_lable: Label = %HealthLable
@onready var hp_range_label: Label = %HPRangeLabel
@onready var life_streal_label: Label = %LifeStrealLabel
@onready var damage_label: Label = %DamageLabel
@onready var luck_label: Label = %LuckLabel
@onready var speed_lable: Label = %SpeedLable
@onready var block_chance_label: Label = %BlockChanceLabel
@onready var harvesting_labell: Label = %HarvestingLabell


func _process(delta: float) -> void:
	if not is_instance_valid(Global.player):
		return
	health_lable.text = str(Global.player.stats.health)
	hp_range_label.text = str(Global.player.stats.hp_regen)
	life_streal_label.text = str(Global.player.stats.life_steal)+ "%"
	damage_label.text = str(Global.player.stats.damage)
	luck_label.text = str(Global.player.stats.luck)
	speed_lable.text = str(Global.player.stats.speed)
	block_chance_label.text = str(Global.player.stats.block_chance)+ "%"
	harvesting_labell.text = str(Global.player.stats.harvesting)
	
