class_name ObjetoInteractivo
extends Node2D
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
var _tiempo: float = 0.0
var _x_base: float = 0.0


func _ready() -> void:
	add_to_group("interactivos")
	_x_base = position.x
	if textura != null:
		tamano = textura.get_size()


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
	if verbo == GameState.MIRAR:
		nombrado = true
		mirado.emit(self)
		return frase_mirar

	if verbo == GameState.PERTURBAR:
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

	if verbo == GameState.AGARRAR:
		if not puede_agarrar:
			if not frase_agarrar.is_empty():
				return frase_agarrar
			return "No puedo llevarme eso."
		agarrado.emit(self)
		visible = false
		remove_from_group("interactivos")
		return frase_agarrar

	return ""


## Placeholder de "perturbar": el objeto tiembla.
func _sacudir() -> void:
	var tw := create_tween()
	for i in 3:
		tw.tween_property(self, "position:x", _x_base + 2.0, 0.04)
		tw.tween_property(self, "position:x", _x_base - 2.0, 0.04)
	tw.tween_property(self, "position:x", _x_base, 0.04)
