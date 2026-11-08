@tool
extends "res://addons/popochiu/engine/interfaces/i_character.gd"

# classes ----
const PCNuna := preload("res://game/characters/nuna/character_nuna.gd")
# ---- classes

# nodes ----
var Nuna: PCNuna : get = get_Nuna
# ---- nodes

# functions ----
func get_Nuna() -> PCNuna: return get_runtime_character("Nuna")
# ---- functions

