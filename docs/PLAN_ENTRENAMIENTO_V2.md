# Plan — Corrección del sistema de entrenamiento, historial, importación y catálogo

Estado: propuesta, pendiente de aprobación. Fecha: 2026-07-15.
Alcance: 11 fases, cada una un commit independiente (Change Scope Limiter: máx. 3 archivos por cambio).

---

## 0. Diagnóstico — qué encontré leyendo el código

Antes de proponer nada, verifiqué cada error reportado contra el código real. Tres de los
diagnósticos del reporte no coinciden con la causa real, y eso cambia la solución.

### 0.1 «Duración: 4433 min» — NO es el volumen

La suposición del reporte es que el campo muestra los kg totales. No es así. En
`lib/screens/history/history_list_screen.dart:244` el cálculo es literalmente:

```dart
session.endedAt!.difference(session.startedAt).inMinutes
```

No hay ninguna ruta de código por la que el volumen entre a ese widget. La coincidencia con
los 4433 kg es casualidad. La causa real está en el importador, y son dos bugs sumados:

1. `ImportEngine.import()` (`import_engine.dart:31-33`) agrupa las filas **por día calendario**
   y usa `DateTime(year, month, day)` como `startedAt` → toda sesión importada arranca a las
   **00:00**. Por eso el historial muestra `10/07/2026 00:00`.
2. `ImportEngine` cierra la sesión con `workoutRepository.finishSession()`
   (`workout_repository.dart:74-80`), que estampa `endedAt = DateTime.now()` → **la hora en que
   corriste la importación**, no la hora en que terminaste de entrenar.

Resultado: `duración = (momento de la importación) − (medianoche del día del entreno)`.

**Confirmado al minuto contra tu CSV real** (`workout_data(3).csv`, 1.621 filas, 85 sesiones):

| | |
|---|---|
| Sesión «Viernes pierna volumen» | `start_time` = 10 jul 2026, 15:44 → `end_time` = 10 jul 2026, 16:46 |
| Duración real | **62 min** (`1 h 2 min`) |
| Volumen real de esa sesión | **5.847 kg** — *no* 4.433 |
| Medianoche del 10/07 → 13/07 01:53 | **4.433 min exactos** |

Ninguna sesión del archivo tiene un volumen de 4.433 kg (la más cercana es 4.404,5 kg, y es de
otro día). El número que ves es la distancia entre la medianoche del entreno y el momento en que
corriste la importación: el 13/07 a la 01:53. La hipótesis del volumen queda descartada.

El importador **descarta `start_time` y `end_time` del CSV**: en
`mapping_models.dart:5-17` el enum `CanonicalField` no tiene campo de hora de fin, y en
`auto_mapper.dart` la columna `start time` está listada como sinónimo de `date` — o sea que la
hora se parsea y después se tira al truncar a medianoche.

La corrección que pedís (`end_time − start_time`) es la correcta, pero hay que arreglarla en el
importador, no en la pantalla del historial.

### 0.2 «Cientos de líneas de récords» — la tabla no tiene unicidad

`WorkoutRepository._checkPersonalRecords()` (`workout_repository.dart:306-357`) hace un
`INSERT` en `PersonalRecords` **cada vez que un set supera el máximo anterior**. No hay
`UPDATE`, no hay índice único, no hay agrupación por ejercicio. En uso normal esto crece
despacio; pero la importación reproduce años de historial set por set, y cada progresión
histórica que alguna vez hiciste inserta una fila. De ahí las cientos de líneas.

Peor: `sessionRecords()` (`workout_repository.dart:216`) atribuye los récords a una sesión por
`achievedAt`, y durante la importación `achievedAt = DateTime.now()` para **todos** → todos los
récords históricos quedan colgados de la última sesión importada.

El fix no es filtrar duplicados en la UI. Es rediseñar la tabla: **una fila por
(ejercicio, tipo de récord)** con upsert, más una columna `sessionId` para saber en qué sesión
se logró. Eso elimina duplicados por construcción y da el agrupamiento por ejercicio gratis.

### 0.3 «Las rutinas no se importan» — el CSV no las trae. Confirmado.

Tu export es el estándar de Hevy, con estas columnas y nada más:

```
title, start_time, end_time, description, exercise_title, superset_id,
exercise_notes, set_index, set_type, weight_kg, reps, distance_km,
duration_seconds, rpe
```

