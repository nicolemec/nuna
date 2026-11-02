extends Node
## Estado global del juego. Autoload con el nombre "GameState".

signal verbo_cambiado(verbo: StringName)
signal inventario_cambiado
signal sellos_cambiados(cantidad: int)
signal bruma_cambiada(valor: float)
signal vela_cambiada(habitacion_id: StringName, valor: float)

const MIRAR := &"mirar"
const AGARRAR := &"agarrar"
const PERTURBAR := &"perturbar"

## Texto de cada botón, en el orden de la barra.
const NOMBRES_VERBOS: Dictionary = {
	&"mirar": "Mirar",
	&"agarrar": "Agarrar",
	&"perturbar": "Perturbar",
}
## Verbos que se ven con candado.
const VERBOS_BLOQUEADOS: Array = ["Manifestar", "Aparecer", "Poseer", "Aterrorizar"]
const SELLOS_TOTALES: int = 3

var verbo_actual: StringName = MIRAR
var inventario: Array[StringName] = []
var _nombres_inventario: Dictionary = {}
var sellos: int = 0
var sellos_obtenidos: Array[StringName] = []
var bruma: float = 50.0
var velas_por_habitacion: Dictionary = {}
var pausado: bool = false

var _goteo_iniciado: bool = false
var _temporizador_goteo: Timer


func _ready() -> void:
	_temporizador_goteo = Timer.new()
	_temporizador_goteo.wait_time = Ajustes.BRUMA_GOTEO_INTERVALO_SEGUNDOS
	_temporizador_goteo.timeout.connect(_drenar_bruma)
	add_child(_temporizador_goteo)


func _process(_delta: float) -> void:
	if _temporizador_goteo != null:
		_temporizador_goteo.paused = pausado


func elegir_verbo(verbo: StringName) -> void:
	verbo_actual = verbo
	verbo_cambiado.emit(verbo)


func agregar_objeto(id: StringName, nombre: String) -> void:
	if inventario.has(id):
		return
	inventario.append(id)
	_nombres_inventario[id] = nombre
	inventario_cambiado.emit()


func quitar_objeto(id: StringName) -> void:
	if inventario.has(id):
		inventario.erase(id)
		inventario_cambiado.emit()


func tiene(id: StringName) -> bool:
	return inventario.has(id)


func nombre_objeto(id: StringName) -> String:
	return _nombres_inventario.get(id, String(id))


func sumar_sello() -> void:
	if sellos >= SELLOS_TOTALES:
		return
	sellos += 1
	sellos_cambiados.emit(sellos)


func otorgar_sello(id: StringName) -> bool:
	if sellos_obtenidos.has(id) or sellos >= SELLOS_TOTALES:
		return false
	sellos_obtenidos.append(id)
	sellos += 1
	cambiar_bruma(Ajustes.BRUMA_RECOMPENSA_SELLO)
	sellos_cambiados.emit(sellos)
	return true


func cambiar_bruma(cantidad: float) -> void:
	bruma = clampf(bruma + cantidad, 0.0, 100.0)
	bruma_cambiada.emit(bruma)


func iniciar_goteo() -> void:
	if _goteo_iniciado:
		return
	_goteo_iniciado = true
	_temporizador_goteo.start()


func _drenar_bruma() -> void:
	cambiar_bruma(-Ajustes.BRUMA_GOTEO_CANTIDAD)


func vela_de(habitacion_id: StringName) -> float:
	return float(velas_por_habitacion.get(habitacion_id, 0.0))


func aumentar_vela(habitacion_id: StringName, cantidad: float) -> void:
	var valor := clampf(vela_de(habitacion_id) + cantidad, 0.0, Ajustes.VELA_MAXIMA)
	velas_por_habitacion[habitacion_id] = valor
	vela_cambiada.emit(habitacion_id, valor)


func llenar_vela(habitacion_id: StringName) -> void:
	velas_por_habitacion[habitacion_id] = Ajustes.VELA_MAXIMA
	vela_cambiada.emit(habitacion_id, Ajustes.VELA_MAXIMA)
