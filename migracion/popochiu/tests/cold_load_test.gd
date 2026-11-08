extends Node

const SLOT := 987653
const Composition := preload("composition_check.gd")
var _owns_save := false
var _failed := false


func _ready() -> void:
	get_tree().create_timer(30.0).timeout.connect(func (): _check(false, "timeout"))


func _process(_delta: float) -> void:
	G.gui.completar_dialogo(true)


func run() -> void:
	reparent(get_tree().root)
	var path := "user://save_%d.json" % SLOT
	if not _check(FileAccess.file_exists(path), "Falta la partida creada por --full-test --retain-full-save"):
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not _check(data is Dictionary and data.get("description") == "Habitación 101 - 3/3 sellos", "Slot no reconocido, no se modifica"):
		return
	_owns_save = true
	E.load_game(SLOT)
	await E.game_loaded
	await get_tree().process_frame
	var room: PopochiuRoom = R.current
	for obj: ObjetoInteractivo in room.get_props():
		obj._sacudir()
	await get_tree().create_timer(0.3).timeout
	var composition_error: String = Composition.error_en(room)
	if not _check(composition_error.is_empty(), "Composición original en frío: " + composition_error):
		return
	if not _check(room.script_name == "Habitacion101" and room.state.mision_completada and room.state.sombra_gigante_activada and Globals.sellos == 3 and Globals.vela_101 == 100.0, "Misión completa al reiniciar Godot"):
		return
	if not _check(room.get_prop("Lumi").estado == Lumi.Estado.CUIDADA and room.get_prop("Lumi").get_node("Sprite").animation == &"cuidada" and room.get_prop("Ramon").get_node("Sprite").animation == &"sonando" and room.get_prop("Cortina").get_node("Sprite").animation == &"baila", "Estados visuales al arrancar en frío"):
		return
	if not _check(C.player.inventory.size() == 1 and Globals.tiene(&"dentadura") and not Globals.tiene(&"ovillo") and room.state.ovi_en_ventana and room.get_prop("Ovillo").visible and not room.get_prop("Dentadura").visible and I.active == null, "Inventario y objetos consumidos sin caché anterior"):
		return
	if not _check(G.gui.ui.visible and G.gui.ui._casilleros[0].text == "S" and G.gui.ui._vela.value == 100.0 and not G.is_blocked and not room.ocupado, "HUD y entrada restaurados"):
		return
	DirAccess.remove_absolute(path)
	_owns_save = false
	print("COLD LOAD PASS: proceso nuevo, misión, estados visuales, inventario, consumo de Ovi y HUD")
	get_tree().quit(0)


func _check(condition: bool, message: String) -> bool:
	if _failed:
		return false
	if not condition:
		_failed = true
		push_error("COLD LOAD FAIL: " + message)
		if _owns_save:
			DirAccess.remove_absolute("user://save_%d.json" % SLOT)
		get_tree().quit(1)
	return condition
