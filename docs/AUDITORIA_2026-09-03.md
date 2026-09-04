# AUDITORÍA NEXFIT — HALLAZGOS Y ÓRDENES DE TRABAJO
Fecha: 2026-09-03 · Rama: `master` · Versión: 1.1.4+7
Estado del árbol auditado: **working tree con el rediseño v2 sin commitear** (hubs Entrenar/Progreso/Cuerpo, `StepperField`, `PillTabBar`, `WeightUnitProvider`, `WorkoutSummaryScreen`, `calendar_screen.dart` borrado).

## Cómo se hizo esta auditoría (para reproducirla)
- `flutter analyze`: **11 infos, 0 errores/warnings**.
- `flutter test`: **124 tests, todos en verde**.
- App ejecutada en Windows desktop. Para que compile hizo falta agregar en `windows/CMakeLists.txt`:
  `add_definitions(-D_SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS)` — sin eso `flutter_inappwebview_windows` (dependencia transitiva de `flutter_3d_controller`) no compila con MSVC 14.5x. **Ese cambio ya está aplicado, no lo revertir.**
- Se creó `lib/main_audit.dart` (**archivo temporal de auditoría**): monta el árbol de providers real con auth simulada, siembra 3 sesiones + 1 rutina + 1 objetivo + 1 sesión activa, y captura las 22 pantallas a PNG con `RepaintBoundary.toImage`. Úsalo para el ciclo *implementar → ejecutar → capturar → comparar*. **Bórralo antes del commit final.**
- Capturas generadas: `%TEMP%\claude\...\scratchpad\shots\01..22*.png` (regenerables corriendo el harness).

---

# PARTE 1 — PUNTUACIÓN

| Dimensión | Nota | Motivo en una línea |
|---|---:|---|
| UX | 4/10 | El bucle central (registrar una serie) cuesta decenas de toques y no hay dato de referencia. |
| UI | 6/10 | Tokens y paleta bien definidos, pero conviven 3 estilos de tarjeta, 2 de tabs y 2 de encabezado. |
| Navegación | 3/10 | Bottom nav + pills + TabBar anidado = 3 niveles horizontales; el Dashboard duplica toda la barra inferior. |
| Entrenamiento | 3/10 | La rutina no llega al entrenamiento; el temporizador de descanso casi nunca arranca; no hay "serie completada". |
| Progreso | 4/10 | Datos calculados bien, pero contaminados por sesiones abiertas y por récords en 0. |
| Funcionalidades | 5/10 | Mucha superficie, poca profundidad: 25 ejercicios, 0 modelos 3D, coach IA siempre "Próximamente". |
| Rendimiento | 5/10 | N+1 en el detalle de sesión y recarga completa de la sesión en cada toque de stepper. |
| Arquitectura | 8/10 | Repos/sync/animaciones bien desacoplados, offline-first real, analyzer y tests limpios. |
| Accesibilidad | 2/10 | 2 usos de `Semantics` en 150 archivos; placeholders como etiquetas; 1 solo archivo responsive. |
| **Calidad general** | **4.5/10** | Base técnica sólida con fallas críticas de datos y de flujo en el núcleo del producto. |

---

# PARTE 2 — HALLAZGOS CRÍTICOS (verificados con evidencia, no inferidos)

## C1 — La cola de sync se corrompe en cada serie que se registra
**Archivo:** `lib/repositories/workout_repository.dart` → `updateSet()`, rama `set.serverId == null`.
Cuando una serie todavía no sincronizó, `updateSet` **sobrescribe** el `payloadJson` del `insert` pendiente con el payload parcial recibido.

Evidencia (ejecutada contra la base real):
```
addSet(exercise_id, set_number:1, weight_kg:0, reps:0)
updateSet(id, {'weight_kg': 80.0})
updateSet(id, {'reps': 8})
→ pendingSetOps: insert -> {"reps":8}
```
El insert que viajará a Supabase queda sin `exercise_id`, `set_number` ni `weight_kg`. `WorkoutSessionSyncable._drainPendingOps` hará `insert({'session_id':…, 'reps':8})` → o falla por NOT NULL y **bloquea la cola para siempre**, o crea filas basura.
Como el flujo nuevo (`_quickAddSet` inserta en 0/0 y los steppers corrigen con `updateSet`) **siempre** crea-y-después-actualiza, esto afecta a **todas** las series registradas con la UI nueva.

