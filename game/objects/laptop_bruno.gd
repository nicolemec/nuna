class_name LaptopBruno
extends ObjetoAnimado
## La laptop de Bruno: normal → recalienta → humo → quemada (como Lumi en la 101).
## Por ahora se quema al perturbarla; cuando exista el reloj, la sala lo cambia
## por el puzzle de "PARA AYER" (ver el documento, sello 1 de la 202).

signal se_quemo

enum Estado { NORMAL, QUEMANDOSE, QUEMADA }
var estado: Estado = Estado.NORMAL

## Ya quemada sigue echando humito y una llamita, dibujados pixel a pixel por código
## (sin arte nuevo). Las posiciones son relativas a la base de la laptop: si no
## coinciden con el dibujo, se ajustan acá.
const HUMO_ORIGEN := Vector2(2, -30)
const LLAMA_ORIGEN := Vector2(-8, -17)
const HUMO_ALTURA := 18
const SEGUNDOS_POR_CUADRO_HUMO := 0.14
const COLOR_HUMO := [Color8(155, 155, 165, 220), Color8(118, 118, 130, 170), Color8(90, 90, 100, 110)]
const COLOR_LLAMA := [Color8(251, 242, 54), Color8(223, 113, 38), Color8(172, 50, 50)]
var _humo: Node2D
var _bocanadas: Array = []   # cada una: [x, y, edad]
var _reloj_humo := 0.0
var _cuadro_llama := 0


func reaccionar() -> void:
	if estado != Estado.NORMAL:
		_sacudir()
		return
	estado = Estado.QUEMANDOSE
	reproducir(&"recalienta")
	await _anim.animation_looped
	reproducir(&"humo")
	await _anim.animation_looped
	await _anim.animation_looped
	quemar()


func quemar() -> void:
	estado = Estado.QUEMADA
	anim_reposo = &"quemada"
	reproducir(&"quemada")
	_anim.sprite_frames.set_animation_loop(&"quemada", false)
	frase_mirar = "La pantalla quedó negra y brilla como un espejo… ¡Ahí estoy yo!"
	_prender_humo()
	se_quemo.emit()


func _prender_humo() -> void:
	if _humo != null:
		return
	_humo = Node2D.new()
	_humo.name = "Humo"
	_humo.z_index = 1
	_humo.draw.connect(_dibujar_humo)
	add_child(_humo)


func _process(delta: float) -> void:
	super._process(delta)
	if _humo == null:
		return
	_reloj_humo += delta
	if _reloj_humo < SEGUNDOS_POR_CUADRO_HUMO:
		return
	_reloj_humo = 0.0
	# Cada cuadro: las bocanadas suben 1 pixel y a veces se corren de costado.
	for b in _bocanadas:
		b[1] -= 1
		b[2] += 1
		if randf() < 0.3:
			b[0] += [-1, 1].pick_random()
	_bocanadas = _bocanadas.filter(func(b): return b[2] < HUMO_ALTURA)
	if randf() < 0.45:
		_bocanadas.append([HUMO_ORIGEN.x + randi_range(-2, 2), HUMO_ORIGEN.y, 0])
	_cuadro_llama = randi_range(0, 2)
	_humo.queue_redraw()


func _dibujar_humo() -> void:
	for b in _bocanadas:
		var tramo: int = mini(int(b[2] * COLOR_HUMO.size() / HUMO_ALTURA), COLOR_HUMO.size() - 1)
		var lado := 1 if b[2] < HUMO_ALTURA / 2 else 2  # arriba la bocanada se agranda
		_humo.draw_rect(Rect2(Vector2(b[0], b[1]), Vector2(lado, lado)), COLOR_HUMO[tramo])
	# Llamita de 3 cuadros: cambia de forma, no se desliza.
	var formas := [
		[Vector2(0, 0), Vector2(1, 0), Vector2(0, -1), Vector2(1, -2)],
		[Vector2(0, 0), Vector2(1, 0), Vector2(1, -1), Vector2(0, -2)],
		[Vector2(0, 0), Vector2(1, 0), Vector2(0, -1), Vector2(1, -1), Vector2(1, -3)],
	]
	var forma: Array = formas[_cuadro_llama]
	for i in forma.size():
		var color: Color = COLOR_LLAMA[0] if i == 0 else (COLOR_LLAMA[2] if i == forma.size() - 1 else COLOR_LLAMA[1])
		_humo.draw_rect(Rect2(LLAMA_ORIGEN + forma[i], Vector2.ONE), color)


func _on_vuelta() -> void:
	if estado == Estado.NORMAL:
		super()
