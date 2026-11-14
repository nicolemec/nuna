@tool
extends "res://addons/popochiu/engine/interfaces/i_room.gd"

# classes ----
const PRBaseTecnica := preload("res://game/rooms/base_tecnica/room_base_tecnica.gd")
const PRHabitacion101 := preload("res://game/rooms/habitacion_101/room_habitacion_101.gd")
const PRTeatro := preload("res://game/rooms/teatro/room_teatro.gd")
const PRCalle := preload("res://game/rooms/calle/room_calle.gd")
const PRRecepcion := preload("res://game/rooms/recepcion/room_recepcion.gd")
# ---- classes

# nodes ----
var BaseTecnica: PRBaseTecnica : get = get_BaseTecnica
var Habitacion101: PRHabitacion101 : get = get_Habitacion101
var Teatro: PRTeatro : get = get_Teatro
var Calle: PRCalle : get = get_Calle
var Recepcion: PRRecepcion : get = get_Recepcion
# ---- nodes

# functions ----
func get_BaseTecnica() -> PRBaseTecnica: return get_runtime_room("BaseTecnica")
func get_Habitacion101() -> PRHabitacion101: return get_runtime_room("Habitacion101")
func get_Teatro() -> PRTeatro: return get_runtime_room("Teatro")
func get_Calle() -> PRCalle: return get_runtime_room("Calle")
func get_Recepcion() -> PRRecepcion: return get_runtime_room("Recepcion")
# ---- functions

