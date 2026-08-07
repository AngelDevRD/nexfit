# Animaciones de ejercicios — fuente de datos

**Se reemplazó el enfoque anterior (modelos 3D `.glb` vía Mixamo).** Ahora la
fuente de animaciones/datos de ejercicios es el dataset gratuito:

> https://github.com/hasaneyldrm/exercises-dataset

920+ ejercicios con GIF animado, thumbnail 180×180, grupos musculares, equipo
e instrucciones en 6 idiomas (`data/exercises.json` del repo, ~17 MB).

## Licencia — leer antes de usar

- **Datos** (nombres, categorías, músculos, instrucciones, estructura): **MIT**.
  Libre de usar/modificar, ver `LICENSE` del repo origen.
- **Media** (GIFs y thumbnails en `images/` y `videos/`): **© Gym visual**
  (https://gymvisual.com/), incluida en ese repo con permiso explícito del
  titular, bajo estas condiciones obligatorias:
  - Solo se puede usar/redistribuir a **180×180** de resolución.
  - Toda pantalla que muestre esa media debe llevar la atribución
    **"© Gym visual — https://gymvisual.com/"** visible.
  - Clonar ese repo **no** da licencia propia sobre la media — los términos
    del titular (https://gymvisual.com/content/3-terms-and-conditions-of-use)
    son la referencia final; ante duda, no redistribuir a mayor resolución.

## Pendiente (no implementado en esta sesión)

La integración real (descargar `exercises.json`, mapear al modelo `Exercise`
de la app por `slug`, reemplazar el visor 3D en
`lib/features/exercise_3d/exercise_3d_view.dart` por un visor de GIF con
atribución visible) queda para una sesión aparte — es un cambio de varias
pantallas y del pipeline de assets, fuera del límite de 3 archivos por sesión.

Esta carpeta (`assets/models_3d/`) y el código del visor 3D actual
(`Exercise3DView`, dependencia `flutter_3d_controller`) siguen intactos hasta
que se haga esa migración.
