# Modelos 3D de ejercicios — cómo agregar assets

La app carga los modelos 3D **desde esta carpeta** (100% offline una vez que
están acá). Por licencia, los archivos los descargás vos (Mixamo pide cuenta de
Adobe; sus assets son gratis y de uso comercial, pero hay que bajarlos desde tu
cuenta). La app ya está preparada: **soltás el archivo con el nombre correcto acá,
recompilás, y aparece solo** en la pestaña 3D del ejercicio.

## Convención de nombres (obligatoria)

```
assets/models_3d/<slug>_male.glb     ← modelo masculino + animación del ejercicio
assets/models_3d/<slug>_female.glb   ← modelo femenino + animación del ejercicio
```

El `<slug>` es el identificador del ejercicio (ej: `press-banca-con-barra`,
`sentadilla-con-barra`, `dominadas`). Está en el catálogo
(`assets/data/exercises.json`, campo `slug`).

Ejemplos:
```
assets/models_3d/press-banca-con-barra_male.glb
assets/models_3d/press-banca-con-barra_female.glb
assets/models_3d/sentadilla-con-barra_male.glb
```

Si un archivo no está, la app muestra un placeholder “Modelo 3D no disponible”
para ese ejercicio; el resto sigue funcionando.

## Cómo obtener cada archivo en Mixamo (gratis, uso comercial)

1. Entrá a https://www.mixamo.com (cuenta de Adobe gratuita).
2. **Characters:** elegí un personaje masculino y uno femenino (ej: “Y Bot”/“X Bot”
   o un personaje realista del catálogo).
3. **Animations:** buscá la animación del ejercicio (ej: “squat”, “push up”).
   ⚠️ Mixamo tiene mocap general, **no tiene todos los ejercicios de gym con
   nombre exacto**. Para los que no estén, hay que crear/adaptar la animación en
   Blender (eso queda fuera de la app).
4. Con la animación aplicada al personaje, **Download** con estos ajustes:
   - Format: **glTF Binary (.glb)**
   - Skin: **With Skin**
   - Frames per Second: 30
   - Keyframe Reduction: none o uniforme
5. Renombrá el `.glb` a `<slug>_male.glb` (o `_female.glb`) y ponelo en esta carpeta.
6. Recompilá la app (`flutter build apk ...`). Listo.

## Recomendaciones de peso (para que sea liviano y ande en gama baja)

- Objetivo: **< 5 MB por archivo**. Si pesa más, reducí en Blender (decimate) o
  usá keyframe reduction en Mixamo.
- Texturas PBR opcionales; para músculos alcanza con color base.

## Nota sobre el resaltado de músculos

El resaltado (primario rojo intenso / secundario rojo claro) se hace con un
**mapa muscular 2D** dentro de la app (pestaña “Músculos”), usando los datos de
`primary_muscles`/`secondary_muscles` que ya tiene cada ejercicio. Recolorear
músculos **sobre el modelo 3D animado** requeriría un modelo con cada músculo
como malla separada (los de Mixamo son una sola malla), así que el 3D muestra la
animación y el resaltado va en el mapa 2D. Si conseguís un modelo anatómico
segmentado por músculos, la arquitectura queda lista para engancharlo.
