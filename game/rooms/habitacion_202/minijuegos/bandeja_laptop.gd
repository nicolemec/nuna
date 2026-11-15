class_name BandejaLaptop
extends Panel202
## Minijuego de la compu de Bruno: tres mails del trabajo llenos de metáforas.
## Nuna toma todo al pie de la letra: la respuesta literal hace trabajar de más a la compu.
## Tres respuestas literales = la compu se recalienta y se quema.

signal elegido(indice: int)

const MAILS := [
	{
		"asunto": "URGENTE",
		"cuerpo": "Hay que ponerse las pilas con este proyecto.",
		"opciones": ["Contestar 'mañana lo veo'", "Ponerle pilas a la compu", "Cerrar la compu"],
		"correcta": 1,
		"ok": "¡Pilas puestas! Ahora trabaja el doble.",
		"mal": ["¿Mañana? En esta pieza no existe el mañana.", "", "Cerrarla sería dejarla descansar. Eso no asusta a nadie."],
	},
	{
		"asunto": "PARA AYER",
		"cuerpo": "Lo necesito para ayer, sin falta.",
		"opciones": ["Mandar el archivo al pasado", "Pedir más tiempo", "Mandarlo el lunes"],
		"correcta": 0,
		"ok": "¡Archivo enviado a ayer! Calcular viajes en el tiempo la hace transpirar.",
		"mal": ["", "¿Más tiempo? El tiempo es bruma, y nadie regala bruma.", "El lunes queda para adelante. ¡Ayer es para atrás!"],
	},
	{
		"asunto": "ÚLTIMO CAMBIO (v37)",
		"cuerpo": "Esta vez necesito que lo des todo.",
		"opciones": ["Dar el 50%", "Tomarse un descanso", "Abrir todos los programas a la vez"],
		"correcta": 2,
		"ok": "¡Lo da todo! Todos los programas abiertos, todos a la vez.",
		"mal": ["¿La mitad? Din dice que los profesionales dan el 110.", "¿Descanso? Ni Bruno ni la compu conocen esa palabra.", ""],
	},
]

var _asunto: Label
var _cuerpo: Label
var _calor: Label
var _opciones: VBoxContainer


func _armar() -> void:
	caja.add_child(_label("BANDEJA DE ENTRADA", COLOR_GRIS))
	_asunto = _label("", COLOR_NARANJA)
	caja.add_child(_asunto)
	_cuerpo = _label("", COLOR_CLARO)
	caja.add_child(_cuerpo)
	caja.add_child(_espacio(4))
	_opciones = VBoxContainer.new()
	_opciones.add_theme_constant_override("separation", 1)
	caja.add_child(_opciones)
	caja.add_child(_espacio(2))
	_calor = _label("", COLOR_ROJO)
	caja.add_child(_calor)
	caja.add_child(_label("clic afuera para cerrar", COLOR_PISTA))


func mostrar(indice: int) -> void:
	var mail: Dictionary = MAILS[indice]
	_asunto.text = "Asunto: %s" % mail.asunto
	_cuerpo.text = mail.cuerpo
	for b in _opciones.get_children():
		_botones.erase(b)
		_opciones.remove_child(b)
		b.queue_free()
	for i in mail.opciones.size():
		_opciones.add_child(_boton(mail.opciones[i], elegido.emit.bind(i)))
	_calor.text = "Temperatura: " + "■".repeat(indice) + "□".repeat(MAILS.size() - indice)
	reacomodar()
