class_name ListaTareas
extends CanvasLayer
## Lista de tareas de la habitación: cuelga debajo de SELLOS en el HUD, con su mismo fondo.
## Muestra el nombre común hasta que Nuna mira el objeto, y lo tacha al ganar su sello.

const RUTA_FUENTE := "res://arte/fuentes/Tiny5-Regular.ttf"  # la misma del HUD
const TAM := 8

const COLOR_OSCURO := Color8(34, 32, 52)
const COLOR_GRIS := Color8(155, 173, 183)
const COLOR_CLARO := Color8(203, 219, 252)
const COLOR_HECHO := Color8(153, 229, 80)

var _tareas: Array[Dictionary] = []  # {objeto, sello, comun, label}
var _caja: HBoxContainer


func _ready() -> void:
	layer = 40
	var panel := PanelContainer.new()
	panel.theme = _crear_tema()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	_caja = HBoxContainer.new()
	_caja.add_theme_constant_override("separation", 6)
	panel.add_child(_caja)
	panel.position = Vector2(Ajustes.UI_HUD_SELLOS_ETIQUETA_POS.x - 4.0, Ajustes.UI_HUD_TAMANO.y)
	GameState.sellos_cambiados.connect(func(_c): _refrescar())


## Suma una tarea: el objeto, el id del sello que la cumple y su nombre común.
func agregar(objeto: ObjetoInteractivo, sello: StringName, comun: String) -> void:
	var l := Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caja.add_child(l)
	_tareas.append({"objeto": objeto, "sello": sello, "comun": comun, "label": l, "hecho": false})
	objeto.mirado.connect(func(_o): _refrescar())
	_refrescar()


func _refrescar() -> void:
	for t in _tareas:
		var obj: ObjetoInteractivo = t.objeto
		var hecho: bool = GameState.sellos_obtenidos.has(t.sello)
		var nombre: String = obj.nombre if obj.nombrado else t.comun
		var l: Label = t.label
		l.text = ("✓ " if hecho else "- ") + nombre
		l.add_theme_color_override("font_color", COLOR_HECHO if hecho else COLOR_GRIS)
		if hecho and not t.hecho:
			t.hecho = true
			_parpadear(l)


func _parpadear(l: Label) -> void:
	var tw := create_tween()
	for i in 4:
		tw.tween_property(l, "modulate", Color(1, 1, 1, 0.2), 0.12)
		tw.tween_property(l, "modulate", Color.WHITE, 0.12)


func _crear_tema() -> Theme:
	var t := Theme.new()
	if ResourceLoader.exists(RUTA_FUENTE):
		var fuente: FontFile = load(RUTA_FUENTE)
		fuente.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		fuente.hinting = TextServer.HINTING_NONE
		fuente.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
		t.default_font = fuente
	t.default_font_size = TAM
	var c := StyleBoxFlat.new()
	c.bg_color = Ajustes.UI_HUD_FONDO  # mismo fondo que el HUD, para que se lea como parte de él
	c.content_margin_left = 3
	c.content_margin_right = 3
	c.content_margin_top = 1
	c.content_margin_bottom = 1
	t.set_stylebox("panel", "PanelContainer", c)
	return t
