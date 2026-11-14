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


static func _envolvente(t: float, total: float, ataque: float, caida: float) -> float:
	var e := 1.0
	if ataque > 0.0 and t < ataque:
		e = t / ataque
	var resta := total - t
	if caida > 0.0 and resta < caida:
		e = minf(e, maxf(resta, 0.0) / caida)
	return roundf(e * PASOS_VOLUMEN) / PASOS_VOLUMEN
