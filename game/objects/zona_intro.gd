class_name ZonaIntro
extends ObjetoInteractivo
## Algo clickeable de la intro que ya está dibujado en el fondo: un cartel, una puerta, el timbre.
## No dibuja un objeto propio. Cuando "resaltar" está activo, repite su pedazo del fondo y lo
## hace latir (el mismo brillo que usan los objetos de la 101 antes de mirarlos).
## Las subclases (fantasma, lámpara, viejo) agregan su propio sprite animado.

## true: un clic alcanza (Nuna va y mira). false: muestra los verbos en la consola.
@export var accion_directa := true

var resaltar := false: set = set_resaltar
var recorte: Texture2D


func set_resaltar(valor: bool) -> void:
	resaltar = valor
	queue_redraw()


## Toma del fondo el pedazo que ocupa la zona, para poder hacerlo brillar o saltar.
func recortar_de(fondo: Texture2D) -> void:
	var rect := _rect_local()
	var atlas := AtlasTexture.new()
	atlas.atlas = fondo
	atlas.region = Rect2(global_position + rect.position, rect.size)
	recorte = atlas
	queue_redraw()


func _aplicar_latido() -> void:
	var luz := 1.0
	if resaltar and clickable:
		luz = 1.0 + 0.35 * (0.5 + 0.5 * sin(_tiempo * 3.0))
	var tinte := Color(luz, luz, luz, 1.0)
	self_modulate = tinte
	for hijo in get_children():
		if hijo is AnimatedSprite2D:
			hijo.self_modulate = tinte


func _draw() -> void:
	if resaltar and recorte != null:
		draw_texture(recorte, _rect_local().position)


## Un saltito (el timbre al sonar). Usa el recorte del fondo.
func saltar() -> void:
	var estaba := resaltar
	if recorte != null:
		resaltar = true
	restaurar_posicion()
	var base_y := position.y
	var tw := create_tween()
	tw.tween_property(self, "position:y", base_y - 2.0, 0.06)
	tw.tween_property(self, "position:y", base_y, 0.06)
	tw.tween_property(self, "position:y", base_y - 1.0, 0.05)
	tw.tween_property(self, "position:y", base_y, 0.05)
	await tw.finished
	resaltar = estaba
