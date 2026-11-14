class_name Chip
extends RefCounted
## Sonidos de consola retro hechos con código (no necesitan archivos ni importación).
## Como un chip de 4 canales: ondas de pulso, triangular y ruido; el volumen cambia
## a saltos (60 veces por segundo, 16 niveles) y la triangular tiene 16 escalones.
##
## Uso:
##   var sonido := Chip.wav(Chip.nota(&"triangulo", 523.0, 0.2))
##   reproductor.stream = sonido
## Sonidos listos: Chip.voz_viejo(), Chip.voz_fantasma(), Chip.voz_ceremonia(),
## Chip.clic(), Chip.confetti(), Chip.garabato().
## Radio de Ramón: Chip.radio_estatica(), Chip.radio_estacion(numero) y Chip.radio_reves().

const MEZCLA := 22050
const PASOS_VOLUMEN := 15.0


## Una nota. onda: &"pulso12", &"pulso25", &"pulso50", &"triangulo" o &"ruido".
## barrido: el tono final respecto del inicial (0.5 = baja una octava).
static func nota(
	onda: StringName,
	hz: float,
	segundos: float,
	volumen := 0.8,
	ataque := 0.005,
	caida := 0.05,
	vibrato_hz := 0.0,
	vibrato := 0.0,
	barrido := 1.0
) -> PackedFloat32Array:
	var total := int(MEZCLA * segundos)
	var muestras := PackedFloat32Array()
	muestras.resize(total)
	var fase := 0.0
	var ruido := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in total:
		var t := float(i) / MEZCLA
		var paso := floorf(t * 60.0) / 60.0  # el volumen y el tono cambian a saltos
		var avance := paso / maxf(segundos, 0.001)
		var f := hz * lerpf(1.0, barrido, avance)
		if vibrato_hz > 0.0:
			f *= 1.0 + vibrato * sin(TAU * vibrato_hz * paso)
		var fase_previa := fase
		fase = fmod(fase + f / MEZCLA, 1.0)
		var v := 0.0
		match onda:
			&"pulso12":
				v = 1.0 if fase < 0.125 else -1.0
			&"pulso25":
				v = 1.0 if fase < 0.25 else -1.0
			&"pulso50":
				v = 1.0 if fase < 0.5 else -1.0
			&"triangulo":
				v = roundf((4.0 * absf(fase - 0.5) - 1.0) * 7.5) / 7.5
			&"ruido":
				if fase < fase_previa:
					ruido = rng.randf_range(-1.0, 1.0)
				v = ruido
		muestras[i] = v * _envolvente(paso, segundos, ataque, caida) * volumen
	return muestras


## Suma b dentro de a, empezando en el segundo indicado.
static func mezclar(a: PackedFloat32Array, b: PackedFloat32Array, desde := 0.0) -> PackedFloat32Array:
	var inicio := int(desde * MEZCLA)
	if a.size() < inicio + b.size():
		a.resize(inicio + b.size())
	for i in b.size():
		a[inicio + i] = a[inicio + i] + b[i]
	return a


## Convierte muestras en un sonido de 8 bits listo para un AudioStreamPlayer.
static func wav(muestras: PackedFloat32Array) -> AudioStreamWAV:
	var datos := PackedByteArray()
	datos.resize(muestras.size())
	for i in muestras.size():
		var v := clampi(int(roundf(clampf(muestras[i], -1.0, 1.0) * 127.0)), -128, 127)
		datos[i] = v & 0xFF  # 8 bits con signo
	var sonido := AudioStreamWAV.new()
	sonido.format = AudioStreamWAV.FORMAT_8_BITS
	sonido.mix_rate = MEZCLA
	sonido.stereo = false
	sonido.data = datos
	return sonido


# ---------- Sonidos del juego ----------

## El viejo: grave (La2) y largo, pulso cuadrado con una triangular una octava abajo.
static func voz_viejo() -> AudioStreamWAV:
	var s := nota(&"pulso50", 110.0, 0.2, 0.5, 0.01, 0.09)
	return wav(mezclar(s, nota(&"triangulo", 55.0, 0.2, 0.45, 0.01, 0.09)))


