@tool
extends "res://addons/popochiu/engine/interfaces/i_room.gd"

# classes ----
const PRBaseTecnica := preload("res://game/rooms/base_tecnica/room_base_tecnica.gd")
const PRHabitacion101 := preload("res://game/rooms/habitacion_101/room_habitacion_101.gd")
# ---- classes

# nodes ----
var BaseTecnica: PRBaseTecnica : get = get_BaseTecnica
var Habitacion101: PRHabitacion101 : get = get_Habitacion101
# ---- nodes

# functions ----
func get_BaseTecnica() -> PRBaseTecnica: return get_runtime_room("BaseTecnica")
func get_Habitacion101() -> PRHabitacion101: return get_runtime_room("Habitacion101")
# ---- functions

