@tool
extends SalaIntro
## TOMA 1 — Teatro: Nuna se gradúa. Es automática: la felicitación institucional, salto,
## confetti, festejo, la letra chica y a la calle.
## La "graduación" es en realidad la bienvenida a la muerte: solemne, con una advertencia.

const Data := preload("room_teatro_state.gd")
const CONFETTI_PNG := "res://arte/objetos/confetti.png"
const CONFETTI_JSON := "res://arte/objetos/confetti.json"
const RUTA_FUENTE := "res://arte/fuentes/monogram-extended.ttf"
## Textos de la ceremonia (se pueden cambiar acá).
const TITULO := "¡FELICITACIONES!"
const FRASE := "Tu descanso eterno comienza ahora.*"
const LETRA_CHICA := "*Sujeto a cumplimiento de cuota."
const COLOR_TITULO := Color8(251, 242, 54)
const COLOR_FRASE := Color8(203, 219, 252)
const COLOR_LETRA_CHICA := Color8(155, 173, 183)
const COLOR_SOMBRA := Color8(34, 32, 52)
# El fondo usa el cuadro 1 de escenario.png (el cuadro 0 del .aseprite está vacío).

var state: Data = load("res://game/rooms/teatro/room_teatro.tres")
var _confetti: AnimatedSprite2D
var _sonido_confetti: AudioStreamPlayer
var _carteles: CanvasLayer


func _on_room_entered() -> void:
	super()
	ocupado = true  # toda la toma es una cinemática
	C.player.position = $Markers/Nuna.position
	C.player.volver_a_reposo_frontal()
	_poner_alfa_nuna(1.0)  # recién graduado: todavía entero
	_confetti = AnimatedSprite2D.new()
	_confetti.centered = false
	_confetti.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_confetti.sprite_frames = SpriteJson.cargar(CONFETTI_JSON, CONFETTI_PNG, {}, ["nace", "explota"])
	_confetti.hide()
	# El confetti va detrás de Nuna: dentro del nodo Confetti, que está antes que Characters.
	$Confetti.add_child(_confetti)
	_sonido_confetti = AudioStreamPlayer.new()
	_sonido_confetti.stream = Chip.confetti()
	_sonido_confetti.volume_db = -8.0
	add_child(_sonido_confetti)


func _on_room_transition_finished() -> void:
	_carteles = CanvasLayer.new()
	_carteles.layer = 5
	add_child(_carteles)
	await E.wait(0.6)
	var titulo := await _cartel(TITULO, 14, 32, COLOR_TITULO)
	await E.wait(0.5)
	var frase := await _cartel(FRASE, 44, 16, COLOR_FRASE)
	await E.wait(0.3)
	_tirar_confetti()
	await C.player.mini_salto()
	await C.player.celebrar()
	# Y la advertencia, en letra chica.
	var letra_chica := await _cartel(LETRA_CHICA, 60, 16, COLOR_LETRA_CHICA)
	await E.wait(1.4)
	for cartel: Label in [titulo, frase, letra_chica]:
		_fundir(cartel, 0.0)
	await E.wait(0.5)
	state.celebracion_vista = true
	_ir_a("Calle")


## Un texto centrado arriba, sobre el fondo oscuro del escenario, con la voz de flauta.
## Aparece en tres escalones de transparencia (nada de fundidos suaves: pixel art).
func _cartel(texto: String, y: int, tamano: int, color: Color) -> Label:
	var cartel := Label.new()
	cartel.text = texto
	cartel.position = Vector2(0, y)
	cartel.size = Vector2(320, tamano + 4)
	cartel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cartel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	cartel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(RUTA_FUENTE):
		cartel.add_theme_font_override("font", load(RUTA_FUENTE))
	cartel.add_theme_font_size_override("font_size", tamano)
	cartel.add_theme_color_override("font_color", color)
	cartel.add_theme_color_override("font_shadow_color", COLOR_SOMBRA)
	cartel.add_theme_constant_override("shadow_offset_x", 0)
	cartel.add_theme_constant_override("shadow_offset_y", 1 if tamano <= 16 else 2)
	cartel.modulate.a = 0.0
	_carteles.add_child(cartel)
	G.gui.voz("CEREMONIA: " + texto.replace("*", ""))
	await _fundir(cartel, 1.0)
	# Que la flauta termine antes de seguir.
	await E.wait(clampf(texto.length() * 0.07, 0.8, 2.4))
	return cartel


func _fundir(cartel: Label, hasta: float) -> void:
	var desde := cartel.modulate.a
	for escalon in [0.34, 0.67, 1.0]:
		if not is_instance_valid(cartel):
			return
		cartel.modulate.a = lerpf(desde, hasta, escalon)
		await get_tree().create_timer(0.08).timeout


func _tirar_confetti() -> void:
	_confetti.show()
	_confetti.play(&"nace")
	await _confetti.animation_finished
	_confetti.play(&"explota")
	_sonido_confetti.play()
	await _confetti.animation_finished
	_confetti.play(&"caido")


# ---------- Saltar ----------

func _sala_siguiente() -> String:
	return "Calle"


func _completar_esta_sala() -> void:
	state.celebracion_vista = true