Cada fila es **un set ejecutado**. No hay rutinas, ni días, ni orden planificado, ni descanso
configurado, ni peso objetivo. **Las rutinas no se pueden importar porque el dato no existe en el
origen** — no es un bug del importador. Ninguna app puede leer lo que Hevy no exporta.

Pero tu archivo tiene una estructura que resuelve el problema igual de bien: **85 sesiones con
solo 5 títulos distintos**, que son exactamente tu split semanal.

| Título | Sesiones |
|---|---|
| Jueves upper pull | 20 |
| Lunes pierna | 18 |
| Viernes pierna volumen | 16 |
| Miércoles glúteo y femoral | 16 |
| Entrenamiento por la tarde 💪 | 15 |

O sea que **se puede derivar una rutina de 5 días desde tu propio historial**: cada título es un
día, y de la última sesión de cada grupo salen los ejercicios, su orden y las series típicas. El
resultado es tu rutina real, la que venís entrenando hace 5 meses. La Fase 3b queda desbloqueada
con esta forma.

Otros datos del archivo, útiles para el resto del plan: rango 11/02/2026 → 10/07/2026, duraciones
entre 32 y 116 min (media 62), 31 ejercicios distintos, **ningún día tiene dos sesiones** (así que
el bug de agrupar por día calendario, §0.1, no llegó a fusionar nada en tu caso — pero sigue ahí),
y `rpe` está **vacío en las 1.621 filas** (nunca lo usaste → importar RPE es irrelevante por ahora).

### 0.3b El importador está perdiendo tus dropsets y tus supersets, en silencio

Esto no estaba en tu lista y lo encontré cruzando el CSV con el código.

- **`set_type`** (`auto_mapper.dart`) está listado como sinónimo de `CanonicalField.isWarmup`, y
  `validators.dart:111-116` lo colapsa a un booleano. Tu archivo tiene **95 filas `dropset`**: cada
  una evalúa a `false` y se guarda como un set normal. **Sin error, sin aviso.** Funciona de
  casualidad para `warmup` (está en la lista de valores verdaderos), pero Hevy usa un enum de
  4 valores (`normal`/`warmup`/`dropset`/`failure`) y meterlo en un bool destruye los otros dos.
- **`superset_id`**: 191 filas lo tienen cargado. `CanonicalField` no tiene campo para supersets
  → la columna se ignora entera y tus supersets se importan como ejercicios sueltos.

Irónico: la tabla `WorkoutSets` **ya tiene** `techniques` y `supersetGroupId`
(`database.dart:87-88`), y `availableTechniques` (`workout.dart:135`) ya define `drop_set`. El
destino existe; lo que falta es el mapeo. Va en la Fase 3.

### 0.4 El cronómetro sí se pierde, pero menos de lo que parece

`active_workout_screen.dart:42-44` ya calcula con `DateTime.now().difference(session.startedAt)`,
no acumula ticks. O sea que **la duración ya es wall-clock y sobrevive a minimizar la app**. Lo
que no sobrevive es:
- El `Timer.periodic` muere con el widget → al volver, no refresca hasta reconstruir.
- El descanso (`rest_timer_banner.dart`) **sí** es un `Timer.periodic` puro → ese se pierde de verdad.
- No hay persistencia del borrador (pesos/reps escritos, ejercicio actual, serie actual).
- No hay notificación ni foreground service.
- No hay guarda de «una sola sesión activa».

### 0.5 Riesgo de compatibilidad: el catálogo de ejercicios está acoplado al backend

`WorkoutSets.exerciseId` es un `int` que referencia `Exercises.id`, y ese id es **el mismo id del
catálogo de Supabase** (comentario explícito en `database.dart:6-8`). El payload de sync manda
`exercise_id` crudo al servidor (`workout_session_syncable.dart`, `_drainPendingOps`). Hoy hay
**25 ejercicios** en `assets/data/exercises.json` y 25 en Supabase.

Meter 1.324 ejercicios del dataset con sus ids propios **rompe el FK del servidor** y por lo tanto
el sync de todos los sets nuevos. Esto no es un detalle: es la restricción que gobierna la Fase 8.

### 0.6 Riesgo legal y de tamaño: los GIFs del dataset

