# AUDITORÍA NEXFIT — 2026-09-04

Ámbito: técnica + funcional + visual + arquitectura + Supabase + assets + licencias.
Rama `master`, versión `1.1.4+7`, 154 archivos Dart / 42.684 líneas en `lib/`.

Esta auditoría **continúa** `docs/AUDITORIA_2026-09-03.md` (no la repite): las órdenes
C1–C6, N1–N5, T1–T4, T7, U-F1 y las Fases 1–3 de aquel documento **ya están
implementadas y verificadas en el código actual**. Acá se registra (a) lo que quedó
pendiente y sigue vivo, (b) hallazgos nuevos que aquella auditoría no cubrió
(Supabase real, licencia de los GIFs, ciclo de vida del entrenamiento activo,
arquitectura del catálogo), y (c) el plan ejecutable.

---

## 0. Evidencia de cómo se hizo

| Comprobación | Resultado |
|---|---|
| `flutter analyze --no-pub` | **11 infos, 0 warnings, 0 errores** |
| `flutter test --no-pub` | **196 tests, todos en verde** (`All tests passed!`) |
| Supabase — proyectos | `appgym` (`btrdczpnuutrvgoprqze`, creado 2026-09-04) y `Admin Panel y Negocio` (`rjahodesvndawnxghugp`) |
| Supabase — filas reales | **11 tablas `nexfit_*`, TODAS con 0 filas.** 1 usuario en `auth.users` |
| Supabase — Storage | **0 buckets, 0 objetos** |
| Supabase — advisors seguridad | 3 lints (2 × SECURITY DEFINER expuesto a `anon`, 1 × leaked-password protection off) |
| Supabase — advisors rendimiento | 16 × `auth_rls_initplan`, 1 × FK sin índice, 11 × índice sin uso |
| Assets — GIFs | 16 archivos, **todos 180×180**, 1,5 MB total. `assets/images/exercises/` y `assets/models_3d/` **vacíos** (solo README) |
| Catálogo | `assets/data/exercises.json` = **40 ejercicios**, `image_url` nulo en los 40 |
| Secretos | `env.json` **nunca estuvo en el historial de git** (`git log --all -- env.json` vacío). `backend_ia/.env` tampoco. Correcto. |
| Dataset origen | https://github.com/hasaneyldrm/exercises-dataset — 1.324 ejercicios, datos MIT, **media © Gym visual** |

---

## 1. Mapa de la aplicación (cómo funciona hoy)

**Stack:** Flutter 3.12 / Dart, `provider` para estado, **Drift/SQLite como fuente de
verdad** (offline-first, ADR-002), Supabase solo como destino de *subida*
(`supabase_flutter`), backend propio opcional `backend_ia` (FastAPI) para el Coach.

**Arranque** (`lib/main.dart`): `Supabase.initialize` → si falla cae a
`UnavailableAuthRepository` y la app arranca igual sin auth. Se instancian 14
repositorios + `SyncEngine`, se dispara `syncExerciseCatalog` (fire-and-forget) y
`_repairZeroPersonalRecordsOnce`. `AuthProvider.status` decide splash / login / shell.

**Shell** (`home_shell.dart`): `IndexedStack` de 5 destinos —
Inicio · Entrenar · Progreso · Cuerpo · Cuenta — más un banner global de
"entrenamiento en curso" (`Positioned(bottom: 0)`).

| Hub | Pestañas |
|---|---|
| Entrenar | Ejercicios · Rutinas · Historial (+ FAB "Empezar entrenamiento") |
| Progreso | Resumen · Estadísticas (5 secciones por chips) · Objetivos · Logros · Retos |
| Cuerpo | Nutrición · Recuperación · Medidas · Wearables · Herramientas |

**Bucle central:** `EntrenarHub → StartWorkoutScreen → ActiveWorkoutRepository.begin()`
(crea `WorkoutSessions` + fila única `ActiveWorkoutDrafts` id=1) `→ ActiveWorkoutScreen`
(steppers con debounce de 500 ms, check por serie que arranca `RestTimerBanner`,
`_addExercise` vía `ExercisePickerScreen`) `→ finish()` (borra el draft, `finishSession`
reconstruye PRs) `→ WorkoutSummaryScreen`.

**Sync:** `SyncEngine` recorre 6 `SyncableEntity` y llama **solo `push`**. Se dispara al
recuperar conectividad, cada N horas y al arrancar.

---

## 2. HALLAZGOS CRÍTICOS NUEVOS