**ORDEN:** en la rama `serverId == null`, hacer *merge* del payload parcial sobre el payload del insert pendiente (leer el JSON existente, aplicar las claves nuevas, reescribir). Alternativa preferible: reconstruir el payload del insert desde la fila actual de `workoutSets` en vez de guardar un JSON aparte. Agregar test en `test/repositories/` que reproduzca la secuencia de arriba.

## C2 — Los récords personales quedan en 0 y nunca se recalculan
**Archivos:** `lib/screens/workout/active_workout_screen.dart` → `_quickAddSet()`; `lib/repositories/workout_repository.dart` → `addSet()`/`updateSet()`; `lib/repositories/personal_records_service.dart` → `evaluateSet()`.

Evidencia:
```
addSet(ejercicio sin historial, weight_kg:0, reps:0)
→ records-al-insertar = 2 · PR max_weight=0.0 · PR max_reps=0.0
updateSet(→ 80 kg) ; updateSet(→ 8 reps)
→ PRs siguen siendo max_weight=0.0 · max_reps=0.0
```
Dos fallas encadenadas:
1. `addSet` evalúa récords con la serie placeholder en 0/0 → inserta un PR de **0 kg** y **0 reps** para todo ejercicio nuevo.
2. `updateSet` **no llama nunca** a `PersonalRecordsService` → el peso real que el usuario carga con los steppers no se evalúa jamás.

Contaminación aguas abajo: banner "¡Récord Personal!", `strength_profile_tab`, `upcomingRecordPredictions`, y **XP** (`_xpPerRecord = 25` por cada récord basura → nivel y racha inflados).

**ORDEN:**
1. No evaluar récords en series con `reps <= 0 || weightKg <= 0`.
2. Llamar a `evaluateSet` desde `updateSet` cuando cambien `weight_kg` o `reps` (y no sea `is_warmup`).
3. Correr `rebuildPersonalRecords()` en una migración de datos para limpiar los PRs en 0 ya persistidos.
4. Tests: PR no se crea con 0/0; PR sí se crea al corregir la serie.

## C3 — El sync es solo de subida: no existe restauración
**Archivo:** `lib/core/sync/syncable.dart` — el contrato `SyncableEntity` solo declara `push(AppDatabase db)`. No hay `pull`/`restore` en ninguna entidad ni en `SyncEngine`.
Consecuencia: reinstalar la app o cambiar de teléfono = **se pierde todo el historial**, aunque Ajustes lo llame "Mis datos (backup)" y anuncie "se suben a la nube". El único camino de vuelta es el import manual de CSV/Excel.
Se ve además en Perfil: los campos aparecen **vacíos** aunque el usuario autenticado tenga edad/sexo/altura/peso, porque `ProfileScreen` lee de la tabla local `profiles` y nadie la puebla desde el servidor.

**ORDEN:** decidir y ejecutar una de las dos, no dejarlo ambiguo:
- (a) Implementar `pull` en `SyncableEntity` + resolución de conflictos por `updatedAt`, empezando por `ProfileSyncable` y `WorkoutSessionSyncable`.
- (b) Si (a) no entra en el alcance, **cambiar el copy de Ajustes** para no prometer backup: decir explícitamente que la restauración es por exportación manual, y destacar el export.

## C4 — La rutina no llega al entrenamiento
`ActiveWorkoutRepository.begin(routineId:)` guarda el `routineId` como FK en la sesión y **nada más**. Nadie lee `RoutineDay.exercises` para precargar el entrenamiento: iniciar "con esta rutina" abre la misma pantalla vacía que "Entrenamiento libre" ("Agregá un ejercicio para empezar").
La tabla `RoutineExercises` ya guarda `targetSets`, `targetRepsMin/Max`, `targetRestSeconds`, `targetWeightKg`, `setType`, `tempo`, `targetRpe`, `targetRir`, `notes` — **todo eso se descarta**. El constructor de rutinas (514 líneas) es decorativo.

**ORDEN:** al iniciar sesión con rutina, precargar los ejercicios del día correspondiente con sus series objetivo (peso/reps sugeridos, descanso objetivo). Mostrar en cada fila el objetivo vs. lo realizado. Si la rutina tiene varios días, preguntar qué día (o inferirlo por el último día entrenado de esa rutina).

## C5 — El temporizador de descanso casi nunca arranca
En `ActiveWorkoutScreen` el descanso se dispara **solo** desde `_openAdvancedEditor` (el sheet de 8 campos, acción secundaria detrás del ícono `Icons.tune`). En el flujo normal —agregar ejercicio, mover steppers, "Añadir serie"— nunca se llama a `updateProgress(restEndsAt:)`.
Además **no existe control de "serie completada" por fila**: la única forma de marcar avance es el botón "Marcar como completado" que marca *todas* las series del ejercicio de golpe (`markExerciseCompleted`).
`RestTimerBanner` está bien implementado (instante absoluto persistido, sobrevive al cierre de la app) pero es código muerto en la práctica.