Verifiqué `hasaneyldrm/exercises-dataset`: 1.324 ejercicios, `data/exercises.json`, instrucciones
en 9 idiomas, 1.324 thumbnails 180×180 y 1.324 GIFs. **El código es MIT, pero la media no**: los
GIFs e imágenes son © Gym Visual, redistribuidos ahí con permiso y sujetos a sus Términos, con
obligación de conservar la atribución.

Dos consecuencias:
- **Legal**: que ese repo tenga permiso para redistribuir no te da permiso a vos para
  redistribuirlos dentro de una app publicada. Antes de empaquetarlos hay que revisar los
  Términos de Gym Visual. No soy tu abogado, pero no puedo recomendarte que embebas media de
  terceros en un binario distribuible sin verificar esto.
- **Tamaño**: 1.324 GIFs son del orden de 300–600 MB. Google Play tiene un límite de 150 MB por
  APK/AAB. **Empaquetar todos los GIFs en assets es técnicamente imposible.**

Ver Fase 8 para la estrategia que propongo.

---

## Fases

Cada fase es un commit. Las fases 1–5 son correcciones y no dependen de decisiones pendientes:
se pueden arrancar ya. Las 6–9 dependen de las decisiones de la sección «Decisiones abiertas».

### Fase 0 — Migración de esquema (schema v6)

Un solo `onUpgrade` que cubre todo lo que las fases siguientes necesitan, para no encadenar
migraciones. Archivos: `database.dart`, `database.g.dart` (generado), test de migración.

| Tabla | Cambio | Para qué |
|---|---|---|
| `PersonalRecords` | + `sessionId` (nullable, FK), índice único `(exerciseId, recordType)` | Elimina duplicados por construcción; atribuye el PR a su sesión real |
| `WorkoutSessions` | + `title` (nullable) | Hevy exporta el nombre del entreno; hoy se descarta |
| `RoutineExercises` | + `targetWeightKg`, `setType`, `tempo`, `targetRpe`, `targetRir` | Constructor de rutinas (Fase 7) |
| `ActiveWorkoutDrafts` | tabla nueva, fila única | Persistencia del borrador (Fase 5) |

**No** agrego columna de volumen ni de duración cacheados: ambos se derivan de los sets y de
`startedAt`/`endedAt`. Cachearlos es denormalización sin necesidad todavía (YAGNI) y abre la
puerta a que se desincronicen.

Migración de `PersonalRecords`: la tabla actual está contaminada (cientos de filas basura, todas
con `achievedAt` = momento de la importación). No se puede deduplicar preservando la verdad
histórica. Se **vacía y se reconstruye** replayando los sets en orden cronológico — ver Fase 2.
Es la única forma de que `achievedAt` y `sessionId` queden correctos.

Riesgo: si el replay tiene un bug, se pierden los PRs. Mitigación: el replay es una función pura
testeada aparte, y los datos de origen (`WorkoutSets`) no se tocan → siempre se puede volver a
reconstruir.

### Fase 1 — Duración real y volumen en el historial

Archivos: `history_list_screen.dart`, `workout_repository.dart`, `workout.dart`.

- `WorkoutSessionSummary` gana `totalVolumeKg`, `exerciseCount`, `setCount`, y `duration`
  derivada. Se calculan en una sola consulta agregada, no N+1 por sesión.
- La tarjeta del historial pasa a:
  - Fecha sola (`10/07/2026`), sin hora → `DateFormat.yMd`.
  - ⏱ tiempo entrenando, formateado `1 h 12 min` / `48 min` (nunca miles de minutos).
  - 🏋 volumen total (Σ peso × reps, excluyendo warm-ups).
  - 💪 ejercicios distintos · 📊 series.
- Guarda de sanidad: si `endedAt − startedAt` da > 12 h (dato corrupto de la importación vieja),
  se muestra `—` en vez de un número absurdo. Esto es red de seguridad, no la corrección: la
  corrección es la Fase 3.

**Decisión**: `totalVolumeKg` excluye warm-ups. Es lo que hacen Hevy y Strong. Si preferís
incluirlos, es un parámetro.

### Fase 2 — Récords personales sin duplicados

Archivos: `personal_records_service.dart` (nuevo), `workout_repository.dart`, test.

