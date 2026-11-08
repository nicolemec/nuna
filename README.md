# Nuna

Aventura point-and-click en Godot. La adopción de Popochiu se realiza en un proyecto aislado; Escoria no se instala.

## Dos proyectos, sin mezclar sus sistemas

| Proyecto | Archivo que se abre en Godot | Estado |
| --- | --- | --- |
| Prototipo original | `project.godot` de la raíz | Menú e habitación 101 existentes, sin cambios. |
| Versión migrada | `migracion\popochiu\project.godot` | Menú, 101 completa, interfaz original, inventario nativo y guardado/carga. |

La carpeta histórica `nuna` contiene otra copia del proyecto y no es la base de esta integración. No se eliminó ni modificó.

`migracion\.gdignore` evita que el proyecto original importe la base experimental. El nuevo proyecto tiene sus propios recursos, autoloads y datos de usuario. No carga el `GameState` original ni comparte su inventario. La rama de trabajo es `integration/popochiu-base`; el punto de partida es el commit `daa78799420331f7f506445186e3652faf54ee48`.

## Versiones fijadas

- Godot **4.7.1 stable**, compilación oficial `a13da4feb`.
- Popochiu **2.2.1**, commit `1b3426252543a82b456be6a40735eff15d0f0a81`.
- Resolución lógica **320 × 180**, ventana **1280 × 720**, escalado entero y filtro nearest.

`migracion\popochiu\framework.lock.json` registra la fuente, revisión y SHA-256 del archivo descargado. El addon se incluye íntegro en `addons\popochiu` y no necesita una descarga para abrir esta base. Su licencia MIT se conserva en `third_party\Popochiu-LICENSE.txt`. No editar el addon para añadir mecánicas de Nuna: usar scripts del juego y puntos de extensión del framework.

## Abrir y ejecutar

1. Importar `migracion\popochiu\project.godot` en Godot 4.7.1.
2. Dejar finalizar la importación. Los plugins de Popochiu ya están configurados.
3. Ejecutar el proyecto con **F5**: ahora arranca en `game\menu\menu_inicio.tscn`.
4. Elegir **JUGAR** para una nueva partida, o **CONTINUAR** para recuperar el slot 1. Una partida nueva reinicia misión, objetos, inventario y recompensas sin borrar el archivo guardado.
5. En la habitación, hacer clic en un objeto y elegir **Mirar**, **Agarrar** o **Perturbar**, según lo que permita. Clic en el suelo para moverse.

La 101 conserva el fondo de **320 × 152**, las fuentes y la interfaz originales. Nuna usa el movimiento de Popochiu a 70 píxeles/segundo, los mismos límites, la flotación visual y las animaciones originales. Los **11 objetos** son Props nativos: puerta, pantuflas, huésped/cama, velador, Lumi, cómoda, dentadura, vaso, Doña Cortina, Ramón y Ovi. No se redimensionó el fondo para llenar la franja de UI.

La composición de la 101 conserva el **orden de dibujo y los anclajes del prototipo**, incluida la dentadura detrás del vaso y Nuna delante de los objetos. Solo esta habitación desactiva el orden automático por Y de Popochiu; la prioridad de clic sobre el objeto más pequeño se resuelve por separado. Las sacudidas vuelven al anclaje de la escena, no a una coordenada guardada como progreso. Al cargar se restablecen las posiciones, y los antiguos snapshots con `_x_base` se ignoran sin borrar la partida.

La escena `game\rooms\base_tecnica\room_base_tecnica.tscn` queda disponible para diagnóstico con **F6**: **Verificar secuencia** comprueba `E.queue`; **Abrir 101** entra a la habitación. No es el menú del juego ni una nueva escena de lore.

### Controles y partidas

- Diálogo: clic, **Enter** o **Espacio** después de 0.4 segundos; también avanza automáticamente según la longitud del texto.
- Dentro del juego: **Esc** abre el menú de pausa, **F5** guarda y **F9** carga. El menú también ofrece los botones correspondientes y volver al menú principal.
- Guardar/cargar solo está permitido entre acciones, no durante movimiento de interacción, diálogos ni el cierre de misión. Pausar detiene el goteo y el cooldown de Lumi; los diálogos detienen el goteo, como en el prototipo.
- El inventario conserva sus casilleros: clic en **Ovi** para seleccionarlo y luego en la cortina conocida para usarlo; también funciona **Perturbar** con Ovi recogido. Se consume una vez y no reaparece al cargar. La dentadura se recoge como **Sonrisa**, como en el prototipo.
- Partidas en `user://save_1.json`, dentro de los datos de usuario de **Nuna - Base Popochiu**. No son compatibles con un `GameState` del proyecto original. Menú y GUI comparten un validador para rechazar archivos ausentes, malformados o de otro proyecto sin iniciar una carga inválida.

