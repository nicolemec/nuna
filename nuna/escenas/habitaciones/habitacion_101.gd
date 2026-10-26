extends Node2D
## Habitación 101 · prototipo gris.
## Paso 2: clic en el piso = moverse; clic en un objeto = ir y usar el verbo elegido.

@onready var nuna: Nuna = $Nuna
@onready var marcador: ColorRect = $Marcador
@onready var ui: InterfazUI = $UI

var objeto_pendiente: ObjetoInteractivo = null  # el objeto hacia el que va Nuna
var verbo_pendiente: StringName = &""


func _ready() -> void:
	marcador.visible = false
	nuna.llego.connect(_on_nuna_llego)


func _process(_delta: float) -> void:
	# Línea de acción: "Mirar lámpara", "Perturbar Lumi"...
	var texto: String = GameState.NOMBRES_VERBOS[GameState.verbo_actual]
	var obj: ObjetoInteractivo = _objeto_en(get_global_mouse_position())
	if obj != null:
		texto += " " + obj.nombre_visible()
	ui.mostrar_accion(texto)


func _unhandled_input(event: InputEvent) -> void:
	var boton := event as InputEventMouseButton
	if boton == null or not boton.pressed or boton.button_index != MOUSE_BUTTON_LEFT:
		return

	var clic: Vector2 = get_global_mouse_position()
	if clic.y >= Ajustes.UI_Y:
		return  # clic en la franja de interfaz

	var obj: ObjetoInteractivo = _objeto_en(clic)
	if obj != null:
		# Clic en un objeto: Nuna va hasta él y, al llegar, usa el verbo
		objeto_pendiente = obj
		verbo_pendiente = GameState.verbo_actual
		_mover_nuna(obj.punto_de_uso())
	else:
		# Clic en el piso o la pared: solo moverse
		objeto_pendiente = null
		var destino := Vector2(
			clampf(clic.x, Ajustes.LIMITE_X_MIN, Ajustes.LIMITE_X_MAX),
			clampf(clic.y, Ajustes.PISO_Y_MIN, Ajustes.PISO_Y_MAX)
		)
		_mover_nuna(destino)


func _mover_nuna(destino: Vector2) -> void:
	nuna.ir_a(destino)
	marcador.position = destino - marcador.size / 2.0
	marcador.visible = true


func _on_nuna_llego() -> void:
	marcador.visible = false
	if objeto_pendiente == null:
		return
	var obj: ObjetoInteractivo = objeto_pendiente
	objeto_pendiente = null
	nuna.mirar_a(obj.global_position.x)
	nuna.interactuar()
	var frase: String = obj.ejecutar(verbo_pendiente)
	nuna.decir(frase)


## Devuelve el objeto que está bajo el punto, o null si no hay ninguno.
func _objeto_en(punto: Vector2) -> ObjetoInteractivo:
	var lista: Array[Node] = get_tree().get_nodes_in_group("interactivos")
	for i in range(lista.size() - 1, -1, -1):  # de atrás hacia adelante: gana el de arriba
		var o := lista[i] as ObjetoInteractivo
		if o != null and o.contiene(punto):
			return o
	return null
