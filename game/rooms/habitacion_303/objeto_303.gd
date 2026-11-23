extends ObjetoAnimado
## Objeto animado de la 303 con zona de clic ajustada al dibujo.
## Las tiras de Aseprite tienen aire transparente alrededor (el placard, sobre todo);
## sin esto, el clic agarraría medio cuarto.

@export var zona_clic := Rect2()  ## En píxeles del cuadro (arriba-izquierda = 0,0). Vacía = todo el cuadro.


func _rect_local() -> Rect2:
	var base := Rect2(Vector2(-floorf(tamano.x / 2.0), -tamano.y), tamano)
	if zona_clic.size == Vector2.ZERO:
		return base
	return Rect2(base.position + zona_clic.position, zona_clic.size)
