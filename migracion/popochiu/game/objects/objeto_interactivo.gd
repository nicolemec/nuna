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
# El anclaje es visual, no progreso: Vector2 queda fuera del snapshot de Props.
var _posicion_base := Vector2.ZERO
var _sacudida: Tween


func _ready() -> void:
	super()
	$Sprite2D.hide()
	add_to_group("interactivos")
	_posicion_base = position
	if textura != null:
		tamano = textura.get_size()
	var rect := _rect_local()
	interaction_polygon = PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])


func _process(delta: float) -> void:
	_tiempo += delta
	queue_redraw()


## El rectángulo del objeto, alineado a pixeles enteros.
func _rect_local() -> Rect2:
	return Rect2(Vector2(-floorf(tamano.x / 2.0), -tamano.y), tamano)


func _draw() -> void:
	var rect: Rect2 = _rect_local()
	if textura != null:
		draw_texture(textura, rect.position)
	else:
		draw_rect(rect, color)
	# Brillo: un borde amarillo que titila mientras Nuna no lo miró
	if not nombrado:
		var alfa: float = 0.35 + 0.35 * sin(_tiempo * 4.0)
		draw_rect(rect.grow(1.0), Color(1.0, 0.9, 0.3, alfa), false, 1.0)


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
	var x: float = clampf(global_position.x + distancia_uso, Ajustes.LIMITE_X_MIN, Ajustes.LIMITE_X_MAX)
	return Vector2(x, Ajustes.PISO_Y_MIN + 4.0)


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


func restaurar_posicion() -> void:
	if _sacudida != null and _sacudida.is_valid():
		_sacudida.kill()
	position = _posicion_base


## Placeholder de "perturbar": el objeto tiembla.
func _sacudir() -> void:
	restaurar_posicion()
	_sacudida = create_tween()
	for i in 3:
		_sacudida.tween_property(self, "position:x", _posicion_base.x + 2.0, 0.04)
		_sacudida.tween_property(self, "position:x", _posicion_base.x - 2.0, 0.04)
	_sacudida.tween_property(self, "position:x", _posicion_base.x, 0.04)

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
	await super(viewport, event, shape_idx)


func _on_click() -> void:
	R.current.seleccionar_objeto(self)


func _on_double_click() -> void:
	_on_click()


func _on_right_click() -> void:
	_on_click()


func _on_item_used(item: PopochiuInventoryItem) -> void:
	R.current.usar_objeto(item, self)