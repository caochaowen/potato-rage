extends Panel
class_name UpgradePanel

const UPGREDE_CARD_SCENE = preload("uid://be2j5vgor3pyi")

@export var upgrade_list:Array[ItemUpgrade]
@onready var item_container: HBoxContainer = %ItemContainer




func load_upgrade(current_wave: int)-> void:
	for child in item_container.get_children():
		child.queue_free()
		
	var config := Global.UPGRADE_PROBABILITY_CONFIG
	var selected_upgrade := Global.select_items_for_offer(upgrade_list,current_wave,config)
	for random_upg:ItemUpgrade in selected_upgrade:
		var card_instance := UPGREDE_CARD_SCENE.instantiate() as UpgradeCard
		item_container.add_child(card_instance)
		card_instance.item_data = random_upg
