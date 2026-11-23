class_name ObjetoInteractivo
extends PopochiuProp
## Un objeto con el que Nuna puede interactuar.
## El punto (0, 0) del nodo es la BASE del objeto: abajo, al centro.
## Si tiene "textura", dibuja la imagen; si no, un rectángulo de color (placeholder).

signal mirado(objeto: ObjetoInteractivo)
signal perturbado(objeto: ObjetoInteractivo)
signal agarrado(objeto: ObjetoInteractivo)

const FRASE_PERTURBAR_GENERICA: String = "¡Buu!"

@export var id: StringName = &"objeto"            ## Nombre interno: lampara
@export var textura: Texture2D                     ## Imagen del objeto (opcional)
@export var nombre_desconocido: String = "algo"    ## Antes de mirarlo: lámpara
@export var nombre: String = "Objeto"              ## El nombre que le pone Nuna: Lumi
@export var frase_mirar: String = "¡Hola!"
@export var frase_perturbar: String = ""
@export var es_prueba: bool = false
@export var puede_perturbar: bool = true
@export var puede_agarrar: bool = false
@export var frase_agarrar: String = "¡Te llevo!"
@export var tamano: Vector2 = Vector2(12, 16)      ## Solo se usa si no hay textura
@export var color: Color = Color(0.7, 0.7, 0.7)
@export var distancia_uso: float = -16.0           ## Dónde se para Nuna: negativo = a la izquierda

var nombrado: bool = false
var recogido := false
var _tiempo: float = 0.0
## Destello "hacé clic acá": cada objeto sin mirar brilla de vez en cuando, a destiempo
## de los demás, cuadro a cuadro (sin interpolar, para no romper el pixel art).
const BRILLO_CUADROS: Array[float] = [1.15, 1.35, 1.15]
const DESTELLO_CUADROS: Array[int] = [1, 2, 1]   # 1 = punto, 2 = cruz de 3x3
const SEGUNDOS_POR_CUADRO := 0.1
const ESPERA_DESTELLO_MIN := 3.0
const ESPERA_DESTELLO_MAX := 9.0
var _espera_destello := 0.0
var _cuadro_destello := -1
var _punto_destello := Vector2.ZERO
var _destello: Node2D
## Los destellos (y el latido de la intro) solo aparecen al entrar a una sala, hasta el primer
## clic sobre un objeto, y después solo si el jugador pasa un rato largo sin tocar ningún objeto.
const SEGUNDOS_SIN_CLIC_PARA_AYUDA := 20.0
static var _sala_del_ultimo_clic := 0
static var _ultimo_clic_ms := 0
# El anclaje es visual, no progreso: Vector2 queda fuera del snapshot de Props.
var _posicion_base := Vector2.ZERO
var _sacudida: Tween


func _ready() -> void:
	super()
	$Sprite2D.hide()
	add_to_group("interactivos")
	_posicion_base = position
	_espera_destello = randf_range(0.5, ESPERA_DESTELLO_MAX)  # cada uno arranca a destiempo
	if textura != null:
		tamano = textura.get_size()
	var rect := _rect_local()
	interaction_polygon = PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])


func _process(delta: float) -> void:
	_tiempo += delta
	_avanzar_destello(delta)
	if _ayuda_permitida():
		_aplicar_latido()
	else:
		_quitar_latido()
	queue_redraw()


## ¿Toca mostrar la ayuda visual? Sí al entrar a la sala (antes del primer clic en un objeto)
## y cuando pasó mucho tiempo desde el último clic en un objeto.
func _ayuda_permitida() -> bool:
	if not is_instance_valid(R.current):
		return false
	if R.current.get_instance_id() != _sala_del_ultimo_clic:
		return true
	return Time.get_ticks_msec() - _ultimo_clic_ms > SEGUNDOS_SIN_CLIC_PARA_AYUDA * 1000.0


