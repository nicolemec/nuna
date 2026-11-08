class_name Lumi
extends ObjetoInteractivo

signal combo_sombra_activado
signal susto_chico
signal fogonazo_realizado

enum Estado {
	APAGADA,
	NIVEL_1,
	NIVEL_2,
	NIVEL_3,
	CUIDADA,
	QUEMADA,
}

const FRASE_ETIQUETA: String = "¡Los mejores aprendices nunca se apagan!"
const FRASE_LETRA_CHICA: String = "(Repuestos no incluidos.)"
const FRASE_AGARRAR_LUMI: String = "Está enchufada… ¡qué responsable!"

# Popochiu persists plain script-variable integers; enum-typed properties have extra usage flags.
var estado: int = Estado.APAGADA
var mirada_inicial: bool = false
var segundos_quemada := 0.0

var _niveles_recompensados: Array[int] = []
var _fogonazo_recompensado: bool = false
var _certificacion_pendiente: bool = false
var _iniciar_temporizador_quemada: bool = false
var _bloqueo_hasta_msec: int = 0
var _anim_sprite: AnimatedSprite2D
var _temporizador_quemada: Timer


func _ready() -> void:
	super._ready()
	frase_agarrar = FRASE_AGARRAR_LUMI
	_anim_sprite = AnimatedSprite2D.new()
	_anim_sprite.name = "Sprite"
	_anim_sprite.position = Ajustes.LUMI_SPRITE_OFFSET
	_anim_sprite.centered = true
	_anim_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_anim_sprite)
	var sprite_frames: SpriteFrames = AsepriteCargador.crear_desde_tira(
		Ajustes.LUMI_RUTA_TIRA,
		Ajustes.LUMI_FRAME_ANCHO,
		Ajustes.LUMI_FRAME_ALTO,
		Ajustes.LUMI_ETIQUETAS,
		Ajustes.LUMI_FPS_BASE,
		Ajustes.LUMI_ANIMACIONES_SIN_LOOP
	)
	if sprite_frames == null:
		push_error("No se pudieron crear las animaciones de Lumi.")
	else:
		sprite_frames.set_animation_speed(&"sube", Ajustes.LUMI_FPS_SUBE)
		sprite_frames.set_animation_speed(&"nivel_3", Ajustes.LUMI_FPS_NIVEL_3)
		sprite_frames.set_animation_speed(&"fogonazo", Ajustes.LUMI_FPS_FOGONAZO)
		sprite_frames.set_animation_speed(&"quemada", Ajustes.LUMI_FPS_QUEMADA)
		_anim_sprite.sprite_frames = sprite_frames
	_anim_sprite.animation_finished.connect(_al_terminar_animacion)
	_temporizador_quemada = Timer.new()
	_temporizador_quemada.one_shot = true
	_temporizador_quemada.timeout.connect(_volver_a_apagada)
	add_child(_temporizador_quemada)
	_reproducir_animacion(&"apagada")


func _process(delta: float) -> void:
	super(delta)
	_temporizador_quemada.paused = G.gui.partida_pausada()
	if estado == Estado.QUEMADA and not _temporizador_quemada.is_stopped():
		segundos_quemada = _temporizador_quemada.time_left


func restaurar() -> void:
	_bloqueo_hasta_msec = 0
	_certificacion_pendiente = false
	_iniciar_temporizador_quemada = false
	var animaciones := ["apagada", "nivel_1", "nivel_2", "nivel_3", "cuidada", "quemada"]
	_reproducir_animacion(animaciones[estado])
	if estado == Estado.QUEMADA:
		_temporizador_quemada.start(maxf(0.01, segundos_quemada))


func _draw() -> void:
	pass


func resolver_accion(verbo: StringName, cortina_bailando: bool) -> Array[String]:
	if verbo == Globals.MIRAR:
		return obtener_frases_mirar()
	if verbo == Globals.PERTURBAR:
		return obtener_frases_perturbar(cortina_bailando)
	if verbo == Globals.AGARRAR:
		return [FRASE_AGARRAR_LUMI]
	return []


func obtener_frases_mirar() -> Array[String]:
	nombrado = true
	mirado.emit(self)
	match estado:
		Estado.APAGADA:
			if not mirada_inicial:
				mirada_inicial = true
				_certificacion_pendiente = true
				return ["¡Hola, lámpara! Te llamaré Lumi.", "¿Nunca se apagan? ¡Hay que encenderla!"]
			return ["Lumi está apagadita."]
		Estado.NIVEL_1:
			return ["Tiene algo grabado… no llego a leerlo."]
		Estado.NIVEL_2:
			return ["¡Ya casi lo leo! Un poquito más de luz…"]
		Estado.NIVEL_3:
			estado = Estado.CUIDADA
			_reproducir_animacion(&"cuidada")
			Globals.otorgar_sello(&"lumi")
			return ["Garantía: 3 noches.", "Lumi, ya diste suficiente. Quédate así."]
		Estado.CUIDADA:
			return ["Lumi brilla tranquila. Ya no corre peligro."]
		Estado.QUEMADA:
			return ["Lumi necesita un ratito."]
	return []


