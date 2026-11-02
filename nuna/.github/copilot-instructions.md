# Nuna · instrucciones para Copilot

## Proyecto
Aventura gráfica point-and-click con gestión, en pixel art. Nuna es un fantasma novato
que trabaja el turno noche en un hotel asustando huéspedes que nunca se ven.
Prototipo gris de la habitación 101. Somos dos personas aprendiendo Godot.

## Reglas técnicas
- Godot 4.7.1, GDScript 4, tipado cuando ayude. Sin addons ni plugins.
- Resolución base 320x180, stretch "viewport", escala entera, filtro Nearest.
- Sangría SIEMPRE con tabs, nunca espacios.
- Comentarios en español. Explicaciones en español, en pasos chicos, sin suponer nada.
- Todos los números ajustables van en res://scripts/ajustes.gd (class_name Ajustes).
- No modifiques archivos .tscn: si hace falta un cambio de escena, explícame cómo hacerlo en el editor de Godot.
- Cuando propongas un cambio, usa el formato: así estaba antes / dónde / código corregido / qué esperar.

## Arquitectura
- res://scripts/ajustes.gd: constantes (velocidad, límites del piso, animaciones de Nuna).
- res://scripts/aseprite_cargador.gd: crear_desde_tira() corta nuna.png (552x24, 23 frames de 24x24).
- res://scripts/game_state.gd: Autoload "GameState" (sin class_name). Verbo actual, inventario, sellos, Bruma.
- res://escenas/personajes/nuna.gd (class_name Nuna, Node2D, hijo AnimatedSprite2D "Sprite"):
  flota, ir_a(), mirar_a(), interactuar(), decir() con globo.
- res://escenas/objetos/objeto_interactivo.gd (class_name ObjetoInteractivo): base reutilizable,
  grupo "interactivos", brilla hasta ser mirado, Mirar obligatorio antes de Perturbar, textura opcional.
- res://escenas/ui/ui.gd (class_name InterfazUI, CanvasLayer "UI"): verbos, 4 verbos con candado,
  inventario de 2 casilleros, cuaderno de 3 sellos, barra de Bruma, línea de acción.
- res://escenas/habitaciones/habitacion_101.gd: clics, mover a Nuna, usar objetos, teclas de prueba 1/2/3.

## Diseño de la habitación 101 (lo que viene)
Cada objeto tiene una etiqueta "Prueba de certificación" que Nuna lee contento; la letra chica la ve solo el jugador.
1. Lumi (lámpara): cada Perturbar sube un nivel de luz. Nivel 3 + Mirar = sello. 4.ª vez se quema (-10 Bruma, 20 s apagada).
2. Ramón (radio): dial de 5 estaciones; la etiqueta dice FXDWUR (César -3 = CUATRO). Estación incorrecta -5 Bruma.
3. Doña Cortina (ventana): Nuna no llega al picaporte (los aprendices flotan bajito). Agarrar a Ovi (ovillo) y soltarlo bajo la ventana.
4. Sonrisa (dentadura): con 3 sellos el vaso se destraba.
Combo: Lumi cuidada (nivel 3) + cortina flotando = sombra gigante, vela llena.
Gestión: Bruma 0-100, empieza en 50, goteo -1 cada 3 s, Nuna más transparente con menos Bruma.

## Pendientes
- Las animaciones de Nuna: "cuerpo" parece un giro, no un flote quieto. Hay que confirmar qué es cada frame.
- La lámpara tiene 2 estados (apagada / encendida).