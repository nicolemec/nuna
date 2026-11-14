extends Node

var _blocked := false
var _unblocked := false


func _ready() -> void:
	get_tree().create_timer(10.0).timeout.connect(func ():
		push_error("SMOKE FAIL: tiempo de espera agotado")
		get_tree().quit(1)
	)


func run(room: PopochiuRoom) -> void:
	var lock = JSON.parse_string(FileAccess.get_file_as_string("res://framework.lock.json"))
	var version := Engine.get_version_info()
	var engine_version := "%s.%s.%s" % [version.major, version.minor, version.patch]
	var plugin := ConfigFile.new()
	if plugin.load("res://addons/popochiu/plugin.cfg") != OK:
		_fail("No se pudo leer la version del framework")
		return
	if lock == null or engine_version != lock.engine.version:
		_fail("Godot no coincide con la version fijada")
		return
	if plugin.get_value("plugin", "version") != lock.framework.version:
		_fail("Popochiu no coincide con la version fijada")
		return
	if R.current != room or room.script_name != "BaseTecnica":
		_fail("La habitacion tecnica no es la habitacion activa")
		return
	if not R.rooms_states.has("BaseTecnica") or not room.state.visited:
		_fail("El estado de la habitacion no fue registrado")
		return
	if get_tree().root.has_node("GameState"):
		_fail("El estado del prototipo se filtro al proyecto de migracion")
		return
	if get_viewport().get_visible_rect().size != Vector2(320, 180):
		_fail("La resolucion no es 320 x 180")
		return
	if E.gui == null or E.commands == null or T.tl == null:
		_fail("Falta la interfaz, comandos o transiciones")
		return

	G.blocked.connect(func (): _blocked = true)
	G.unblocked.connect(func (): _unblocked = true)
	await room._verificar_secuencia()
	if not _blocked or not _unblocked or E.playing_queue:
		_fail("La secuencia no bloqueo y libero correctamente la entrada")
		return
	if room.get_node("Panel/Verificar").disabled:
		_fail("El boton quedo bloqueado")
		return
	if room.get_node("Panel/Estado").text != "Secuencia completada. Base operativa.":
		_fail("La secuencia no completo su ultima instruccion")
		return

	print("SMOKE PASS: habitacion, estado, aislamiento, resolucion y secuencia Popochiu")
	if is_instance_valid(C.player) and not C.player.is_inside_tree():
		C.player.free()
	get_tree().quit(0)


func _fail(message: String) -> void:
	push_error("SMOKE FAIL: " + message)
	get_tree().quit(1)