## El fantasma del banco: grave pero apagado, triangular suave que tiembla y se apaga.
static func voz_fantasma() -> AudioStreamWAV:
	return wav(nota(&"triangulo", 147.0, 0.28, 0.9, 0.07, 0.16, 5.0, 0.025))


## La voz de la ceremonia: flauta (triangular con vibrato y entrada suave), Do5.
static func voz_ceremonia() -> AudioStreamWAV:
	var s := nota(&"triangulo", 523.25, 0.24, 0.85, 0.04, 0.1, 5.5, 0.012)
	# Un soplido muy bajito al empezar, como el aire de la flauta.
	return wav(mezclar(s, nota(&"ruido", 6000.0, 0.05, 0.08, 0.005, 0.04)))


## Clic: un tic corto y agudo.
static func clic() -> AudioStreamWAV:
	return wav(nota(&"pulso12", 1568.0, 0.035, 0.45, 0.0, 0.03, 0.0, 0.0, 0.7))


## Confetti: explota (ruido) y caen chispitas (arpegio Do-Mi-Sol-Do).
static func confetti() -> AudioStreamWAV:
	var s := nota(&"ruido", 3500.0, 0.22, 0.75, 0.0, 0.2, 0.0, 0.0, 0.4)
	var notas := [1046.5, 1318.5, 1568.0, 2093.0, 1568.0, 2093.0]
	for i in notas.size():
		s = mezclar(s, nota(&"pulso25", notas[i], 0.06, 0.28, 0.0, 0.05), 0.08 + i * 0.055)
	return wav(s)


## Firma: tres rasguños cortos de lapicera.
static func garabato() -> AudioStreamWAV:
	var s := PackedFloat32Array()
	for i in 3:
		s = mezclar(s, nota(&"ruido", 2500.0 + i * 600.0, 0.07, 0.5, 0.01, 0.04), i * 0.09)
	return wav(s)


# ---------- La radio de Ramón ----------

## Notas en Hz para escribir melodías cortas.
const _HZ := {
	&"A3": 220.0, &"B3": 246.94, &"C4": 261.63, &"D4": 293.66, &"E4": 329.63, &"F4": 349.23,
	&"G4": 392.0, &"A4": 440.0, &"B4": 493.88, &"C5": 523.25, &"D5": 587.33, &"D#5": 622.25,
	&"E5": 659.25, &"F5": 698.46, &"G5": 783.99, &"A5": 880.0, &"C6": 1046.5, &"E6": 1318.5,
}

static var _cancion_reves: AudioStreamWAV


## Estática al mover el dial: ruido agudo con un silbido que baja.
static func radio_estatica(segundos := 0.45) -> AudioStreamWAV:
	var s := nota(&"ruido", 7000.0, segundos, 0.32, 0.0, 0.12)
	s = mezclar(s, nota(&"pulso12", 2200.0, segundos, 0.12, 0.0, 0.1, 0.0, 0.0, 0.3))
	return wav(s)


## "Din": la campanita de Din (la misma que va a sonar en todo el hotel).
static func din() -> PackedFloat32Array:
	var s := nota(&"triangulo", _HZ[&"E6"], 0.35, 0.5, 0.0, 0.32)
	return mezclar(s, nota(&"pulso12", _HZ[&"E6"] * 2.0, 0.08, 0.12, 0.0, 0.07))