**ORDEN:** agregar un check por serie que (1) marque `completed`, (2) arranque el descanso con `restSeconds` de la serie o el `targetRestSeconds` de la rutina. Ese check es el gesto central del bucle de gimnasio: debe ser el elemento más grande y accesible de la fila.

## C6 — Registrar una serie cuesta demasiado
Cada serie nace en `0.0 / 0 / 0.0`. Para cargar 80 kg con paso de 2.5 hacen falta **32 toques** en el `+`, o abrir un diálogo modal (tocar número → teclear → "Guardar") **por cada uno de los 3 campos**. No hay:
- valor de la sesión anterior como referencia ni como prefill (grep de "última vez"/"anterior": **0 resultados** en toda la app),
- objetivo de la rutina (ver C4),
- teclado numérico inline.
`_addSetFor` sí copia peso/reps de la última serie —bien— pero solo a partir de la segunda serie del ejercicio.

**ORDEN:** la primera serie de un ejercicio debe nacer con el valor de la última vez que se hizo ese ejercicio (o el objetivo de la rutina). Mostrar "Última vez: 80 kg × 8" en cada fila. Reemplazar el diálogo modal por edición inline.

---

# PARTE 3 — PROBLEMAS DE NAVEGACIÓN

## N1 — Tres niveles de navegación horizontal apilados
`HomeShell` (5 destinos) → `PillTabBar` (5 pills scrollables) → dentro de "Estadísticas", `StatsHubScreen(embedded:true)` monta **otro** `TabBar` de 5 pestañas.
En la captura `06-progreso-estadisticas.png` se ven las dos filas de tabs una sobre la otra **con estilos distintos** (pill azul vs. subrayado plano), y ambas cortan su última pestaña ("Retos", "Estándares") sin ninguna señal de scroll. Los dos `TabBarView` anidados también se pelean el gesto de swipe horizontal.

**ORDEN:** eliminar un nivel. Opción recomendada: aplanar las 5 sub-pestañas de Estadísticas en una sola vista scrolleable por secciones (Músculos / Fuerza / Progreso / Tonelaje / Estándares como bloques), dejando un único `PillTabBar` por hub. Nunca anidar `TabBar` dentro de `TabBar`.

## N2 — El Dashboard duplica toda la barra inferior
9 de las 11 tiles del Dashboard hacen `Navigator.push` de `ProgresoHubScreen`/`CuerpoHubScreen` — los mismos hubs que ya están a un toque en la barra inferior. Además se **apilan** sobre el shell: el usuario queda en una pantalla idéntica a la pestaña pero sin la barra inferior, con un back button.
La tile "Calendario / Descarga y planes" apunta a Progreso→Resumen; `calendar_screen.dart` fue borrado. Copy obsoleto y engañoso.

**ORDEN:** el Dashboard no debe ser un menú de la barra inferior. Reemplazar los 3 bloques de tiles por: (1) estado del entrenamiento de hoy, (2) reanudar sesión activa si hay, (3) 2-3 métricas reales con tendencia, (4) accesos a lo que **no** está en la barra inferior (Coach, Ajustes). Si una tile debe navegar a un hub, hacerlo cambiando la pestaña del shell, no con `push`.

## N3 — No se puede reanudar un entrenamiento desde el inicio
Con una sesión activa en la base, el Dashboard no muestra nada. El único punto de reanudación es la tarjeta "En curso / Continuar sesión" enterrada en Entrenar → pestaña Historial (captura `04-entrenar-historial.png`). `StartWorkoutScreen` sí redirige con `pushReplacement` si hay sesión activa, pero hay que ir a buscarla.

**ORDEN:** banner persistente de "entrenamiento en curso" en el Dashboard (y idealmente en el shell completo).

## N4 — No se puede salir de la pantalla de entrenamiento activo
`ActiveWorkoutScreen` no tiene botón de retroceso ni acción de minimizar. Las únicas salidas son "Finalizar" (sin confirmación, incluso con 0 series) o cerrar la app. No se puede consultar la rutina ni el detalle de un ejercicio a mitad del entrenamiento.

**ORDEN:** permitir minimizar el entrenamiento (volver al shell con el banner de C/N3 activo) y pedir confirmación al finalizar.

