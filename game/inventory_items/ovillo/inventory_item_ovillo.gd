extends "res://game/objects/nuna_inventory_item.gd"

var state: PopochiuInventoryItemData = load("res://game/inventory_items/ovillo/inventory_item_ovillo.tres")


func _on_click() -> void:
	I.set_active_item(self)


func _on_right_click() -> void:
	I.set_active_item(null)