func _quitar_latido() -> void:
	self_modulate = Color.WHITE
	for hijo in get_children():
		if hijo is AnimatedSprite2D:
			hijo.self_modulate = Color.WHITE


## Anota cada clic que cae sobre un objeto (no lo consume: la sala lo sigue resolviendo igual).
func _input(event: InputEvent) -> void:
	if not event is InputEventMouseButton or not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return
	if not visible or not clickable or not is_instance_valid(R.current):
		return
	var punto: Vector2 = R.current.get_global_transform_with_canvas().affine_inverse() * event.position
	if contiene(punto):
		_sala_del_ultimo_clic = R.current.get_instance_id()
		_ultimo_clic_ms = Time.get_ticks_msec()


## Latido: mientras Nuna no miró el objeto, cada tanto (al azar) brilla un instante
## y le aparece una chispita en una esquina. Va por cuadros, no suave.
func _aplicar_latido() -> void:
	var luz: float = 1.0
	if _cuadro_destello >= 0:
		luz = BRILLO_CUADROS[_cuadro_destello]
	var tinte := Color(luz, luz, luz, 1.0)
	self_modulate = tinte
	for hijo in get_children():
		if hijo is AnimatedSprite2D:
			hijo.self_modulate = tinte


func _avanzar_destello(delta: float) -> void:
	if nombrado or not visible or not clickable or not _ayuda_permitida():
		if _cuadro_destello >= 0:
			_cuadro_destello = -1
			_redibujar_destello()
		return
	_espera_destello -= delta
	if _espera_destello > 0.0:
		return
	var anterior := _cuadro_destello
	if _cuadro_destello < 0:
		# Empieza un destello en un lugar al azar del borde de arriba.
		var rect := _rect_local()
		_punto_destello = Vector2(roundf(randf_range(rect.position.x + 1, rect.end.x - 2)), rect.position.y + 1)
	_cuadro_destello += 1
	if _cuadro_destello >= BRILLO_CUADROS.size():
		_cuadro_destello = -1
		_espera_destello = randf_range(ESPERA_DESTELLO_MIN, ESPERA_DESTELLO_MAX)
	else:
		_espera_destello = SEGUNDOS_POR_CUADRO
	if anterior != _cuadro_destello:
		_redibujar_destello()


func _redibujar_destello() -> void:
	if _destello == null:
		_destello = Node2D.new()
		_destello.name = "Destello"
		_destello.z_index = 1  # por encima del dibujo del objeto
		_destello.draw.connect(_dibujar_destello)
		add_child(_destello)
	_destello.queue_redraw()


func _dibujar_destello() -> void:
	if _cuadro_destello < 0:
		return
	var p := _punto_destello
	var blanco := Color(1, 1, 1, 0.9)
	_destello.draw_rect(Rect2(p, Vector2.ONE), blanco)
	if DESTELLO_CUADROS[_cuadro_destello] == 2:
		for d in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			_destello.draw_rect(Rect2(p + d, Vector2.ONE), Color(1, 1, 1, 0.55))


## El rectángulo del objeto, alineado a pixeles enteros.
func _rect_local() -> Rect2:
	return Rect2(Vector2(-floorf(tamano.x / 2.0), -tamano.y), tamano)


func _draw() -> void:
	var rect: Rect2 = _rect_local()
	if textura != null:
		draw_texture(textura, rect.position)
	else:
		draw_rect(rect, color)


## ¿El punto (en coordenadas de pantalla) cae sobre este objeto?
func contiene(punto: Vector2) -> bool:
	var rect: Rect2 = _rect_local()
	rect.position += global_position
	return rect.has_point(punto)


func nombre_visible() -> String:
	if nombrado:
		return nombre
	return nombre_desconocido