## N5 — El patrón `embedded` está implementado de 4 formas distintas
- `return content` sin Scaffold: `exercise_list`, `history_list`, `gamification`, `nutrition`, `recovery`.
- `Scaffold` transparente anidado con FAB: `goals`, `challenges`, `measurements`, `wearables`.
- `AppBar` transparente con `toolbarHeight: 44` solo para colgar un `IconButton`: `measurements`, `challenges`, `wearables`.
- Botón "+" inline en el header del contenido: `routine_list`.

**ORDEN:** un solo contrato. Recomendado: la pantalla embebida devuelve **solo el contenido**, y el hub expone las acciones (FAB / acciones de AppBar) que le pase la pestaña activa. Eliminar los `Scaffold` y `AppBar` anidados.

---

# PARTE 4 — PROBLEMAS DE UI Y CONSISTENCIA (vistos en las capturas)

| # | Problema | Dónde | Orden |
|---|---|---|---|
| U1 | "Racha de **1 días**" / "**1 días** mejor racha" — falta singular | `dashboard_screen.dart`, `progreso_resumen_tab.dart` | Pluralización correcta en todos los contadores. |
| U2 | El gráfico de racha de 7 barras tiene **alturas hardcodeadas** (`[10,16,13,22,18,26,32]`) y no tiene etiquetas de día | `_StreakCard` | O se alimenta con datos reales (L-M-M-J-V-S-D con el día entrenado marcado) o se elimina. Un gráfico decorativo que finge datos es peor que ninguno. |
| U3 | Título "Próximo entrenamiento" sobre una tarjeta genérica que dice "Elegí una rutina o entrená libre" | `dashboard_screen.dart` | O muestra el próximo día real de la rutina activa, o cambia el título. |
| U4 | Miniaturas de ejercicio con **fondo blanco puro** sobre tema casi negro | `exercise_thumb.dart`, listas y entrenamiento | Aplicar un tratamiento consistente (fondo del contenedor, `BlendMode`, o recorte) para que no perforen la UI oscura. |
| U5 | Métricas del historial usan **emojis** (⏱🏆💪📊) como iconos | `history_list_screen.dart` → `_Metric(icon: String)` | Reemplazar por `IconData` de Material como en el resto de la app. |
| U6 | Colores semánticos invertidos: dificultad "Intermedio"=**verde** (color reservado a éxito), "Avanzado"=**rojo** (color de error); volumen muscular alto=**rojo** | `exercise_list_screen.dart`, `exercise_detail_screen.dart`, `colorForLevel` en `theme.dart` | Verde solo = éxito; rojo solo = error/peligro. Usar una escala neutra (o el primario en intensidades) para dificultad y volumen. |
| U7 | `muscleGroupColors` es un arcoíris de 10 colores (rosa, violeta, naranja, teal, cian, magenta) que contradice el sistema declarado en `theme.dart` ("azul principal, violeta solo acento, verde solo éxito") | `theme.dart` + bordes de tarjeta en entrenamiento activo | Reducir a una escala derivada del primario, o usar el color solo en un punto pequeño (el dot), nunca como borde de tarjeta. |
| U8 | 3 estilos de tarjeta en una sola pantalla: borde izquierdo de 4px, tarjeta con glow, tarjeta plana | `progreso_resumen_tab.dart`, `dashboard_screen.dart` | Un único estilo base + una variante destacada. |
| U9 | 2 estilos de encabezado de sección: círculo+ícono con texto blanco (Dashboard) vs. ícono+texto **azul** (Perfil, Ajustes) | `dashboard_screen.dart` vs `profile_screen.dart`/`settings_screen.dart` | Unificar. |
| U10 | Label truncado "Proteína (..." — 3 inputs en un `Row` no caben a 430px | `nutrition_screen.dart` | 2 por fila, o etiqueta arriba del campo. |
| U11 | Todos los formularios usan **placeholder como etiqueta**: al escribir se pierde el significado del campo | Perfil, Nutrición, Recuperación, Constructor de rutinas | Usar `labelText` (flotante) en vez de `hintText`. |
| U12 | El FAB tapa el último elemento de todas las listas | Ejercicios, Historial, Rutinas | Padding inferior ≥ 96px en cada lista con FAB. |
| U13 | Tabs y chips scrollables cortan el último elemento sin indicio de scroll | Todos los hubs, filtro de Historial | Gradiente de desvanecido en el borde, o repartir para que quepan. |
| U14 | Estados vacíos = una línea de texto gris, sin ilustración ni acción | 10 pantallas ("Sin objetivos todavía.", "Sin registros todavía.", …) | Componente único de estado vacío: ícono + frase + botón de acción primaria. |
| U15 | Pantallas **sin estado de error**: una excepción deja spinner infinito | Medidas, Nutrición, Recuperación, Logros, Detalle de sesión, todas las pestañas de Stats | Componente único de error con reintento. |
| U16 | Errores mostrados con `e.toString()` crudo al usuario | `dashboard_screen.dart`, `exercise_detail_screen.dart`, y otros | Mensajes traducidos, como ya hace `AuthFailure`. |
| U17 | RPE muestra `0.0` como valor válido | `active_workout_screen.dart` | Mostrar "–" cuando es nulo; 0 no es un RPE. |
| U18 | Etiqueta de la barra inferior dice "Cuenta", la pantalla se titula "Perfil" | `home_shell.dart` / `profile_screen.dart` | Unificar nombre. |
| U19 | Borrar objetivo y borrar serie (swipe) no piden confirmación ni ofrecen deshacer | `goals_screen.dart`, `active_workout_screen.dart` (`Dismissible`) | SnackBar con "Deshacer". |