### Probar el puzzle de Ramón

1. Abrir la 101 y hacer clic en la radio, a la derecha. Los botones se habilitan al seleccionarla.
2. **Perturbar** antes de mirar solo muestra «¡Ay, todavía no nos presentamos!»: no cuenta como intento.
3. **Mirar** presenta a Ramón una sola vez y muestra su frase original. Nuna se acerca y reproduce su interacción antes de hablar.
4. **Perturbar** una vez: la radio se sacude, sin sello ni vela.
5. **Perturbar** otra vez: sintoniza, queda sonando, la huésped tiembla y se obtiene un sello, +20 de vela y +10 de bruma.
6. Repetir la acción no entrega otra recompensa. Durante movimiento/interacción/diálogo se bloquean los verbos y los clics de movimiento. Los textos avanzan automáticamente o con clic/Enter/Espacio después de 0.4 segundos.

La bruma comienza en 50 y, tras el primer intento válido, pierde 1 cada 5 segundos, como en el prototipo. El HUD puede mostrar menos de 60 al completar el puzzle por ese consumo durante la partida.

Las reglas globales pertenecen a `game\popochiu_globals.gd` (`Globals`). Intentos, entrada, cortina, sombra y cierre pertenecen al recurso de estado de `Habitacion101`; presentación, recogida, niveles y cooldown se guardan en los Props. Los InventoryItems y la posesión de objetos pertenecen a **I/C.player.inventory**, no a otro inventario en Globals.

Los scripts gráficos y de interacción originales se adaptaron bajo `game\objects` a `PopochiuProp`. La GUI de Popochiu alberga la interfaz original adaptada bajo `game\ui`, con HUD, guía, tareas y certificaciones. El addon permanece intacto. La radio no tiene un audio nuevo: el prototipo también representaba «sonando» visualmente.

### Lumi, Ovi, cortina y cierre

- **Lumi:** mirarla la presenta y muestra la etiqueta con su letra chica. Tres perturbaciones suben la luz: cada nivel cobra 5 de bruma y recompensa una única vez +10 de bruma/+10 de miedo. Mirar en nivel 3 la deja cuidada y da su sello. Perturbar de nuevo la quema: cobra otros 10 de bruma y recompensa +25 de miedo una sola vez; tras 20 segundos vuelve a apagada. Se guarda el tiempo restante y no se vuelven a premiar los niveles al reintentarlos.
- **Doña Cortina:** sin Ovi, los intentos cuestan 2 de bruma, reproducen el mini-salto y ofrecen pistas progresivas. Con Ovi recogido, empieza a bailar, lo consume y entrega +15 de miedo y su sello una sola vez.
- **Sombra:** perturbar a Lumi cuidada cuando la cortina baila llena el miedo a 100, conservando el combo original.
- **Tres sellos:** vuelve la orden de trabajo marcada **CUMPLIDO**, seguida de las frases originales de Din y Nuna. Guardar y cargar no repite ese cierre.

Se conserva la entrada existente por la puerta y su orden de trabajo. Esto **no** implementa ni reemplaza la futura cinemática/tutorial.

## Arte e importador Aseprite

Los archivos de `arte` se copiaron a `migracion\popochiu\arte`, sin las cachés `.import` antiguas. Es una copia independiente: los cambios posteriores en el arte del prototipo no se sincronizan automáticamente. Editar el arte de la versión migrada desde su proyecto y mantener un único origen por asset cuando termine la migración.

El addon descargado quedó instalado y habilitado en `migracion\popochiu\addons\nklbdev.aseprite_importers`. Dejar el ZIP extraído como hermano de `popochiu` no lo instala: `res://addons` pertenece al proyecto que se abrió. Su licencia y revisión declarada por el nombre de la carpeta están registradas junto con Popochiu.

El proyecto versionado busca `aseprite` en el **PATH**, sin guardar una ruta personal. Antes de importar una copia nueva, instalar Aseprite y añadir la carpeta que contiene su ejecutable al PATH del usuario. En Windows se puede configurar desde **Variables de entorno > Variables de usuario > Path**. Después reiniciar Godot y comprobar `aseprite --version` en una terminal nueva. En **Project > Project Settings > General**, activar ajustes avanzados y buscar **Aseprite Importers > Aseprite Executable Path**: debe contener `aseprite`. Se probó con Aseprite 1.3.7. Popochiu también tiene su herramienta de importación Aseprite: no ejecutar ambas herramientas sobre el mismo destino. En esta prueba, el addon externo genera `SpriteFrames`; Popochiu gestiona el personaje y el juego.