- Extraer la lógica de PRs de `WorkoutRepository` a un `PersonalRecordsService` con dos entradas:
  - `evaluateSet(...)` → upsert sobre `(exerciseId, recordType)`; devuelve el PR solo si es nuevo.
  - `rebuildAll()` → borra y reconstruye toda la tabla replayando `WorkoutSets` en orden
    cronológico. Lo usa la migración (Fase 0) y la importación (Fase 4).
- `sessionRecords(sessionId)` deja de filtrar por `achievedAt` y filtra por `sessionId` → los
  récords de una sesión son los que se lograron en esa sesión, punto.
- La UI de «Nuevos récords» agrupa por ejercicio y muestra el valor, como pediste.

El núcleo (`rebuildAll` sobre una lista de sets en memoria) se escribe como función pura →
testeable sin base de datos. Tests: sin sets, un set, progresión, empate, warm-up ignorado,
récord de reps y de peso en el mismo set.

### Fase 3 — Importador de Hevy: horas reales y título

Archivos: `mapping_models.dart`, `auto_mapper.dart`, `import_engine.dart`.

- `CanonicalField` gana `startTime`, `endTime`, `sessionTitle`, `setType`, `supersetId`.
- `auto_mapper.dart`: `start time`/`start_time` deja de ser sinónimo de `date` y pasa a
  `startTime`; se agrega `end time`/`end_time` → `endTime`; `title`/`workout name` → `sessionTitle`.
- **`set_type` deja de ser sinónimo de `isWarmup`** (§0.3b) y pasa a `setType`. `validators.dart`
  lo valida como enum de 4 valores en vez de coercionarlo a bool. En el `ImportEngine`:
  `warmup` → `isWarmup = true`; `dropset`/`failure` → entrada en `techniques` (`drop_set` /
  `to_failure`, que ya existen en `availableTechniques`); `normal` → nada. Sin columnas nuevas.
- **`superset_id` → `supersetGroupId`** (la columna ya existe). Los ids de Hevy son por sesión,
  así que se remapean a ids locales dentro de cada sesión.
- `ImportEngine` agrupa por **`(sessionTitle, startTime)`**, no por día calendario. Dos entrenos
  el mismo día dejan de fusionarse en uno solo (en tu archivo no pasa — ningún día tiene dos
  sesiones — pero el bug está y es gratis cerrarlo acá).
- La sesión se persiste con `startedAt = start_time` y `endedAt = end_time` reales. Se agrega
  `WorkoutRepository.finishSession(id, {DateTime? endedAt})` — parámetro opcional, no rompe
  ninguna llamada existente.
- Fallback: si el CSV no trae `end_time`, `endedAt` queda `null` y la UI muestra `—`. **Nunca**
  `DateTime.now()`.

**Migración de datos ya importados**: las sesiones que importaste tienen `endedAt` basura. Una
rutina de reparación única las detecta (duración > 12 h) y pone `endedAt = null`. No se puede
recuperar la hora real sin reimportar. Recomiendo: borrar las sesiones importadas y reimportar
con el importador corregido — más limpio y ahora sí trae las horas verdaderas.

### Fase 3b — «Generar rutina desde el historial» (desbloqueada)

Archivos: `routine_from_history.dart` (nuevo), `routine_repository.dart`, test.

Confirmado en §0.3 que el CSV no trae rutinas. Se derivan del historial ya importado — es un paso
posterior e independiente de la importación, no un parser.

Función pura `deriveRoutine(List<WorkoutSession>)`:
1. Agrupar sesiones por `title` → un `RoutineDay` por título (5 días, en tu caso).
2. Por día, tomar la **sesión más reciente** como plantilla: refleja tu programación actual, no un
   promedio de 5 meses que mezclaría ejercicios que ya dejaste de hacer.
3. Por ejercicio: `orderIndex` = orden de aparición; `targetSets` = nº de series efectivas;
   `targetRepsMin`/`Max` = mín/máx de reps; `targetWeightKg` = peso de la última serie efectiva;
   `setType`/supersets = lo que trajo el CSV (Fase 3).
4. `targetRestSeconds` **queda en el default de 90 s**: el dato no existe en el origen y no lo voy
   a inventar. Lo ajustás en el constructor (Fase 7).

Preview editable antes de guardar. No pisa rutinas existentes: crea una nueva.

### Fase 4 — Reconstrucción de agregados tras importar

Archivo: `import_engine.dart` + el servicio de la Fase 2.

