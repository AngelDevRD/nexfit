# `gymvisual_animations.json` — cómo poblarlo

Este archivo es el mapeo que usa `GymVisualProvider`
(`lib/core/exercise_animation/providers/gym_visual_provider.dart`) para
resolver la animación de cada ejercicio.

## Estado actual: muestra de validación (16 de 25 ejercicios propios)

Se integraron 16 GIFs (~1.5 MB total) para validar el flujo completo
(descarga → mapeo → `pubspec.yaml` → render en `ExerciseAnimationViewer`)
antes de traer el dataset completo (1324 ejercicios, ~17 MB de JSON + su
media). Los GIFs viven en `assets/animations/gymvisual/<slug>.gif`.

Dos mapeos son aproximados porque el dataset no tiene la variante genérica
exacta:
- `jalon-al-pecho` -> "cable lat pulldown full range of motion" (id 2330)
- `hip-thrust` -> "barbell glute bridge" (id 1409, el dataset no tiene un
  "hip thrust" liso)

Cuando se traiga el dataset completo, revisar si aparecen variantes más
exactas para esos dos.

## Formato esperado

```json
{
  "<slug-del-ejercicio>": {
    "gif_path": "assets/animations/gymvisual/<slug>.gif"
  }
}
```

El `<slug>` debe coincidir con el `slug` de `assets/data/exercises.json` (el
catálogo propio de la app), no con el id interno del dataset de origen --
esa traducción de ids también es responsabilidad de `GymVisualProvider`.

## Pasos para poblarlo (cuando se confirme traer el dataset)

1. Descargar `data/exercises.json` del repo origen y los GIFs de `images/`
   que se necesiten (180×180, como exige la licencia).
2. Copiar los GIFs a `assets/animations/gymvisual/`.
3. Generar este archivo con un `gif_path` por cada slug que tenga GIF.
4. Agregar `assets/data/gymvisual_animations.json` y
   `assets/animations/gymvisual/` a la sección `flutter: assets:` de
   `pubspec.yaml` (hoy no están declarados porque el archivo está vacío).
5. Recompilar. `GymVisualProvider` los toma solos, sin tocar ninguna
   pantalla ni widget.

## Licencia — no se toca fuera de este archivo/proveedor

La atribución "© Gym visual — https://gymvisual.com/" y la restricción de
180×180 están hardcodeadas en `GymVisualProvider`, no en la UI. Si algún día
se cambia de proveedor, este archivo y ese `.dart` se borran juntos y no
queda ningún rastro de la licencia en el resto del proyecto.
