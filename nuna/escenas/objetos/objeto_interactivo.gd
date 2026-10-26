class_name ObjetoInteractivo
extends Node2D
## Un objeto con el que Nuna puede interactuar.
## El punto (0, 0) del nodo es la BASE del objeto: abajo, al centro.
## Por ahora se dibuja como un rectángulo de color (placeholder).

signal mirado(objeto: ObjetoInteractivo)
signal perturbado(objeto: ObjetoInteractivo)
signal agarrado(objeto: ObjetoInteractivo)

@export var id: StringName = &"objeto"            ## Nombre interno, sin espacios ni tildes: lampara
@export var nombre_desconocido: String = "algo"    ## Cómo se ve antes de mirarlo: lámpara
@export var nombre: String = "Objeto"              ## El nombre que le pone Nuna: Lumi
@export var frase_mirar: String = "¡Hola!"         ## Lo que dice Nuna al mirarlo
@export var puede_perturbar: bool = true
@export var puede_agarrar: bool = false
@export var frase_agarrar: String = "¡Te llevo!"
@export var tamano: Vector2 = Vector2(12, 16)      ## Ancho y alto del rectángulo
@export var color: Color = Color(0.7, 0.7, 0.7)
@export var distancia_uso: float = -16.0           ## Dónde se para Nuna: negativo = a la izquierda

var nombrado: bool = false
var _tiempo: float = 0.0
var _x_base: float = 0.0


func _ready() -> void:
	add_to_group("interactivos")
	_x_base = position.x


func _process(delta: float) -> void:
	_tiempo += delta
	queue_redraw()  # vuelve a dibujar para que el brillo titile


func _draw() -> void:
	var rect := Rect2(Vector2(-tamano.x / 2.0, -tamano.y), tamano)
	draw_rect(rect, color)
	# Brillo: un borde amarillo que titila mientras Nuna no lo miró
	if not nombrado:
		var alfa: float = 0.35 + 0.35 * sin(_tiempo * 4.0)
		draw_rect(rect.grow(1.0), Color(1.0, 0.9, 0.3, alfa), false, 1.0)


## ¿El punto (en coordenadas de pantalla) cae sobre este objeto?
func contiene(punto: Vector2) -> bool:
	var rect := Rect2(global_position + Vector2(-tamano.x / 2.0, -tamano.y), tamano)
	return rect.has_point(punto)


## El nombre que se muestra en la línea de acción.
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
			return "Mejor no lo molesto."
		if not nombrado:
			return "¡Ay, todavía no nos presentamos!"
		perturbado.emit(self)
		_sacudir()
		return ""

	if verbo == GameState.AGARRAR:
		if not puede_agarrar:
			return "No puedo llevarme eso."
		agarrado.emit(self)
		visible = false
		remove_from_group("interactivos")  # ya no se puede hacer clic en él
		return frase_agarrar

	return ""


## Placeholder de "perturbar": el objeto tiembla.
func _sacudir() -> void:
	var tw := create_tween()
	for i in 3:
		tw.tween_property(self, "position:x", _x_base + 2.0, 0.04)
		tw.tween_property(self, "position:x", _x_base - 2.0, 0.04)
	tw.tween_property(self, "position:x", _x_base, 0.04)