Verifiqué que racha, calendario, heatmap, estadísticas, frecuencia y volumen histórico **ya se
calculan en vivo** desde `WorkoutSessions`/`WorkoutSets` (`stats_repository.dart`,
`gamification_repository.dart`). No hay contadores persistidos que reconstruir: **en cuanto la
importación escriba sesiones con fechas correctas, todo eso aparece solo.** Lo único que hoy
está realmente roto son los PRs (materializados en tabla).

Entonces esta fase es chica: al final de `import()`, llamar `PersonalRecordsService.rebuildAll()`
una vez, en lugar de evaluar PRs set por set durante la importación. Más rápido y correcto.

Esto responde a «no quiero empezar de cero solo porque importé»: no empezás de cero, ya funciona;
lo que fallaba era que las fechas importadas estaban mal (Fase 3) y por eso las rachas y el
calendario salían raros.

### Fase 5 — Sesión activa: persistencia y unicidad

Archivos: `active_workout_repository.dart` (nuevo), `active_workout_screen.dart`, `start_workout_screen.dart`.

- El cronómetro **ya** es wall-clock (§0.4). Lo que se agrega es que el `Timer.periodic` sea solo
  el *refresco de la UI* (explícito en un comentario, para que nadie lo «arregle» hacia un
  contador acumulativo) y que se reenganche vía `WidgetsBindingObserver.didChangeAppLifecycleState`.
- `ActiveWorkoutDrafts`: fila única con ejercicio actual, serie actual, pesos/reps tipeados,
  notas, fin del descanso (como `DateTime` absoluto, no como segundos restantes), supersets y
  dropsets. Se escribe con debounce, no en cada tecla.
- El descanso se recalcula igual que la duración: `restEndsAt − now`. El `Timer` solo repinta.
- Guarda de unicidad: `startSession()` falla si existe una sesión con `endedAt == null`. Al abrir
  la app, si hay una sesión activa, se navega a ella.

### Fase 6 — Notificación persistente y descanso (requiere decisión)

Necesita una dependencia nueva: `flutter_local_notifications` + un foreground service de Android
(`android/app/src/main/AndroidManifest.xml`, permiso `POST_NOTIFICATIONS` en API 33+, y
`FOREGROUND_SERVICE`). Es la primera vez que el proyecto toca notificaciones.

- Notificación ongoing (no descartable) mientras haya sesión activa: duración, ejercicio actual,
  serie X de Y, y un tap que vuelve al entreno.
- Al terminar una serie: descanso automático según `targetRestSeconds` del ejercicio.
- La notificación de descanso cuenta hacia atrás. **El conteo lo hace el sistema**
  (`setChronometer`/`when`), no un `Timer` de Dart — así sigue andando con la app muerta.
- Al llegar a cero: vibración, sonido configurable, cambio de color y texto «Ya podés empezar la
  siguiente serie».

Riesgo real: los fabricantes chinos (Xiaomi, Huawei, Oppo) matan foreground services agresivamente.
Mitigación: como todo se deriva de timestamps absolutos, aunque el proceso muera, al reabrir la
app el estado es correcto. La notificación es un lujo; la corrección del tiempo no depende de ella.

### Fase 7 — Constructor de rutinas

Archivos: pantalla de edición de rutina, `routine.dart`, `routine_repository.dart`.

Por ejercicio: peso objetivo, series, reps, RPE, RIR, descanso, tempo, notas, tipo de serie.
Tipos: Normal, Superset, Dropset, Giant Set, Myo Reps, Rest Pause, Warm Up, Back Off, Failure.

Nota de reuso: `availableTechniques` (`workout.dart:135`) ya tiene 5 de los 9 tipos y
`WorkoutSets.techniques` ya los persiste. Extiendo ese mapa en vez de crear un enum paralelo.
`setType` en `RoutineExercises` es el tipo *planificado*; `techniques` en `WorkoutSets` es lo
*ejecutado*. Son cosas distintas y deben seguir separadas.

### Fase 8 — Catálogo de ejercicios + ExerciseService (requiere decisión)

La restricción que manda es §0.5: los ids del catálogo son claves compartidas con Supabase.
Propuesta:

- **`Exercises` gana `datasetId` (texto, nullable)** = el id del dataset. El `id` int sigue siendo
  el id canónico de tu catálogo. El dataset se *enriquece contra* el catálogo por slug/nombre
  normalizado, no lo reemplaza.
