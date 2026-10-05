extends Panel
class_name UpgradeCard

@export var item_data :ItemUpgrade:set = _set_data
@onready var icon: TextureRect = %Icon
@onready var item_name: Label = %Name
@onready var discript: Label = %Discript

func _set_data(value:ItemUpgrade)-> void:
	item_data = value
	icon.texture = item_data.item_icon
	item_name.text = item_data.item_name
	discript.text = item_data.description 
	
	var style := Global.get_tier_style(item_data.item_tier)
	add_theme_stylebox_override("panel",style)

func _on_custom_button_pressed() -> void:
	if item_data and is_instance_valid(Global.player):
		item_data.apply_upgrade()
		Global.on_upgrade_selected.emit()
