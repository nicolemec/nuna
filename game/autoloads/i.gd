@tool
extends "res://addons/popochiu/engine/interfaces/i_inventory.gd"

# classes ----
const PIIOvillo := preload("res://game/inventory_items/ovillo/inventory_item_ovillo.gd")
const PIIDentadura := preload("res://game/inventory_items/dentadura/inventory_item_dentadura.gd")
# ---- classes

# nodes ----
var Ovillo: PIIOvillo : get = get_Ovillo
var Dentadura: PIIDentadura : get = get_Dentadura
# ---- nodes

# functions ----
func get_Ovillo() -> PIIOvillo: return get_item_instance("Ovillo")
func get_Dentadura() -> PIIDentadura: return get_item_instance("Dentadura")
# ---- functions