- Ejercicios del dataset sin match en tu catálogo: no se pueden usar en sets hasta existir en
  Supabase. Camino limpio: script de seed que los inserta en Supabase, y el catálogo local se
  sincroniza desde ahí. Así el id sigue siendo uno solo en los dos lados.
- Los campos ricos (músculos, equipo, instrucciones, dificultad, variantes) van a `detailJson`,
  que ya existe y ya está pensado para esto (`database.dart:16-17`). Cero columnas nuevas.
- `ExerciseService`: fachada única (buscar, filtrar, media, instrucciones, músculos, variantes,
  historial, estadísticas). La UI no vuelve a tocar Drift para ejercicios. El historial y las
  estadísticas por ejercicio ya existen en `stats_repository.dart` → el servicio los compone, no
  los reimplementa.

**Media**: no se pueden empaquetar 1.324 GIFs (§0.6). Ver «Decisiones abiertas».

### Fase 9 — Pantalla de ejercicio e inteligencia durante el entreno

Pantalla completa (no diálogo) con: cabecera, media en loop, músculos, instrucciones, tips,
errores comunes, variantes, historial personal, gráficas de progresión, y vuelta al entreno sin
tocar el cronómetro (con la Fase 5 esto es gratis: el estado vive en la base, no en el widget).

Durante el entreno, bajo la media: última sesión, mejor marca, objetivo de hoy y sugerencia de
progresión. La sugerencia es una regla explícita y testeada (si completás el tope del rango de
reps con RPE ≤ 8, subir el incremento mínimo), **no** el LLM — determinista, offline, auditable.
El coach IA ya existe (`coach_gateway.dart`) y es otra cosa.

Nota: «errores comunes» **no está en el dataset**. Hay que escribirlo a mano o dejarlo fuera. No
lo voy a inventar con el LLM y presentarlo como consejo de entrenamiento.

### Fase 10 — Informe final

Errores encontrados y causa raíz, correcciones, cambios de modelo de datos con su migración, plan
de pruebas por funcionalidad, y qué del dataset no se pudo integrar y por qué.

---

## Decisiones abiertas — necesito tu respuesta

1. **Media del catálogo.** No se pueden empaquetar los GIFs (§0.6: 300–600 MB vs. límite de
   150 MB de Play, más la licencia de Gym Visual). Opciones:
   - **(recomendada)** Empaquetar los 1.324 thumbnails 180×180 (~15 MB, viable) + descargar el GIF
     bajo demanda la primera vez que abrís el ejercicio y cachearlo en disco. Offline real después
     del primer uso, y solo se bajan los ejercicios que usás (en la práctica, 30–50).
   - Empaquetar GIFs solo de los ~25–60 ejercicios de tu catálogo actual y traer el resto bajo
     demanda.
   - Otra fuente de media con licencia permisiva.

   Ninguna opción cumple literalmente «sin depender de Internet» *y* «todos los GIFs»: son
   incompatibles. Elegí cuál relajar.

2. **Licencia de la media.** ¿Revisás los Términos de Gym Visual, o arrancamos con thumbnails y
   dejamos los GIFs detrás de esa verificación?

3. **Ejercicios nuevos en Supabase.** ¿Sembramos los 1.324 en Supabase (mantiene un id único en
   ambos lados, es lo correcto a futuro con multi-dispositivo) o dejamos el catálogo extendido
   como solo-local por ahora?

4. **Reimportar.** Recomiendo borrar las 85 sesiones importadas y reimportar con el importador
   corregido: recuperás las horas reales, los 95 dropsets y los 191 sets en superset, que hoy están
   perdidos. Es la opción limpia y tu CSV es la fuente de verdad. ¿Vamos por ahí?

~~Export de Hevy~~ — resuelto: archivo recibido y analizado (§0.3).

---

## Orden de ejecución sugerido

Fases 0 → 1 → 2 → 3 → 4 arreglan **todo lo que está roto hoy** y no dependen de ninguna decisión.
Son ~5 commits y creo que deberíamos hacerlas primero y verificarlas en el emulador antes de
tocar el catálogo, que es el bloque grande y el que tiene los riesgos legales y de tamaño.

Fase 3b ya está desbloqueada y va después de reimportar (necesita el historial con títulos).
Fase 5 es independiente y puede ir en paralelo.
Fases 6, 8, 9 esperan las decisiones de arriba.