La animación activa proviene de `arte\importados\nuna\nuna_animaciones.aseprite`. Seleccionarla en FileSystem y elegir **SpriteFrames** en Import; después pulsar **Reimport**. El addon genera el PNG junto a ese archivo y elimina el JSON temporal. Por eso ese origen está separado de `arte\nuna\nuna.png` y `nuna.json`, que se conservan como referencia. Para modificar las animaciones activas editar `nuna_animaciones.aseprite`, no la copia de referencia. Sus tags conservan los nombres `flota_frente`, `flota_derecha`, etc. El archivo `.import` nuevo se conserva porque define el importador seleccionado, no solo una caché.

### Importación limpia y prueba automatizada

Desde PowerShell, ajustar `$repo` y `$godot` si se usa otra ubicación. Se utiliza el ejecutable de consola incluido con Godot:

```powershell
$repo = 'C:\Users\v-emejiacruz\OneDrive - Microsoft\Documents\GitHub\nuna'
$godot = 'C:\Users\v-emejiacruz\Downloads\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe'
$project = Join-Path $repo 'migracion\popochiu'

& $godot --headless --editor --recovery-mode --import --path $project
& $godot --headless --editor --import --path $project
# Completar la carga de las escenas tras generar los SpriteFrames del importador externo:
& $godot --headless --editor --import --path $project
$base = 'res://game/rooms/base_tecnica/room_base_tecnica.tscn'
& $godot --headless --path $project $base -- --smoke-test
& $godot --headless --path $project $base -- --migration-test
& $godot --headless --path $project $base -- --ramon-test
& $godot --headless --path $project $base -- --full-test
& $godot --headless --path $project 'res://tests/menu_test.tscn' -- --menu-test

# Carga de una partida completa en otro proceso, sin caché de la sesión anterior:
& $godot --headless --path $project $base -- --full-test --retain-full-save
if ($LASTEXITCODE -eq 0) {
    & $godot --headless --path $project $base -- --cold-load-test
}
```

En una copia sin `.godot`, la primera pasada importa los recursos sin ejecutar plugins o scripts de editor; la segunda registra el importador externo y genera los SpriteFrames. La tercera comprueba las escenas con esos recursos ya disponibles. Durante la segunda pasada puede aparecer un aviso de recurso Aseprite aún no generado: la última importación y las pruebas de ejecución deben quedar sin errores. Esta secuencia también evita cargar los iconos de Popochiu antes de importar sus texturas. El modo recovery no elimina plugins ni modifica políticas de seguridad.

Las pruebas deben salir con código **0**, imprimir **SMOKE PASS**, **MIGRATION PASS**, **RAMON PASS**, **FULL PASS**, **MENU TEST OK** o **COLD LOAD PASS**, según la prueba, y no mostrar `ERROR` ni `SCRIPT ERROR`.

- Infraestructura, transición, SpriteFrames y movimiento siguen cubiertos por las regresiones de la base.
- Ramón comprueba presentación única, rechazo, dos intentos, reacción, recompensa, bloqueo, goteo y guardado intermedio/completo.
- La misión completa comprueba los 11 Props, verbos desde la UI, niveles/fogonazo/cooldown de Lumi, saltos, inventario nativo, consumo de Ovi, cuatro guardados/cargas, recompensas únicas, cierre, sombra, HUD y pausa. También compara orden de capas, posiciones y offsets con el prototipo al entrar, después de cada acción y después de cargar. Simula snapshots antiguos con `_x_base = 0` y sacudidas superpuestas para verificar que ningún objeto se desplaza permanentemente.
- Menú comprueba diseño, teclado, archivos inválidos, partida nueva, continuar y reinicio del progreso/inventario.
- La carga en frío verifica misión, animaciones, inventario, HUD y composición original después de sacudidas desde otro proceso de Godot.

Los tests de Ramón y misión usan los slots temporales **987654** y **987653**. No sobrescriben un slot existente y los eliminan al terminar. `--retain-full-save` conserva el segundo únicamente para la prueba de carga en frío, que lo elimina. La prueba de menú usa y restaura temporalmente el slot 1: no ejecutarla a la vez que una partida interactiva que esté guardando.

La importación limpia puede mostrar advertencias de UID en cuatro iconos del menú de editor de Popochiu; Godot usa sus rutas de texto y la prueba de ejecución no muestra esas advertencias. Se conserva el addon original sin corregir esos metadatos externos. Evitar rutas de proyecto excesivamente largas: en Windows el escáner de Godot puede fallar al recorrer subdirectorios, aunque los archivos existan.

Validado con Godot 4.7.1: regresiones headless, misión completa con renderizado **OpenGL**, menú y carga en un proceso nuevo. Para repetir una prueba con gráficos, quitar `--headless` y usar `--rendering-method gl_compatibility`. El aviso del importador Aseprite propio de Popochiu en el editor no afecta al importador externo configurado: no usar ambos sobre el mismo destino.