## Lo que suena en cada estación del dial (1 a 5). La 4 es la canción al revés (va aparte, en loop).
static func radio_estacion(numero: int) -> AudioStreamWAV:
	var s := PackedFloat32Array()
	match numero:
		1:  # Radio Mérito: jingle de propaganda, alegre y apurado. Firma: "din".
			var notas := [&"C5", &"E5", &"G5", &"C6", &"G5", &"C6"]
			for i in notas.size():
				s = mezclar(s, nota(&"pulso25", _HZ[notas[i]], 0.11, 0.35, 0.0, 0.04), i * 0.1)
			s = mezclar(s, din(), 0.7)
		2:  # Radio Ocupada: música de espera (Para Elisa, como en todos los call centers).
			var notas := [&"E5", &"D#5", &"E5", &"D#5", &"E5", &"B4", &"D5", &"C5", &"A4"]
			for i in notas.size():
				var largo := 0.4 if i == notas.size() - 1 else 0.16
				s = mezclar(s, nota(&"pulso50", _HZ[notas[i]], largo, 0.22, 0.005, 0.05), i * 0.17)
			s = mezclar(s, din(), 1.75)
		3:  # Radio Feriado: casi nada. Un zumbido muy bajito.
			s = nota(&"ruido", 1800.0, 1.2, 0.05, 0.2, 0.4)
			s = mezclar(s, nota(&"triangulo", 55.0, 1.2, 0.08, 0.2, 0.4))
		5:  # Radio Hora Extra: tic-tac y despertador.
			for i in 6:
				s = mezclar(s, nota(&"pulso12", 1400.0 if i % 2 == 0 else 1000.0, 0.03, 0.4, 0.0, 0.025), i * 0.22)
			for i in 4:
				s = mezclar(s, nota(&"pulso50", 1760.0, 0.07, 0.28, 0.0, 0.02), 1.4 + i * 0.1)
			s = mezclar(s, din(), 1.9)
		_:
			s = nota(&"ruido", 5000.0, 0.3, 0.2, 0.0, 0.1)
	return wav(s)


static func cancion_reves_lista() -> bool:
	return _cancion_reves != null


## Radio Revés: una canción de cuna (la de Brahms) tocada como cajita de música y dada vuelta.
## Al revés cada nota "crece" en vez de apagarse: suena tierno y raro a la vez. Se arma una vez.
static func radio_reves() -> AudioStreamWAV:
	if _cancion_reves != null:
		return _cancion_reves
	# [nota, duración en negras]
	var melodia := [
		[&"E4", 0.5], [&"E4", 0.5], [&"G4", 1.5], [&"E4", 0.5], [&"E4", 1.0], [&"G4", 1.0],
		[&"E4", 0.5], [&"G4", 0.5], [&"C5", 1.0], [&"B4", 1.0], [&"A4", 1.0], [&"A4", 1.0], [&"G4", 1.0],
		[&"D4", 0.5], [&"E4", 0.5], [&"F4", 1.0], [&"D4", 1.0], [&"D4", 0.5], [&"E4", 0.5], [&"F4", 2.0],
		[&"D4", 0.5], [&"F4", 0.5], [&"B4", 0.5], [&"A4", 0.5], [&"G4", 1.0], [&"B4", 1.0], [&"C5", 2.5],
	]
	var negra := 0.42
	var s := PackedFloat32Array()
	var t := 0.0
	for paso: Array in melodia:
		var hz: float = _HZ[paso[0]]
		var largo: float = paso[1] * negra
		# Cajita de música: triangular con un brillo de pulso una octava arriba, que se apaga despacio.
		s = mezclar(s, nota(&"triangulo", hz * 2.0, largo + 0.25, 0.55, 0.0, largo + 0.2), t)
		s = mezclar(s, nota(&"pulso12", hz * 4.0, 0.12, 0.08, 0.0, 0.1), t)
		t += largo
	s.resize(int((t + 0.6) * MEZCLA))  # un respiro de silencio antes de repetir
	s.reverse()
	_cancion_reves = wav(s)
	_cancion_reves.loop_mode = AudioStreamWAV.LOOP_FORWARD
	_cancion_reves.loop_begin = 0
	_cancion_reves.loop_end = s.size()
	return _cancion_reves


static func _envolvente(t: float, total: float, ataque: float, caida: float) -> float:
	var e := 1.0
	if ataque > 0.0 and t < ataque:
		e = t / ataque
	var resta := total - t
	if caida > 0.0 and resta < caida:
		e = minf(e, maxf(resta, 0.0) / caida)
	return roundf(e * PASOS_VOLUMEN) / PASOS_VOLUMEN