## Dónde se para Nuna para usar el objeto (siempre sobre el piso).
func punto_de_uso() -> Vector2:
	var limite_derecho: float = Ajustes.LIMITE_X_MAX
	var piso: float = Ajustes.PISO_Y_MIN + 4.0
	# Las salas de la intro son más anchas que la pantalla y tienen su propia línea de piso.
	if is_instance_valid(R.current):
		limite_derecho = maxf(limite_derecho, R.current.width - Ajustes.LIMITE_X_MIN)
		if R.current.get("piso_y") != null:
			piso = R.current.get("piso_y")
	var x: float = clampf(global_position.x + distancia_uso, Ajustes.LIMITE_X_MIN, limite_derecho)
	return Vector2(x, piso)


## Ejecuta un verbo sobre el objeto. Devuelve lo que dice Nuna ("" = nada).
func ejecutar(verbo: StringName) -> String:
	if verbo == Globals.MIRAR:
		nombrado = true
		mirado.emit(self)
		return frase_mirar

	if verbo == Globals.PERTURBAR:
		if not puede_perturbar:
			if not frase_perturbar.is_empty():
				return frase_perturbar
			return "Mejor no lo molesto."
		if not nombrado:
			return "¡Ay, todavía no nos presentamos!"
		if es_prueba:
			perturbado.emit(self)
		_sacudir()
		if es_prueba:
			return ""
		return frase_perturbar if not frase_perturbar.is_empty() else FRASE_PERTURBAR_GENERICA

	if verbo == Globals.AGARRAR:
		if not puede_agarrar:
			if not frase_agarrar.is_empty():
				return frase_agarrar
			return "No puedo llevarme eso."
		recogido = true
		agarrado.emit(self)
		visible = false
		remove_from_group("interactivos")
		return frase_agarrar

	return ""


## Cambia el lugar de reposo del objeto (por ejemplo, Ovi bajo la ventana).
func fijar_anclaje(nueva_posicion: Vector2) -> void:
	_posicion_base = nueva_posicion
	restaurar_posicion()


func restaurar_posicion() -> void:
	if _sacudida != null and _sacudida.is_valid():
		_sacudida.kill()
	position = _posicion_base


## Placeholder de "perturbar": el objeto tiembla.
func _sacudir() -> void:
	restaurar_posicion()
	# Cuadro a cuadro: salta de pixel en pixel, sin deslizarse.
	_sacudida = create_tween()
	for i in 3:
		_sacudida.tween_callback(func(): position.x = _posicion_base.x + 2.0)
		_sacudida.tween_interval(0.05)
		_sacudida.tween_callback(func(): position.x = _posicion_base.x - 2.0)
		_sacudida.tween_interval(0.05)
	_sacudida.tween_callback(func(): position = _posicion_base)

func _on_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	if G.is_blocked or E.hovered != self:
		return
	if event is InputEventMouseButton and event.pressed:
		var punto: Vector2 = R.current.get_global_transform_with_canvas().affine_inverse() * event.position
		var objetivo: ObjetoInteractivo = R.current.objeto_en(punto)
		if objetivo != null and objetivo != self:
			# Preserve the prototype's smallest-object priority without bypassing native input.
			E.remove_hovered(objetivo)
			E.add_hovered(objetivo)
			await objetivo._on_input_event(viewport, event, shape_idx)
			return
		# Con un objeto del inventario en la mano, el clic lo usa acá (sin depender de la fila
		# de Popochiu, que a veces quedaba trabada y el objeto no se usaba).
		if event.button_index == MOUSE_BUTTON_LEFT and I.active != null:
			var item: PopochiuInventoryItem = I.active
			get_viewport().set_input_as_handled()
			I.set_active_item(null)
			if R.current.has_method("usar_objeto"):
				await R.current.usar_objeto(item, self)
			return
	await super(viewport, event, shape_idx)


func _on_click() -> void:
	R.current.seleccionar_objeto(self)


func _on_double_click() -> void:
	_on_click()


func _on_right_click() -> void:
	_on_click()


func _on_item_used(item: PopochiuInventoryItem) -> void:
	R.current.usar_objeto(item, self)