Para comprobar el arranque del prototipo original:

```powershell
& $godot --headless --editor --import --path $repo
& $godot --headless --path $repo --quit-after 120
```

Esto comprueba su importación y arranque, no la resolución completa de los puzzles. Las cachés `.godot` se regeneran y no se versionan.

## Cómo funciona Popochiu en Nuna

El dock de Popochiu registra elementos del juego; las escenas definen su aspecto y los scripts GDScript sus acciones. Una textura por sí sola no es un objeto interactivo.

| Elemento | Responsabilidad | En este proyecto |
| --- | --- | --- |
| Room | Fondo, personajes, props, hotspots, regiones y entrada/salida. | `game\rooms\habitacion_101` |
| Character | Movimiento, orientación, animación y habla. | `game\characters\nuna` |
| Prop / Hotspot | Objeto visible o zona clicable y sus acciones. | Los 11 objetos de la 101 son Props; selección por la entrada nativa del framework. |
| InventoryItem | Objeto que se recoge y usa. | `I.Ovillo` y `I.Dentadura`, con casilleros en la GUI original. |
| Dialog | Conversación con opciones. | Disponible; el prototipo usa frases lineales mediante `C.player.say`, no necesita inventar diálogos ramificados. |
| GUI | Verbos, inventario, HUD y presentación de diálogos. | `game\gui\gui.gd` conecta Popochiu con `game\ui` y conserva el diseño original. |
| Data / state | Recurso `.tres` y script de estado del elemento. | Estado de misión en RoomData, del personaje en CharacterData y de los Props en los snapshots de la habitación. |

Los autoloads son las puertas de entrada al framework: **E** es el motor y sus secuencias; **R** las habitaciones; **C** los personajes; **I** el inventario; **D** los diálogos; **A** el audio; **G** la interfaz y **T** las transiciones. El addon genera los accesos como `C.Nuna` y `R.Habitacion101`; no editarlos para introducir lógica de puzzles.

```gdscript
await R.goto_room("Habitacion101")
await C.player.walk(Vector2(160, 138))
await E.queue([C.player.queue_walk(Vector2(200, 138)), E.queue_wait(0.5)])
```

Estos ejemplos usan el controlador de Popochiu. Nuna adapta solamente las animaciones y restringe el destino; no reutiliza su bucle de movimiento anterior. Como en el prototipo es un fantasma sin colisiones, esta primera versión ignora walkable areas y obstáculos. Si más adelante el diseño necesita navegación alrededor de objetos, habrá que cambiar esa decisión y dibujar las áreas navegables.

Para la cinemática jugable, `_on_room_entered` prepara la escena y `_on_room_transition_finished` puede iniciar una secuencia `E.queue` o una cinemática omitible `E.cutscene`. Entre secuencias se devuelve el control para los puzzles. Una cinemática omitida o una partida cargada necesita restaurar el estado correcto: no basta con saltar diálogos.

### Dónde modificar el juego

- `game\rooms\habitacion_101\room_habitacion_101.gd`: secuencias, entrada, puzzles, guía y cierre.
- `room_habitacion_101_state.gd`: progreso persistente de la misión.
- `game\objects`: objetos originales adaptados; Lumi guarda su estado como entero compatible con el serializador y el tiempo restante del cooldown.
- `game\inventory_items`: InventoryItems de Ovi y Sonrisa. La base del juego permite reiniciar `ever_collected` solo al comenzar otra partida, sin editar el addon.
- `game\gui` y `game\ui`: puente de señales nativas, interfaz original y controles de guardado/pausa.
- `game\menu`: menú y validador de partidas compartido con la GUI.
- `game\popochiu_data.cfg`: registro que genera los accesos tipados; no editar los autoloads generados para añadir puzzles.

El siguiente contenido nuevo es la cinemática/tutorial, cuando estén disponibles el storyboard, el guion y el diagrama de puzzles.

## Límite de esta base

La cinemática jugable se implementará cuando estén definidos el storyboard, el guion y el diagrama de puzzles. No se ha sustituido el arranque del prototipo ni se han inventado escenas del lore. En Popochiu, se podrá comenzar una secuencia al terminar la transición de una habitación y alternar secuencias con interacción; el comportamiento al omitir o restaurar una partida debe diseñarse junto con el tutorial.

El alcance migrado es el **prototipo actual**: menú y habitación 101 completos, UI, inventario y guardado/carga. No se añadieron otras habitaciones, audio que no existía ni puzzles nuevos. El prototipo de la raíz sigue intacto y disponible como referencia; la integración permanece en su rama de trabajo, sin commits ni push automáticos.

Referencias: [Popochiu 2.2.1](https://github.com/carenalgas/popochiu/releases/tag/v2.2.1) · [Documentación oficial](https://carenalgas.github.io/popochiu/).
