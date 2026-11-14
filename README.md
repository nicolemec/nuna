# Nuna

Aventura point-and-click sobre un fantasma recién graduado que trabaja en un hotel embrujado.
Hecha en **Godot 4.7.1** con el framework **Popochiu 2.2.1**. Pixel art a 320 × 180.

## Abrir el juego

1. Abrir Godot 4.7.1 e importar el `project.godot` de esta carpeta.
2. Esperar a que termine la importación. La primera vez tarda un poco.
3. Apretar **F5**. El juego arranca en el menú (`game/menu/menu_inicio.tscn`).

Para editar el arte desde Godot hace falta Aseprite en el PATH (ver «Arte» más abajo).

## Qué hay en cada carpeta

| Carpeta | Contenido |
| --- | --- |
| `game/rooms` | Las salas: `teatro`, `calle` y `recepcion` (la intro) y `habitacion_101`. |
| `game/characters` | Nuna (personaje jugable). |
| `game/objects` | Los objetos con los que se interactúa (Lumi, Ramón, Doña Cortina…). |
| `game/inventory_items` | Objetos de inventario (Ovi, Sonrisa). |
| `game/gui`, `game/ui` | Interfaz: verbos, HUD, guía, tareas, pausa y guardado. |
| `game/menu` | Menú de inicio y validador de partidas. |
| `game/helpers` | Código compartido: música (`musica.gd`), voces chip (`chip.gd`, `voz_nuna.gd`), tomas de la intro (`toma.gd`, `sala_intro.gd`), ajustes. |
| `arte` | Fondos, personajes, objetos, tomas y fuentes (`.aseprite` + `.png`). |
| `audio/soundtrack` | Música del juego y los patches de Pure Data con los que se hizo. |
| `audio/sfx` | Efectos de sonido. |
| `addons` | Popochiu y el importador de Aseprite. **No editar.** |
| `tests` | Pruebas automáticas. |
| `third_party` | Licencias de los addons. |

## Música

La música se genera con los patches de Pure Data de `audio/soundtrack`, uno por ambiente:

| Patch | Ambiente | Toma que usa el juego |
| --- | --- | --- |
| `nuna_amb_A_menu.pd` | Menú | `nuna_menu_toma_1.wav` |
| `nuna_amb_B_intro.pd` | Intro (teatro, calle, recepción) | `nuna_intro_toma_1.wav` |
| `nuna_amb_C_habitaciones.pd` | Habitaciones | `nuna_habitaciones_toma_1.wav` |

Cada patch tiene una grabadora: **TOMA COMPLETA** graba 2 minutos con fundido final y guarda el `.wav` junto al patch.
Para cambiar una canción en el juego, editá la lista `PISTAS` en `game/helpers/musica.gd`.
`audio/soundtrack/pruebas` guarda versiones anteriores y ejemplos.

## Controles

- Clic en un objeto y elegir **Mirar**, **Agarrar** o **Perturbar**. Clic en el suelo para moverse.
- Diálogos: clic, **Enter** o **Espacio**.
- **Esc** pausa, **F5** guarda, **F9** carga. Partidas en `user://save_1.json`.

## Habitación 101

Once objetos interactivos: puerta, pantuflas, huésped/cama, velador, Lumi, cómoda, dentadura, vaso, Doña Cortina, Ramón y Ovi.

- **Ramón (radio):** mirar para presentarlo; perturbar dos veces para que sintonice. Da un sello.
- **Lumi:** tres perturbaciones suben la luz; mirarla en nivel 3 da su sello. Perturbar de nuevo la quema por 20 segundos.
- **Doña Cortina:** con Ovi recogido empieza a bailar y da su sello.
- **Sombra:** perturbar a Lumi cuidada mientras la cortina baila llena el miedo a 100.
- Con **tres sellos** vuelve la orden de trabajo marcada **CUMPLIDO**.

La bruma empieza en 50 y baja 1 cada 5 segundos después del primer intento.

## Arte

- Los `.aseprite` se importan con el addon `nklbdev.aseprite_importers`, que busca `aseprite` en el PATH.
  En Windows: **Variables de entorno > Variables de usuario > Path**, agregar la carpeta de Aseprite y reiniciar Godot.
- Las animaciones de Nuna salen de `arte/importados/nuna/nuna_animaciones.aseprite`. Editar ese archivo; `arte/nuna` es la copia de referencia.
- No usar el importador de Aseprite de Popochiu sobre los mismos archivos.

## Cómo funciona Popochiu (resumen)

Los autoloads son las puertas de entrada: **E** motor y secuencias, **R** salas, **C** personajes, **I** inventario, **D** diálogos, **A** audio, **G** interfaz, **T** transiciones.

```gdscript
await R.goto_room("Habitacion101")
await C.player.walk(Vector2(160, 138))
```

No editar `addons/popochiu` ni los autoloads generados: la lógica del juego va en `game/`.

## Pruebas automáticas (opcional)

Desde PowerShell:

```powershell
$repo  = 'C:\Users\v-emejiacruz\OneDrive - Microsoft\Documents\GitHub\nuna'
$godot = 'C:\Users\v-emejiacruz\Downloads\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe'
$base  = 'res://game/rooms/base_tecnica/room_base_tecnica.tscn'

& $godot --headless --editor --import --path $repo
& $godot --headless --path $repo $base -- --smoke-test
& $godot --headless --path $repo $base -- --full-test
& $godot --headless --path $repo 'res://tests/menu_test.tscn' -- --menu-test
```

Cada prueba debe terminar con **PASS** / **OK** y sin `ERROR`.

## Versiones

- Godot **4.7.1 stable**.
- Popochiu **2.2.1** (detalle en `framework.lock.json`, licencia MIT en `third_party`).
- 320 × 180, ventana 1280 × 720, escalado entero, filtro nearest.

Referencias: [Popochiu 2.2.1](https://github.com/carenalgas/popochiu/releases/tag/v2.2.1) · [Documentación](https://carenalgas.github.io/popochiu/).