---

# PARTE 5 — PROBLEMAS TÉCNICOS

| # | Problema | Archivo | Orden |
|---|---|---|---|
| T1 | `WorkoutRepository.get()` hace **N+1**: `_toWorkoutSet` consulta la tabla `exercises` una vez **por serie** | `workout_repository.dart` | Cargar el catálogo una vez y resolver en memoria (como ya hace `history()`). |
| T2 | En el entrenamiento activo, **cada** toque de stepper hace `updateSet` + `_load()` completo (recarga la sesión entera con el N+1 de T1) | `active_workout_screen.dart` | Actualizar el estado en memoria y debouncear la escritura; no recargar toda la sesión. |
| T3 | `WorkoutSummaryScreen._loadComparisons` llama `history(muscleGroup:)` **una vez por grupo muscular** (cada llamada lee todas las sesiones + todas las series + todo el catálogo) y luego un `get()` con N+1 por grupo | `workout_summary_screen.dart` | Una sola query de comparación. |
| T4 | `set_number` se calcula como `sets.length + 1` → números duplicados tras borrar una serie intermedia | `active_workout_screen.dart` → `_addSetFor` | Usar `max(setNumber)+1` o renumerar. |
| T5 | Las sesiones **sin terminar** cuentan en estadísticas: `muscleAnalysis` no filtra `endedAt != null`, y las series placeholder en 0/0 inflan el conteo de series (visible en `06-progreso-estadisticas.png`: 10 series con 0 kg de aporte) | `stats_repository.dart` | Filtrar sesiones abiertas y series en 0 en todos los cálculos. |
| T6 | Sesión activa sin caducidad: una sesión abierta 16 h sigue "en curso" con el cronómetro corriendo y contaminando stats | `active_workout_repository.dart` | Detectar sesiones abandonadas (p. ej. > 6 h sin actividad) y ofrecer cerrarla o descartarla al abrir la app. |
| T7 | `showSetFormSheet` crea 6 `TextEditingController` que **nunca se liberan** (viola AG-CORE-009) | `set_form_sheet.dart` | Convertir a `StatefulWidget` con `dispose()`. |
| T8 | `setState` tras `await` sin chequear `mounted` | `dashboard_screen.dart` (`_load`), `history_list_screen.dart` (`_load`), `goals_screen.dart` (`_load`), `exercise_picker_screen.dart` (`initState`) | Agregar guardas `if (!mounted) return;`. |
| T9 | `initState` con cadena `.then().then().catchError()` y `setState` sin `mounted` | `exercise_detail_screen.dart` | Reescribir como `async` con guardas. |
| T10 | `FutureBuilder` con el future creado dentro de `build()` → se recrea en cada rebuild | `exercise_thumb.dart` | Cachear el future en el `State`. |
| T11 | Accesibilidad prácticamente ausente: **2** usos de `Semantics` en 150 archivos; iconos sin `semanticLabel`; contraste de `onSurfaceVariant` (#94A3B8) sobre `surfaceContainer` no verificado | Todo `lib/` | Etiquetar iconos accionables, verificar contraste AA, targets ≥ 48px. |
| T12 | Responsive inexistente: **1** archivo usa `LayoutBuilder`/`MediaQuery.size` | Todo `lib/` | Verificar al menos 360px de ancho y tablet; U10 es un síntoma. |
| T13 | Preferencia de unidad kg/lb solo respetada en 3 pantallas de entrenamiento; Historial, Estadísticas, Medidas, Perfil, Calculadoras y Progreso hardcodean "kg" | `core/units.dart` se importa solo en 3 archivos | Aplicar `formatWeight` en toda la UI, o quitar el selector hasta que esté completo. |
| T14 | Sin paginación: `history()` carga **todas** las sesiones y **todas** sus series en memoria (crítico tras importar historial de Hevy) | `workout_repository.dart`, `history_list_screen.dart` | Paginar. |
| T15 | 77 paquetes desactualizados; `flutter_3d_controller` arrastra `flutter_inappwebview` (que rompe el build de Windows) para una función sin ningún asset | `pubspec.yaml` | Ver F3: si se elimina el visor 3D, se elimina esta dependencia entera. |

---

# PARTE 6 — FUNCIONALIDADES VACÍAS O AUSENTES

## F1 — El catálogo tiene solo 25 ejercicios y no se pueden crear ejercicios
`assets/data/exercises.json`: **25** ejercicios. La única forma de crear un ejercicio propio es el flujo de importación CSV/Excel (`import_preview_screen.dart` → "Crear ejercicio nuevo en mi catalogo"). No hay ninguna acción de "crear ejercicio" en la UI.
**ORDEN:** alta prioridad. Agregar creación de ejercicio propio (nombre, grupo muscular, equipo). Sin esto la app no sirve para un gimnasio real.

## F2 — El Coach IA ("Gemelo Digital") siempre dice "Próximamente"
`SmartBackendAvailability.isConfigured` depende de `--dart-define=SMART_BACKEND_URL`, que **no está en `.github/workflows/release.yml`** (solo están `SUPABASE_URL` y `SUPABASE_ANON_KEY`). Es la tarjeta más destacada del Dashboard (gradiente, glow, glassmorfismo) y en todo build publicado abre `ComingSoonView`.
**ORDEN:** o se configura el backend en CI, o se quita la tarjeta del Dashboard hasta que exista. No dejar la función más prominente rota.

## F3 — El visor 3D no tiene ni un modelo
`assets/models_3d/` contiene **solo un README**. El botón "Ver en 3D" está en el detalle de **todos** los ejercicios y siempre cae al placeholder "falta el archivo".
`assets/images/exercises/` también está vacío (solo README). Solo **16 de 25** ejercicios tienen animación GIF.
**ORDEN:** quitar el botón "Ver en 3D" (y con él `flutter_3d_controller` + `flutter_inappwebview`, ver T15) o poblar los modelos. Igual que con F2: no mostrar una función que nunca funciona.

## F4 — Ausencias frente a apps modernas (grep = 0 resultados)
Sin implementar en ningún lado: **favoritos** de ejercicio, **superseries** en la UI (la columna `supersetGroupId` existe en la base y solo la usa el importador), **historial por ejercicio**, **fotos de progreso**, **recordatorios/notificaciones**, **plantillas de rutina**, **calculadora de discos**, **sustituir ejercicio**, **reordenar ejercicios**, **notas de sesión**.

Priorización:
- 🔴 **Alta:** historial + PR por ejercicio dentro del detalle del ejercicio (F5); prefill "última vez" (C6); crear ejercicio propio (F1); superseries en la UI.
- 🟠 **Media:** favoritos y recientes en el picker; plantillas de rutina; sustituir/reordenar ejercicios; notas de sesión; recordatorios.
- 🟢 **Baja:** fotos de progreso; calculadora de discos.
- ⚪ **No recomendable ahora:** más pantallas nuevas de cualquier tipo. La app ya tiene 22 pantallas y el problema es profundidad, no superficie.

## F5 — El detalle de ejercicio es una enciclopedia sin datos del usuario
`exercise_detail_screen.dart` muestra animación, músculos, equipo, instrucciones, consejos, errores, variantes, beneficios — y **cero** datos personales: no hay historial de ese ejercicio, ni su PR, ni "última vez", ni botón para empezar a entrenarlo o agregarlo a una rutina.
**ORDEN:** es la fusión de mayor impacto (ver Parte 7, U-F1).

## F6 — Nutrición es un formulario de 5 números
5 campos (calorías, agua, proteína, carbos, grasas) + historial en lista. Sin base de alimentos, sin comidas, sin objetivos. La "Calculadora de nutrición" que sí calcula objetivos vive en otra pestaña (Cuerpo → Herramientas) y no está conectada.
**ORDEN:** conectar la calculadora con el registro (objetivo vs. consumido con anillos de progreso) o reducir el alcance a "registro rápido de macros" y dejar de presentarlo como una sección de primer nivel.

---

# PARTE 7 — FUSIONES Y ELIMINACIONES

## Fusiones recomendadas (SÍ)
| Fusión | Motivo | Cómo queda |
|---|---|---|
| **U-F1: Ejercicio + su historial + su PR** | El usuario abre un ejercicio para saber "qué levanté la última vez", y hoy solo ve la enciclopedia | `ExerciseDetailScreen` con 2 secciones: "Tu progreso" (PR, última sesión, gráfico de peso máximo, lista de sesiones) arriba, y la ficha técnica abajo. Botón primario "Empezar con este ejercicio". |
| **U-F2: Nutrición + Calculadora de nutrición** | La calculadora produce exactamente los objetivos que al registro le faltan | Una pestaña "Nutrición" con objetivo calculado arriba y registro diario contra ese objetivo. |
| **U-F3: Medidas + peso/altura del Perfil** | El peso corporal se edita en Perfil y se grafica en Medidas: dos fuentes de verdad para el mismo dato | Perfil deja de tener campo de peso; enlaza a Medidas. Medidas es la única entrada de peso corporal. |
| **U-F4: Estadísticas (5 sub-pestañas) → una vista por secciones** | Ver N1: elimina el `TabBar` anidado | Scroll único con secciones y anclas. |
| **U-F5: Progreso→Resumen + Logros** | Resumen está casi vacío (nivel/XP + deload + 1 objetivo) y Logros es solo nivel/XP/medallas | Un "Resumen" real: nivel/XP, racha, volumen semanal con tendencia, PRs recientes, objetivos, medallas. Se elimina la pestaña Logros. |

## Fusiones NO recomendadas
- **Historial + Estadísticas:** NO. Historial es "qué hice" (registro, se consulta puntualmente); Estadísticas es "cómo voy" (agregado). Frecuencias de uso y modelos mentales distintos.
- **Rutinas + Entrenamiento en una pantalla:** NO. Lo que falta no es fusionar pantallas, es que la rutina **alimente** el entrenamiento (C4). Fusionarlas mete la edición de plantillas en el medio del gimnasio.

## Eliminaciones propuestas
| Qué | Por qué |
|---|---|
| Botón "Ver en 3D" + `flutter_3d_controller` + `flutter_inappwebview` | 0 assets, nunca funcionó, y rompe el build de Windows (F3, T15). |
| Tarjeta "Gemelo Digital" del Dashboard | Siempre "Próximamente" en builds publicados (F2). Reactivar cuando el backend esté en CI. |
| Pestaña "Logros" | Su contenido cabe en Resumen (U-F5). |
| Gráfico de barras de la racha | Datos falsos hardcodeados (U2). |
| Tiles duplicadas del Dashboard | Duplican la barra inferior (N2). |
| `lib/widgets/coming_soon_view.dart` — revisar | Solo se usa en el chat del coach; si se aplica F2, evaluar si sigue haciendo falta. |
| `lib/main_audit.dart` | Archivo temporal de esta auditoría. Borrar al terminar. |
| `kShowPoseAnalysisEntryPoints = false` + `pose_analysis_screen.dart` (347 líneas) + `camera` + `google_mlkit_pose_detection` | Función completa, oculta por flag y sin fecha. Decidir: activarla o eliminarla con sus dependencias. Mantener 347 líneas + 2 plugins nativos inaccesibles tiene costo real. |

---

# PARTE 8 — ROADMAP (ejecutar EN ESTE ORDEN, una fase a la vez)

Regla para cada fase: explicar el cambio → implementar → correr `flutter analyze` y `flutter test` → correr la app con `lib/main_audit.dart` → capturar → comparar antes/después → buscar regresiones → corregir → recién entonces pasar a la siguiente.

### FASE 1 — Integridad de datos (bloqueante, no negociable)
1. C1 — merge del payload en `updateSet` + test de regresión.
2. C2 — no evaluar récords en 0/0, evaluar en `updateSet`, `rebuildPersonalRecords()` de reparación, tests.
3. T5 — excluir sesiones abiertas y series en 0 de todas las estadísticas.
4. T4 — `set_number` correcto tras borrar.
5. T7 — liberar los `TextEditingController` de `set_form_sheet`.
6. C3 — decidir (a) implementar `pull` o (b) corregir el copy de Ajustes. **Documentar la decisión en un ADR.**

### FASE 2 — El bucle de entrenamiento
1. C5 — check de "serie completada" por fila que arranque el descanso.
2. C6 — prefill con la última vez + "Última vez: X kg × Y" en cada fila + edición inline.
3. C4 — precargar los ejercicios y objetivos de la rutina al iniciar con rutina.
4. N4 — minimizar el entrenamiento + confirmación al finalizar.
5. N3 — banner de "entrenamiento en curso".
6. T2, T1, T3 — quitar la recarga completa por toque, el N+1 y las queries del resumen.

### FASE 3 — Navegación
1. N1 — eliminar el `TabBar` anidado (U-F4).
2. N2 — rediseñar el Dashboard (quitar las tiles duplicadas).
3. N5 — un solo contrato `embedded`.
4. U-F5 — fusionar Resumen + Logros.
5. U18 — unificar "Cuenta"/"Perfil".

### FASE 4 — Progreso y datos del usuario
1. U-F1 — historial + PR por ejercicio en el detalle del ejercicio.
2. F1 — crear ejercicio propio.
3. T13 — aplicar kg/lb en toda la UI (o quitar el selector).
4. U-F3 — una sola fuente de verdad para el peso corporal.
5. T14 — paginar el historial.

### FASE 5 — Sistema de diseño
1. Documentar el sistema real en `docs/` (tarjeta base + variante destacada, un encabezado de sección, un estado vacío, un estado de error, un estado de carga).
2. U6, U7 — corregir la semántica de color.
3. U8, U9 — unificar tarjetas y encabezados.
4. U14, U15, U16 — componentes únicos de vacío/error/carga y mensajes traducidos.
5. U1, U2, U3, U4, U5, U10, U11, U12, U13, U17, U19.
6. T11, T12 — accesibilidad y responsive.

### FASE 6 — Limpieza y funciones avanzadas
1. Ejecutar las eliminaciones de la Parte 7 (3D, coach, pose).
2. Superseries en la UI.
3. Favoritos y recientes en el picker.
4. U-F2 — Nutrición + calculadora.
5. Plantillas de rutina; sustituir/reordenar ejercicios.
6. T15 — actualizar dependencias.

---

# PARTE 9 — PRIORIZACIÓN (impacto × esfuerzo)

| Mejora | Impacto | Esfuerzo | Prioridad |
|---|---:|---:|---|
| C1 Payload de sync corrupto | 5 | 1 | 🔴 Máxima |
| C2 Récords en 0 | 5 | 2 | 🔴 Máxima |
| C5 Check de serie + descanso | 5 | 2 | 🔴 Máxima |
| C6 Prefill "última vez" | 5 | 2 | 🔴 Máxima |
| T5 Stats contaminadas | 4 | 1 | 🔴 Alta |
| C4 Rutina → entrenamiento | 5 | 3 | 🔴 Alta |
| N2 Rediseño del Dashboard | 4 | 2 | 🔴 Alta |
| N1 Quitar TabBar anidado | 4 | 3 | 🔴 Alta |
| C3 Sync de bajada (o copy) | 5 | 4 | 🔴 Alta |
| U-F1 Historial por ejercicio | 5 | 3 | 🔴 Alta |
| F1 Crear ejercicio propio | 4 | 2 | 🔴 Alta |
| T1/T2/T3 Rendimiento | 3 | 2 | 🟠 Media |
| N4/N3 Salir y reanudar | 4 | 2 | 🟠 Media |
| T13 kg/lb en toda la UI | 3 | 2 | 🟠 Media |
| N5 Contrato `embedded` | 3 | 3 | 🟠 Media |
| U14/U15 Vacío y error únicos | 3 | 2 | 🟠 Media |
| F3/F2 Quitar 3D y coach roto | 3 | 1 | 🟠 Media |
| Sistema de diseño documentado | 3 | 3 | 🟠 Media |
| T11 Accesibilidad | 3 | 4 | 🟠 Media |
| Superseries en la UI | 3 | 3 | 🟢 Baja |
| U-F2 Nutrición + calculadora | 2 | 3 | 🟢 Baja |
| Favoritos y recientes | 2 | 2 | 🟢 Baja |
| Fotos de progreso | 2 | 4 | 🟢 Baja |
| Más pantallas nuevas | 1 | 5 | ⚪ No |

---

# RESTRICCIONES DE TRABAJO
- No romper los 124 tests existentes; agregar tests para cada bug de la Fase 1.
- `flutter analyze` debe quedar en 0 errores y 0 warnings.
- Respetar la arquitectura actual: las pantallas hablan con repositorios, nunca con Drift directo (excepto `exercise_picker_screen.dart`, que hoy lo viola y conviene corregir).
- Todo lo que se guarda sigue en **kg**; las unidades son solo presentación (`core/units.dart`).
- Máximo 3 archivos por cambio salvo que la fase lo exija explícitamente (AG-CORE-011/012).
- No agregar funcionalidades que no estén en este documento.
- **No commitear** `lib/main_audit.dart`.
