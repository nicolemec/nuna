extends RefCounted

# Orden, anclajes y offsets de escenas/habitaciones/habitacion_101.tscn del prototipo.
const POSICIONES := {
	"Puerta": Vector2(16, 152),
	"Pantuflas": Vector2(70, 143),
	"Huesped": Vector2(75, 135),
	"Velador": Vector2(135, 130),
	"Lumi": Vector2(140, 100),
	"Comoda": Vector2(295, 145),
	"Dentadura": Vector2(130, 100),
	"Vaso": Vector2(130, 101),
	"Cortina": Vector2(219, 98),
	"Ramon": Vector2(300, 122),
	"Ovillo": Vector2(200, 147),
}
const OFFSETS := {
	"Puerta": Vector2(-12, -130),
	"Huesped": Vector2(-52, -79),
	"Lumi": Vector2(0.5, -6),
	"Cortina": Vector2(-20, -60),
	"Ramon": Vector2(-15, -50),
}


static func error_en(room: PopochiuRoom) -> String:
	if room.y_sort_enabled or room.get_node("Props").y_sort_enabled or room.get_node("Characters").y_sort_enabled:
		return "Popochiu reordenó las capas por Y"
	var props := room.get_props()
	if props.size() != POSICIONES.size():
		return "Cantidad de objetos distinta al prototipo"
	for i in props.size():
		var obj: ObjetoInteractivo = props[i]
		if String(obj.name) != POSICIONES.keys()[i]:
			return "Orden de dibujo distinto: " + String(obj.name)
		var esperada: Vector2 = POSICIONES[String(obj.name)]
		if String(obj.name) == "Ovillo" and room.state.get("ovi_en_ventana"):
			# Después de usarlo, Ovi queda en el piso bajo la ventana.
			esperada = room.get_script().get_script_constant_map()["OVI_POS_VENTANA"]
		if not obj.position.is_equal_approx(esperada):
			return "Posición alterada: %s (%s)" % [obj.name, obj.position]
		if obj.z_index != 0 or obj.baseline != 0 or obj.scale != Vector2.ONE:
			return "Capa, baseline o escala alterados: " + String(obj.name)
		if OFFSETS.has(String(obj.name)) and not obj.get_node("Sprite").position.is_equal_approx(OFFSETS[String(obj.name)]):
			return "Offset de animación alterado: " + String(obj.name)
	var bg: Sprite2D = room.get_node("Background")
	if bg.centered or bg.position != Vector2.ZERO or bg.texture.get_size() != Vector2(320, 152):
		return "Anclaje del fondo alterado"
	var characters: Node2D = room.get_node("Characters")
	if characters.get_index() < room.get_node("Props").get_index() or characters.z_index != 0 or C.player.z_index != 0:
		return "Nuna no está delante de los objetos como en el prototipo"
	return ""