### A1 — CRITICAL · El entrenamiento activo no caduca nunca y bloquea el flujo de inicio
**Archivos:** `lib/repositories/active_workout_repository.dart`,
`lib/screens/workout/start_workout_screen.dart:36-46`,
`lib/screens/home/home_shell.dart:88-96`.

`ActiveWorkoutDrafts` es una fila única que **solo** se borra en
`ActiveWorkoutRepository.finish()`. Cualquier salida que no sea "Finalizar" —
minimizar (`_minimize`, `home_shell` la ofrece explícitamente), matar la app,
un crash — deja el draft vivo **para siempre**. Consecuencias encadenadas, todas
reproducibles:

1. El banner "Entrenamiento en curso" aparece en **todas** las sesiones futuras.
2. `StartWorkoutScreen._init()` hace `pushReplacement` a `ActiveWorkoutScreen`
   apenas ve `currentSessionId() != null`: **es imposible empezar un entrenamiento
   nuevo** sin finalizar el viejo, y la pantalla ni siquiera lo explica.
3. `ActiveWorkoutRepository.begin()` lanza `StateError` en ese caso — y
   `_start()` **no lo captura**: excepción sin manejar en el `onTap` del FAB.
4. Esas sesiones abiertas contaminan estadísticas (T6 de la auditoría anterior,
   nunca implementado).

Es exactamente el síntoma reportado por el usuario: *"siempre que entro parece que hay
un entrenamiento en curso"*.

### A2 — CRITICAL · El banner global tapa el FAB "Empezar entrenamiento"
**Archivo:** `lib/screens/home/home_shell.dart:88-96` vs `entrenar_hub_screen.dart:56`.

El banner es un `Positioned(left:0, right:0, bottom:0)` dibujado **después** del
`IndexedStack` en el mismo `Stack`, y `EntrenarHubScreen` es un `Scaffold` **sin**
`bottomNavigationBar`, así que su `FloatingActionButton.extended` queda a 16 px del
borde inferior — dentro del área del banner. El banner gana el hit-test: con un
entrenamiento activo pendiente, **el botón de empezar entrenamiento no responde**.
Nadie compensa con `padding`/`viewInsets`. Segunda mitad del síntoma reportado:
*"no me deja agregar un ejercicio"*.

### A3 — HIGH · El draft puede apuntar a una sesión inexistente → spinner infinito
`ActiveWorkoutDrafts.sessionId` es un `integer()` **sin FK ni cascade** contra
`WorkoutSessions`. Si esa sesión desaparece (`WorkoutSessionSyncable._pushDelete`
borra la fila local; un import puede reemplazar datos), `WorkoutRepository.get()`
hace `.getSingle()` → `StateError`. `_load()` no tiene `try/catch`, así que `_session`
queda `null` y `ActiveWorkoutScreen.build` devuelve `CircularProgressIndicator` **para
siempre**, sin salida salvo el botón de minimizar.

