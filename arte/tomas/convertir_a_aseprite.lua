-- Nuna: convierte 1 o 2 imágenes (PNG/JPG) en un .aseprite de 320x152 por cuadro.
-- Uso en Aseprite: Archivo > Scripts > Abrir carpeta de scripts, copiá este archivo ahí,
-- luego Archivo > Scripts > Volver a cargar scripts y ejecutá "convertir_a_aseprite".
local dlg = Dialog("Imágenes a toma de Aseprite")
dlg:file{ id="a", label="Cuadro 1", open=true, filetypes={"png","jpg","jpeg"} }
dlg:file{ id="b", label="Cuadro 2 (opcional)", open=true, filetypes={"png","jpg","jpeg"} }
dlg:file{ id="out", label="Guardar como", save=true, filename="toma_nueva.aseprite", filetypes={"aseprite"} }
dlg:number{ id="w", label="Ancho", text="320", decimals=0 }
dlg:number{ id="h", label="Alto", text="152", decimals=0 }
dlg:button{ id="ok", text="Convertir" }
dlg:button{ id="cancel", text="Cancelar" }
dlg:show()

local d = dlg.data
if not d.ok then return end

local rutas = {}
for _, k in ipairs({ "a", "b" }) do
  if d[k] ~= nil and d[k] ~= "" then table.insert(rutas, d[k]) end
end
if #rutas == 0 then
  app.alert("Elegí al menos una imagen.")
  return
end

-- Carga la imagen externa en un objeto Image y la estampa en un sprite nuevo.
local primera = Image{ fromFile = rutas[1] }
local spr = Sprite(primera.width, primera.height, ColorMode.RGB)
spr.layers[1].name = "dibujo"
app.transaction(function()
  for i, ruta in ipairs(rutas) do
    local img = (i == 1) and primera or Image{ fromFile = ruta }
    local cuadro = (i == 1) and spr.frames[1] or spr:newEmptyFrame()
    spr:newCel(spr.layers[1], cuadro, img, Point(0, 0))
  end
end)

-- Achica todo a la medida de la toma, sin suavizar (pixel art).
app.command.SpriteSize{ ui=false, width=d.w, height=d.h, lockRatio=false, method="nearest" }
spr:saveAs(d.out)
app.alert("Listo: " .. d.out)