func obtener_frases_perturbar(cortina_bailando: bool) -> Array[String]:
	if not nombrado or not puede_perturbar:
		return [super.ejecutar(Globals.PERTURBAR)]
	if estado == Estado.QUEMADA:
		return ["Lumi necesita un ratito."]
	if estado == Estado.CUIDADA:
		if cortina_bailando:
			combo_sombra_activado.emit()
			return ["¡Lumi, Doña Cortina, son un equipo!"]
		return ["Lumi está lista. ¿Y Doña Cortina?"]

	Globals.iniciar_goteo()
	Globals.cambiar_bruma(-Ajustes.LUMI_COSTO_PERTURBAR_BRUMA)
	perturbado.emit(self)
	_sacudir()
	match estado:
		Estado.APAGADA:
			estado = Estado.NIVEL_1
			susto_chico.emit()
			_aplicar_recompensa_nivel(Estado.NIVEL_1)
			_bloquear_clics()
			_reproducir_animacion(&"sube")
			return ["¡Arriba, Lumi!"]
		Estado.NIVEL_1:
			estado = Estado.NIVEL_2
			susto_chico.emit()
			_aplicar_recompensa_nivel(Estado.NIVEL_2)
			_bloquear_clics()
			_reproducir_animacion(&"sube")
			return ["¡Más brillo! ¡Más rendimiento!"]
		Estado.NIVEL_2:
			estado = Estado.NIVEL_3
			susto_chico.emit()
			_aplicar_recompensa_nivel(Estado.NIVEL_3)
			_bloquear_clics()
			_reproducir_animacion(&"sube")
			return ["¡Brillas como una profesional!", "Lumi… ¿estás transpirando?"]
		Estado.NIVEL_3:
			Globals.cambiar_bruma(-Ajustes.LUMI_COSTO_BRUMA_FOGONAZO)
			estado = Estado.QUEMADA
			_reproducir_animacion(&"fogonazo")
			fogonazo_realizado.emit()
			if not _fogonazo_recompensado:
				_fogonazo_recompensado = true
				Globals.aumentar_vela(Ajustes.LUMI_HABITACION_ID, Ajustes.LUMI_RECOMPENSA_VELA_FOGONAZO)
			_iniciar_temporizador_quemada = true
			return ["¡WOW, Lumi!", "¡Perdón, Lumi!"]
	return []


func certificacion_pendiente_despues_de_frase(indice: int) -> bool:
	if indice != 0 or not _certificacion_pendiente:
		return false
	_certificacion_pendiente = false
	return true


func completar_dialogo() -> void:
	if not _iniciar_temporizador_quemada:
		return
	_iniciar_temporizador_quemada = false
	segundos_quemada = Ajustes.LUMI_DURACION_QUEMADA_SEGUNDOS
	_temporizador_quemada.start(segundos_quemada)


func esperar_bloqueo() -> void:
	var milisegundos_restantes := _bloqueo_hasta_msec - Time.get_ticks_msec()
	if milisegundos_restantes > 0:
		await get_tree().create_timer(float(milisegundos_restantes) / 1000.0).timeout


func _aplicar_recompensa_nivel(nivel: Estado) -> void:
	if _niveles_recompensados.has(nivel):
		return
	_niveles_recompensados.append(nivel)
	Globals.cambiar_bruma(Ajustes.LUMI_RECOMPENSA_BRUMA_NIVEL)
	Globals.aumentar_vela(Ajustes.LUMI_HABITACION_ID, Ajustes.LUMI_RECOMPENSA_VELA_NIVEL)


func _bloquear_clics() -> void:
	_bloqueo_hasta_msec = Time.get_ticks_msec() + int(Ajustes.LUMI_BLOQUEO_CLICS_SEGUNDOS * 1000.0)


func _reproducir_animacion(nombre: StringName) -> void:
	if _anim_sprite == null or _anim_sprite.sprite_frames == null:
		return
	_anim_sprite.play(nombre)


func _al_terminar_animacion() -> void:
	match _anim_sprite.animation:
		&"sube":
			match estado:
				Estado.NIVEL_1:
					_reproducir_animacion(&"nivel_1")
				Estado.NIVEL_2:
					_reproducir_animacion(&"nivel_2")
				Estado.NIVEL_3:
					_reproducir_animacion(&"nivel_3")
		&"fogonazo":
			_reproducir_animacion(&"quemada")


func _volver_a_apagada() -> void:
	segundos_quemada = 0.0
	estado = Estado.APAGADA
	_reproducir_animacion(&"apagada")