### A4 — HIGH · Riesgo legal: se redistribuyen GIFs de Gym visual sin licencia propia ni atribución completa
Verificado en el origen (https://github.com/hasaneyldrm/exercises-dataset):
los **datos** son MIT, pero la **media** es *© Gym visual*, incluida ahí con permiso del
titular y con esta condición textual del README:

> "Keep the `© Gym visual — https://gymvisual.com/` attribution intact. Reuse is
> governed by Gym visual's Terms & Conditions; **obtain your own license there**"

Estado real de la app:
- Los 16 GIFs están **bundleados en el APK** que publica `.github/workflows/release.yml`
  en GitHub Releases → eso es redistribución.
- La resolución **sí** cumple (180×180 verificado en los 16 archivos).
- La atribución **solo** se muestra en `ExerciseDetailScreen` (línea 895) y en
  `ExerciseAnimationViewer`. **`ExerciseThumb` no la muestra nunca** — y es el widget
  que renderiza esos GIFs en la lista de ejercicios, el picker y el entrenamiento
  activo. Verificado por `grep -rn "attribution" lib`: `exercise_thumb.dart` no aparece.
- No hay licencia propia de Gym visual contratada.

### A5 — HIGH · Supabase está vacío: el "backup en la nube" nunca escribió una fila
Las 11 tablas `nexfit_*` del proyecto `appgym` tienen **0 filas** con 1 usuario
registrado. El esquema recién se versionó ayer (`supabase/migrations/20260904_0001`),
que además documenta que en el proyecto anterior *todos* los inserts fallaban con
PGRST204 por la columna `completed` faltante. Aunque ese bug está corregido, hoy no
existe **ninguna evidencia de un push exitoso**. Además el esquema remoto está
**desincronizado** con el local:

| Local (Drift) | Remoto (`nexfit_*`) |
|---|---|
| `WorkoutSessions.title`, `routineDayId` | **no existen** → se pierden en cada push |
| `WorkoutSets.exerciseNotes`, `exerciseOrder` | **no existen** |
| `RoutineExercises.targetWeightKg`, `setType`, `tempo`, `targetRpe`, `targetRir` | **no existen** |
| `PersonalRecords`, `BodyMeasurements` | **sin tabla remota** |
| `exerciseId` int (id del catálogo local) | `exercise_id text` — se manda un int a una columna text |

### A6 — MEDIUM · `SyncableEntity` sigue sin `pull` (ADR-005, decisión (b))
Consciente y documentado, pero la consecuencia sigue viva: reinstalar la app o cambiar
de teléfono **pierde todo**, y `ProfileScreen` arranca vacío en un dispositivo nuevo.
Con Supabase ya poblándose, esto pasa de "deuda aceptada" a "el backup no sirve para
nada": se sube información que jamás se puede bajar.

---

## 3. AUDITORÍA DE SUPABASE

### 3.1 Seguridad (advisors reales)

| Lint | Nivel | Detalle |
|---|---|---|
| `anon_security_definer_function_executable` | WARN | `nexfit_challenge_leaderboard` y `nexfit_join_challenge_by_code` son `SECURITY DEFINER` y **ejecutables por el rol `anon`** vía `/rest/v1/rpc/...`. Un anónimo puede llamar al leaderboard de cualquier reto con solo adivinar su UUID; `join_challenge_by_code` es un oráculo de códigos de invitación sin rate limit. |
| `authenticated_security_definer_function_executable` | WARN | mismas dos funciones para `authenticated` — ahí sí es intencional (lo documenta la migración), pero falta acotar. |
| `auth_leaked_password_protection` | WARN | protección contra contraseñas filtradas (HaveIBeenPwned) **desactivada**. |

RLS: **habilitado en las 11 tablas**, políticas correctas (cada usuario solo lo suyo;
tablas hijas resuelven por jerarquía). No se encontró ninguna tabla sin RLS ni ninguna
política permisiva. Eso está bien hecho.

### 3.2 Rendimiento (advisors reales)

- **16 × `auth_rls_initplan`**: todas las políticas usan `auth.uid()` sin envolver en
  `(select auth.uid())` → se re-evalúa **por fila**. Con historial importado de Hevy
  (miles de series) esto multiplica el coste de cada `select`.
- **1 × FK sin índice**: `nexfit_workout_sessions.routine_id`.
- **11 × índice sin uso**: consecuencia directa de A5 (0 filas, 0 queries). No borrar.

### 3.3 Coste en el plan Free

Situación real: **0 bytes de datos, 0 bytes de Storage**. El plan Free da 500 MB de DB,
1 GB de Storage y 5 GB de egress/mes. Proyección con la arquitectura actual
(offline-first, push-only, un solo usuario activo):

| Concepto | Estimación | Riesgo |
|---|---|---|
| 1 año de entrenamiento (4 sesiones/sem, 20 series) ≈ 4.200 filas de sets | < 2 MB | Nulo |
| Egress por sync | despreciable (solo push de deltas) | Nulo |
| Storage si se suben GIFs del dataset (1.324 × ~90 KB) | **~120 MB** + egress por descarga | **Alto** — ver §4 |

**Conclusión:** la base de datos no es el problema. El único riesgo real de coste es
mover la media a Storage. La arquitectura offline-first ya protege el plan Free casi
por completo; el error sería romperla subiendo assets.

---

## 4. IMÁGENES Y GIFs — origen, licencia y arquitectura

### 4.1 Qué hay hoy (verificado)

| Pregunta | Respuesta verificada |
|---|---|
| ¿Dónde están definidos? | `assets/data/gymvisual_animations.json` (mapa `slug → gif_path`), declarado en `pubspec.yaml` |
| ¿Dónde se almacenan? | **Dentro del repositorio y del APK**: `assets/animations/gymvisual/*.gif`. No hay CDN, ni URL externa, ni Supabase Storage |
| ¿Cuántos hay? | **16** GIFs para **40** ejercicios del catálogo → 24 ejercicios sin animación (60 %) |
| Formato / tamaño | GIF, 180×180 los 16, 61–128 KB c/u, **1,5 MB total** |
| ¿Quién los resuelve? | `AnimationRepository` → `CustomAnimationProvider` (prio 0, carpeta vacía) → `GymVisualProvider` (prio 10) → `ExerciseAnimation.placeholder` |
| ¿Quién los renderiza? | `ExerciseThumb` (listas, picker, entrenamiento) y `ExerciseAnimationViewer` (detalle) |
| Duplicados / rotos | Ninguno duplicado; ninguno roto. 2 mapeos son **aproximaciones** documentadas: `jalon-al-pecho` → "cable lat pulldown", `hip-thrust` → "barbell glute bridge" |
| `image_url` del catálogo | **null en los 40 ejercicios** — la columna existe en Drift y en el JSON, no se usa |
| `assets/images/exercises/` | **vacía** (solo README) |
| `assets/models_3d/` | **vacía** (solo README) — el visor 3D nunca tuvo un modelo |

### 4.2 Dos problemas de rendimiento reales en la carga

1. **`ExerciseThumb` crea el `Future` dentro de `build()`**
   (`lib/widgets/exercise_thumb.dart:53`): `FutureBuilder(future: context.read<AnimationRepository>().getAnimation(slug))`.
   Cada rebuild —cada `setState` del entrenamiento activo, cada tecla en el buscador
   del picker— vuelve a resolver la animación de **todas** las filas visibles. Es la
   orden T10 de la auditoría anterior, **nunca implementada**.
2. **`CustomAnimationProvider` hace 5 `rootBundle.load()` fallidos por consulta**
   (`_extensionsByType`: mp4, webm, gif, json, webp) porque su carpeta está vacía. Al
   ser el proveedor de prioridad 0, **toda** resolución paga esas 5 excepciones antes
   de llegar a GymVisual. Multiplicado por el punto 1, son cientos de cargas fallidas
   por segundo en una lista con scroll.

### 4.3 Problema visual

Los GIFs de Gym visual tienen **fondo blanco puro**. Sobre `AppColors.background`
(#0B0D12) las miniaturas perforan la UI oscura — visible en
`docs/auditoria/baseline/18-entrenamiento-activo.png`. Es la orden U4, no implementada.

### 4.4 Alternativas comparadas (investigación externa)

| Dataset | Ejercicios | Media | Licencia media | ¿Uso comercial libre? |
|---|---|---|---|---|
| **hasaneyldrm/exercises-dataset** (actual) | 1.324 | GIF animado + thumb 180×180 | **© Gym visual**, permiso al repo, no transferible | **NO** — hay que licenciar aparte |
| **yuhonas/free-exercise-db** | 800+ | 2 JPG por ejercicio (inicio/fin), servidas por raw.githubusercontent o CDN | **Unlicense (dominio público)** | **SÍ**, sin atribución ni restricción |
| **wger-project/wger** | 845+ | imágenes con licencia por ítem | **AGPL-3.0** (copyleft) | Contaminante para una app propietaria |

### 4.5 Arquitectura recomendada para los assets

**No subir nada a Supabase Storage.** Razones: (a) 1.324 GIFs ≈ 120 MB de los 1 GB del
plan Free y consumo de egress por cada visualización; (b) la app es offline-first y un
asset remoto rompe esa promesa justo en el gimnasio, donde no hay señal.

Arquitectura objetivo, en tres capas por orden de prioridad (el
`AnimationRepository` ya soporta exactamente esto sin cambios estructurales):

1. **Bundle** — un subconjunto curado de ~60–80 ejercicios (los de mayor uso real)
   como **WebP animado** (`AnimationType.image`, ya contemplado en el enum). WebP pesa
   ~30–50 % menos que el mismo GIF a igual calidad. Presupuesto: **≤ 4 MB de APK**.
2. **Descarga bajo demanda + caché en disco** — un `HttpAnimationProvider` nuevo
   (prioridad 20) que baje desde el CDN público del dataset elegido y guarde en
   `path_provider` (ya es dependencia). Cache-first, sin red = se salta.
3. **Placeholder** — el actual, por grupo muscular. Ya existe y funciona.

El *manifest* (`slug → ruta o URL`) se queda como asset estático versionado con el
código: **no** en Supabase. Es dato inmutable, idéntico para todos los usuarios; ponerlo
en una tabla es pagar lecturas por algo que nunca cambia.

**Decisión sobre licencia (requiere el sí del dueño del producto):**
- Opción A (recomendada): **migrar a `free-exercise-db` (Unlicense)** y borrar
  `GymVisualProvider` + los 16 GIFs. Coste: se pierde la animación (pasa a 2 imágenes
  estáticas por ejercicio), se gana seguridad legal total y 800+ ejercicios.
- Opción B: **contratar la licencia de Gym visual** y, mientras tanto, añadir la
  atribución en `ExerciseThumb`.
- Opción C (mínimo aceptable hoy): mantener los 16 GIFs, **añadir ya la atribución en
  `ExerciseThumb`** y **no ampliar** el set hasta resolver A o B.

---

## 5. CATÁLOGO DE EJERCICIOS

Hoy: 40 ejercicios en `assets/data/exercises.json`, sembrados en la tabla Drift
`Exercises` por `mergeExerciseCatalog` (fusión idempotente por `slug`, versionada por
hash en `SharedPreferences` — **bien resuelto**, no tocar). Los ejercicios propios usan
ids desde 1.000.000 y slug `custom-<id>`, así que quedan fuera del merge por
construcción.

Campos presentes: `id, slug, name, muscle_group, primary_muscles, secondary_muscles,
equipment, difficulty, movement_type, description, instructions, tips,
common_mistakes, variants, benefits`. **Faltan** respecto de lo que pide el producto:
`alternative_names` (búsqueda: "press de banca" vs "bench press"), `gif`/`image`/
`thumbnail` (hoy `image_url` está sin usar y el mapeo vive en otro archivo), `source`,
`license`, `tags`.

**Arquitectura correcta:** el catálogo **es estático y compartido** → JSON en assets +
tabla Drift local. **Nunca** en Supabase: replicarlo ahí serían 800–1.300 filas
idénticas para todos los usuarios pagando lecturas y egress por dato que no cambia. Lo
que sí es del usuario —ejercicios propios, favoritos, notas— sí va a Supabase, y hoy
**ni siquiera eso se sincroniza** (no hay `ExerciseSyncable`; un ejercicio propio
creado con E1 se pierde al reinstalar).

---

## 6. INVENTARIO DE PANTALLAS Y VEREDICTO

| # | Pantalla | Archivo | Veredicto | Motivo |
|---|---|---|---|---|
| 1 | Login / Registro | `screens/auth/` | Mantener | Correcta, con `AuthFailure` traducido |
| 2 | Dashboard | `home/dashboard_screen.dart` | **Mejorar** | U2 (gráfico de racha con alturas fijas `[10,16,13,22,18,26,32]`), U3 ("Próximo entrenamiento" genérico), U1 ("1 días") |
| 3 | Entrenar (hub) | `entrenar/` | **Corregir** | A2: el FAB queda tapado por el banner |
| 4 | Ejercicios | `exercises/exercise_list_screen.dart` | Mejorar | U6 (verde = "Intermedio"), U12 (FAB tapa el último ítem), sin favoritos |
| 5 | Detalle de ejercicio | `exercises/exercise_detail_screen.dart` (1.113 líneas) | **Refactorizar** | Ya tiene U-F1; sigue con "Ver en 3D" apuntando a 0 modelos y es la pantalla más grande del proyecto |
| 6 | Picker de ejercicio | `exercises/exercise_picker_screen.dart` | Mejorar | Sin `mounted` en `initState` (T8), sin favoritos/recientes, sin `ListView.builder` (construye todas las filas) |
| 7 | Iniciar entrenamiento | `workout/start_workout_screen.dart` | **Corregir** | A1: redirige en silencio; `begin()` puede lanzar sin captura |
| 8 | Entrenamiento activo | `workout/active_workout_screen.dart` (1.512 líneas) | **Refactorizar** | A3 (spinner infinito), FAB oculto mientras `_restEndsAt != null`, U17 (RPE 0.0), archivo demasiado grande |
| 9 | Resumen de entrenamiento | `workout/workout_summary_screen.dart` | Mejorar | T3 (una query por grupo muscular) nunca implementado |
| 10 | Rutinas / Constructor | `routines/` | Mantener | Funciona; sin plantillas |
| 11 | Historial | `history/history_list_screen.dart` | Mejorar | U5 (emojis como iconos), T14 (paginación) |
| 12 | Detalle de sesión | `history/session_detail_screen.dart` | Mantener | — |
| 13 | Progreso (hub) + 5 tabs | `progreso/`, `stats/`, `goals/`, `gamification/`, `social/` | **Fusionar** | U-F5 pendiente: "Logros" cabe en "Resumen" |
| 14 | Estadísticas (5 secciones) | `stats/` | Mantener | N1 ya resuelto con chips + `IndexedStack` |
| 15 | Cuerpo (hub) + 5 tabs | `cuerpo/`, `nutrition/`, `recovery/`, `measurements/`, `wearables/`, `calculators/` | **Fusionar** | U-F2 (Nutrición + calculadora) y U-F3 (peso corporal en dos sitios) pendientes |
| 16 | Perfil / Ajustes | `profile/`, `settings/` | Mejorar | U18 ("Cuenta" vs "Perfil"), U11 (placeholder como label) |
| 17 | Coach IA | `coach/coach_chat_screen.dart` | **Corregir o eliminar** | F2 vive: `SMART_BACKEND_URL` **no está** en `release.yml` → en todo APK publicado abre `ComingSoonView` |
| 18 | Análisis de pose | `features/pose/` | **Decidir** | 347 líneas + `camera` + `google_mlkit_pose_detection` inalcanzables tras `kShowPoseAnalysisEntryPoints = false` |
| 19 | Visor 3D | `features/exercise_3d/` | **Eliminar** | 0 modelos; arrastra `flutter_3d_controller` → `flutter_inappwebview` → rompe el build de Windows |
| 20 | Import / Export | `features/import_export/`, `measurements_import/` | Mantener | Bien construido y con tests |

---

## 7. MATRIZ DE PROBLEMAS

| ID | Categoría | Sev. | Ubicación | Descripción | Causa | Impacto |
|---|---|---|---|---|---|---|
| A1 | Funcional | **CRITICAL** | `active_workout_repository.dart`, `start_workout_screen.dart:36` | El entrenamiento activo no caduca y bloquea iniciar otro | El draft solo se borra en `finish()` | No se puede entrenar; stats contaminadas |
| A2 | UX | **CRITICAL** | `home_shell.dart:88`, `entrenar_hub_screen.dart:56` | El banner tapa el FAB "Empezar entrenamiento" | `Positioned(bottom:0)` sobre un Scaffold sin `bottomNavigationBar` | Botón principal inutilizable |
| A3 | Robustez | HIGH | `active_workout_screen.dart:72` | Draft huérfano → spinner infinito | `sessionId` sin FK; `_load()` sin `try/catch` | Pantalla muerta sin salida |
| A4 | Legal | HIGH | `assets/animations/gymvisual/`, `exercise_thumb.dart` | Redistribución de media © Gym visual sin licencia propia ni atribución en las miniaturas | Se clonó el dataset asumiendo que MIT cubría la media | Riesgo legal en un APK público |
| A5 | Datos | HIGH | `supabase/migrations/`, `core/sync/entities/` | Esquema remoto desincronizado; 0 filas escritas | Columnas locales sin equivalente remoto | El "backup" pierde campos y no está probado |
| A6 | Arquitectura | MEDIUM | `core/sync/syncable.dart` | No hay `pull`; sin restauración | ADR-005 opción (b) | Reinstalar = perder todo |
| A7 | Seguridad | MEDIUM | Supabase RPC | 2 funciones `SECURITY DEFINER` ejecutables por `anon` | Falta `revoke execute from anon` | Enumeración de leaderboards / códigos |
| A8 | Seguridad | MEDIUM | Supabase Auth | Leaked-password protection desactivada | Config por defecto | Contraseñas ya filtradas aceptadas |
| A9 | Rendimiento | MEDIUM | Supabase RLS × 16 | `auth.uid()` sin `(select ...)` → re-evaluación por fila | Migración escrita sin el patrón | Coste × N filas |
| A10 | Rendimiento | MEDIUM | `exercise_thumb.dart:53` | `Future` creado en `build()` (T10 pendiente) | — | Resolución repetida en cada rebuild |
| A11 | Rendimiento | MEDIUM | `custom_animation_provider.dart` | 5 `rootBundle.load()` fallidos por consulta, carpeta vacía | Proveedor de prioridad 0 sin assets | Excepciones en bucle durante el scroll |
| A12 | Rendimiento | MEDIUM | `workout_summary_screen.dart` | T3: una query de historial completo **por grupo muscular** | Nunca implementado | Resumen lento al crecer el historial |
| A13 | Rendimiento | MEDIUM | `workout_repository.dart` `history()` | T14: sin paginación en la carga inicial del historial | Nunca implementado | OOM tras importar Hevy |
| A14 | Funcional | MEDIUM | `.github/workflows/release.yml` | F2: falta `SMART_BACKEND_URL` → Coach siempre "Próximamente" | Secret no configurado | La tarjeta más destacada del Dashboard no funciona |
| A15 | Funcional | MEDIUM | `exercise_repository.dart`, `core/sync/` | Los ejercicios propios (E1) **no sincronizan**: no hay `ExerciseSyncable` | — | Se pierden al reinstalar |
| A16 | UI | MEDIUM | `exercise_thumb.dart` | U4: miniaturas con fondo blanco sobre tema casi negro | GIFs con fondo blanco | Perforan la UI |
| A17 | UI | MEDIUM | `dashboard_screen.dart` `_StreakCard` | U2: gráfico de racha con alturas hardcodeadas | Decorativo que finge datos | Engaña al usuario |
| A18 | A11y | HIGH | todo `lib/` | T11: **2** archivos con `Semantics` sobre 154 | Nunca abordado | App inusable con lector de pantalla |
| A19 | Responsive | MEDIUM | todo `lib/` | T12: **3** archivos usan `LayoutBuilder`/`MediaQuery` | Nunca abordado | U10 (labels truncados) es el síntoma |
| A20 | Producto | MEDIUM | `features/exercise_3d/`, `pubspec.yaml` | F3/T15: visor 3D sin modelos arrastrando `flutter_inappwebview` | — | Rompe el build de Windows con MSVC 14.5x |
| A21 | Consistencia | LOW | `active_workout_screen.dart:858` | El FAB "Agregar ejercicio" se **oculta** mientras corre el descanso | Decisión de diseño | Se pierde la acción principal durante 90 s |
| A22 | Datos | LOW | `exercises.json` | `image_url` null en los 40; el mapeo real vive en otro archivo | Dos fuentes para lo mismo | Confusión de modelo |
| A23 | Calidad | LOW | `main_audit.dart` | Archivo temporal de la auditoría anterior, todavía en `lib/` | — | 100+ líneas muertas en el bundle |
| A24 | Deps | LOW | `pubspec.yaml` | 77 paquetes desactualizados | — | Deuda acumulada |
| A25 | Datos | **HIGH** | `lib/core/local/database.dart` | Las **5 acciones de clave foránea declaradas** (`onDelete: KeyAction.cascade` × 4, `setNull` × 1) **no se aplican nunca**: SQLite las ignora salvo que se ejecute `PRAGMA foreign_keys = ON`, y esta base nunca lo activa | El pragma está OFF por defecto en SQLite y Drift no lo fuerza | Borrar una rutina/sesión deja días, ejercicios de rutina, series y `PendingSetOps` huérfanos. Detectado por el test de `discard()` en la Fase 1 |
| A26 | Testabilidad | MEDIUM | `lib/core/app_updater.dart`, `home_shell.dart:33` | `AppUpdater.checkForUpdate` hace una llamada HTTP real con timeout en cada montaje de `HomeShell`, sin costura para desactivarla | — | Cualquier `testWidgets` que monte el shell queda con un `Timer` pendiente y se cuelga. Además el `catch (_) {}` de `checkForUpdate` es un catch vacío (AG-CORE-001) |

---

## 8. MATRIZ DE MEJORAS

| ID | Mejora | Resuelve | Pantalla | Archivos | BD | Supabase | Dificultad | Prio | Depende de |
|---|---|---|---|---|---|---|---|---|---|
| M1 | Caducidad + descarte del entrenamiento activo | A1, A3 | Inicio, Entrenar | `active_workout_repository.dart`, `start_workout_screen.dart`, `home_shell.dart` | — | — | Media | **P0** | — |
| M2 | El banner no tapa contenido | A2 | Shell | `home_shell.dart`, `entrenar_hub_screen.dart` | — | — | Baja | **P0** | — |
| M3 | Atribución en `ExerciseThumb` + decisión de licencia | A4 | Listas, picker, entrenamiento | `exercise_thumb.dart` | — | — | Baja | **P0** | decisión del dueño |
| M4 | Alinear esquema remoto con el local | A5 | — | nueva migración SQL | — | DDL | Media | **P0** | — |
| M5 | Endurecer RPC + RLS de Supabase | A7, A8, A9 | — | nueva migración SQL | — | DDL | Baja | **P0** | — |
| M6 | Cachear el future de la miniatura + quitar el proveedor vacío | A10, A11 | Todas las listas | `exercise_thumb.dart`, `main.dart` | — | — | Baja | **P1** | — |
| M7 | Tratamiento visual de miniaturas | A16 | Listas | `exercise_thumb.dart` | — | — | Baja | **P1** | M6 |
| M8 | Gráfico de racha con datos reales o eliminarlo | A17 | Dashboard | `dashboard_screen.dart` | — | — | Baja | **P1** | — |
| M9 | Eliminar visor 3D + `flutter_3d_controller` | A20 | Detalle | `exercise_detail_screen.dart`, borrar `features/exercise_3d/`, `pubspec.yaml` | — | — | Baja | **P1** | — |
| M10 | `ExerciseSyncable` para ejercicios propios | A15 | — | nuevo archivo + `main.dart` + migración | — | tabla nueva | Media | **P1** | M4 |
| M11 | Una query para el resumen + paginar historial | A12, A13 | Resumen, Historial | `workout_repository.dart`, `workout_summary_screen.dart`, `history_list_screen.dart` | — | — | Media | **P1** | — |
| M12 | Accesibilidad: `Semantics` en controles accionables | A18 | Todas | ~15 archivos | — | — | Alta | **P1** | — |
| M13 | Arquitectura de assets en 3 capas + WebP | §4.5 | Detalle, listas | nuevo `HttpAnimationProvider`, `pubspec.yaml`, manifest | — | — | Alta | **P2** | M3 |
| M14 | Favoritos y recientes en el picker | F4 | Picker | `exercise_picker_screen.dart`, `database.dart` (tabla nueva) | tabla | tabla | Media | **P2** | — |
| M15 | Superseries en la UI | F4 | Entrenamiento | `active_workout_screen.dart` | ya existe `supersetGroupId` | — | Media | **P2** | — |
| M16 | Fusionar Logros→Resumen y Nutrición+Calculadora | U-F5, U-F2 | Progreso, Cuerpo | 4 archivos | — | — | Media | **P2** | — |
| M17 | Coach: configurar CI o quitar la tarjeta | A14 | Dashboard | `release.yml` o `dashboard_screen.dart` | — | — | Baja | **P2** | decisión |
| M18 | `pull` en `SyncableEntity` (revisar ADR-005) | A6 | — | `syncable.dart` + 6 entidades | — | — | Alta | **P3** | M4 |
| M19 | Responsive (360 px y tablet) | A19 | Todas | ~10 archivos | — | — | Alta | **P3** | — |
| M20 | Limpieza: `main_audit.dart`, pose, deps | A23, A24 | — | varios | — | — | Baja | **P3** | decisión |

---

## 9. ARQUITECTURA OBJETIVO (deliberadamente conservadora)

**No cambia:** Drift como fuente de verdad, `provider` como estado, la capa
`Repository`, `AnimationRepository` + proveedores por prioridad, el sistema de diseño
"Kinetic AI" de `core/theme.dart`, el patrón de hubs con `PillTabBar`, el merge
idempotente del catálogo. Todo eso está bien hecho y es lo que hace la app viable.

**Cambia:**
1. **Ciclo de vida del entrenamiento activo**: el draft pasa a tener caducidad
   explícita y una salida (descartar) que hoy no existe.
2. **Assets**: bundle curado (WebP) → descarga bajo demanda con caché en disco →
   placeholder. Manifest estático versionado con el código. **Cero assets en Supabase
   Storage.**
3. **Supabase**: el esquema remoto pasa a ser un espejo real del local (no un
   subconjunto), con RLS optimizado y RPC acotadas. Sigue siendo **solo backup** hasta
   que se decida M18.
4. **Frontera de datos**: catálogo y media = estáticos, versionados con el código.
   Solo lo generado por el usuario viaja a Supabase.

---

## 10. Fuentes externas consultadas

| Fuente | URL | Qué demuestra | Cómo influye |
|---|---|---|---|
| exercises-dataset (hasaneyldrm) | https://github.com/hasaneyldrm/exercises-dataset | 1.324 ejercicios; datos MIT; media © Gym visual con exigencia de licencia propia para reutilizar | Origen confirmado de los 16 GIFs → A4 y la decisión de §4.5 |
| free-exercise-db (yuhonas) | https://github.com/yuhonas/free-exercise-db | 800+ ejercicios, imágenes JPG, **Unlicense** (dominio público) | Única alternativa sin fricción legal para uso comercial |
| wger | https://github.com/wger-project/wger | 845+ ejercicios, **AGPL-3.0** | Descartada: copyleft incompatible con app propietaria |
| Supabase database linter | https://supabase.com/docs/guides/database/database-linter | Reglas 0001/0003/0005/0028/0029 | Base de A7, A8, A9 |
| Supabase RLS performance | https://supabase.com/docs/guides/database/postgres/row-level-security#call-functions-with-select | `(select auth.uid())` evita la re-evaluación por fila | Base de M5 |
