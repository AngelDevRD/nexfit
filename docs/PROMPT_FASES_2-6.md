# PROMPT — NEXFIT, FASES 2 a 6 (todo lo que quedó pendiente)

> Pegar este documento completo como primer mensaje en una sesión nueva con acceso al
> repositorio `nexfit`. Es autosuficiente: no hace falta releer la auditoría ni repetir
> la investigación. Documentos de respaldo, solo si necesitás profundizar:
> `docs/AUDITORIA_2026-09-04.md` y `docs/PROMPT_MAESTRO_SONNET.md`.

---

## 1. CONTEXTO

App de gimnasio **NexFit** (`pubspec.yaml` → `name: appgym`, v`1.1.4+7`).

- **Stack: Flutter / Dart.** No es React ni TypeScript. Las pantallas son widgets en
  `lib/screens/**`. Estado con `provider`, composition root en `lib/main.dart`.
- **Offline-first:** la fuente de verdad es **SQLite local vía Drift**
  (`lib/core/local/database.dart`, `schemaVersion = 11`). Supabase es **solo destino de
  subida (backup)**. La app nunca lee de Supabase durante el uso normal.
- **Supabase:** proyecto `appgym`, ref `btrdczpnuutrvgoprqze`. 11 tablas `nexfit_*`, RLS
  activo en todas, **0 filas hoy**, **0 buckets de Storage**.
- **Credenciales:** `flutter run --dart-define-from-file=env.json`. `env.json` está en
  `.gitignore` y nunca estuvo en git. **No lo commitees.**
- **Diseño:** sistema "Kinetic AI" en `lib/core/theme.dart`. Tema oscuro, primario azul
  `#4F7CFF`, éxito verde `#22C55E`, acento violeta `#8B5CF6`, fondo `#0B0D12`. Capturas
  de referencia en `docs/auditoria/baseline/*.png`.

### Baseline de calidad — no lo rompas
- `flutter analyze --no-pub` → **11 infos, 0 warnings, 0 errores**.
- `flutter test --no-pub` → **207 tests, todos en verde**.

### Ya hecho — NO lo repitas
Una Fase 1 previa cerró los dos bugs críticos. Está en el working tree, sin commitear:
- `ActiveWorkoutRepository`: `discard()`, `staleSessionId()`, y `currentSessionId()` /
  `watchCurrentSessionId()` autolimpian el draft huérfano.
- `StartWorkoutScreen`: diálogo de 3 salidas (Continuar / Descartar / Cancelar) en vez
  de resumir en silencio; `try/catch` sobre el `StateError` de `begin()`.
- `HomeShell`: el banner salió del `Stack` y pasó a `Column` + `Expanded`, así que ya no
  le tapa el toque al FAB de `EntrenarHubScreen`.
- `ActiveWorkoutScreen._load()`: `try/catch` + `EmptyState` en vez de spinner infinito.
- Drift `schemaVersion` 10→11: borra drafts huérfanos de instalaciones ya afectadas.

También hay **dos migraciones SQL ya escritas pero NO aplicadas**:
`supabase/migrations/20260905_0002_alinear_esquema.sql` y `..._0003_endurecer_rls.sql`.

### Verificado como YA RESUELTO — no vuelvas a "arreglarlo"
Estos aparecen como pendientes en documentos viejos, pero se comprobó en el código que
ya están hechos: **T3/A12** (`WorkoutSummaryScreen._loadComparisons` ya usa una sola
query, `previousVolumeByMuscle`), **T14/A13** (`history()` ya pagina con `limit`/
`offset` y `HistoryListScreen` ya tiene `_loadMore`), **U2/A17** (el gráfico de racha ya
se alimenta de `trainedLast7Days()`, las alturas hardcodeadas se eliminaron).

---

## 2. REGLAS ABSOLUTAS

1. **No rediseñes visualmente la app.** Reutilizá `AppColors`, `AppSpacing`, `AppRadius`,
   `AppGlow`, `Theme.of(context).textTheme`. Nunca un `TextStyle(fontSize: N)` ni un
   `Color(0x...)` a mano.
2. **Cambios quirúrgicos:** ~3 archivos por cambio lógico. Nada de features no pedidas.
3. **Nunca un `catch` vacío.** O lo manejás, o `developer.log(..., error: e, stackTrace: st)`.
4. **Después de CADA tarea:** `flutter analyze --no-pub` (0 errores/warnings) →
   `flutter test --no-pub` (207 + los nuevos, todos verdes). Si algo se pone rojo,
   arreglalo antes de seguir.
5. **No apliques nada a Supabase sin el OK explícito del usuario.**
6. **No borres código sin confirmación** (las eliminaciones están marcadas abajo).
7. **No hagas `git commit` ni `git push`** salvo que te lo pidan. Autor: Angel, **nunca**
   `Co-Authored-By` de IA.
8. Comentarios y textos de UI **en español**. Nombres de código en inglés.

### Entorno Windows — vas a chocar con esto
`flutter test` crashea con `PathAccessException: ... build\native_assets\windows\sqlite3.dll`
cuando quedó vivo un `flutter_tester` de una corrida anterior. Antes de cada corrida:

```bash
taskkill //F //IM flutter_tester.exe //IM dart.exe >/dev/null 2>&1; sleep 2
```

No uses `timeout` externo para `flutter test`: mata al padre y deja el hijo colgado,
que es justo lo que produce el lock.

---

## 3. TAREAS

Ordenadas por prioridad. Hacé una, verificá, seguí.

---

### BLOQUE A — Seguridad y legal (P0)

#### A4 — Atribución de la media de Gym visual · **HIGH, riesgo legal**

Los 16 GIFs de `assets/animations/gymvisual/` son **© Gym visual**, incluidos en el APK
que `.github/workflows/release.yml` publica en GitHub Releases. El README del dataset
origen (https://github.com/hasaneyldrm/exercises-dataset) dice textual: *"Keep the
`© Gym visual — https://gymvisual.com/` attribution intact. Reuse is governed by Gym
visual's Terms & Conditions; obtain your own license there."*

La resolución **sí** cumple (los 16 son 180×180, verificado). Lo que falta es la
atribución: hoy solo aparece en `ExerciseDetailScreen` (línea ~895) y en
`ExerciseAnimationViewer`. **`lib/widgets/exercise_thumb.dart` no la muestra nunca** — y
es el widget que renderiza esos GIFs en la lista de ejercicios, el picker y el
entrenamiento activo.

**Qué hacer:**
1. Creá `lib/widgets/attribution_footer.dart`. Una miniatura de 56 px no puede llevar
   texto, así que la atribución va **una vez por pantalla**, al pie.
2. Colocalo en `ExerciseListScreen`, `ExercisePickerScreen` y `ActiveWorkoutScreen`,
   visible cuando al menos un ejercicio en pantalla use media de un proveedor con
   atribución.
3. **No hardcodees el texto.** Sacalo de `ExerciseAnimation.attribution`
   (`GymVisualProvider` ya lo provee). El día que se cambie de proveedor no debe quedar
   rastro de esa licencia en la UI.

**Decisión que NO podés tomar vos** — preguntá y esperá respuesta antes de ampliar el
set de GIFs:
- **Opción A (recomendada):** migrar a **`yuhonas/free-exercise-db`** —
  https://github.com/yuhonas/free-exercise-db — 800+ ejercicios, **Unlicense (dominio
  público)**, sin atribución ni restricción comercial. Se pierde la animación (pasa a 2
  imágenes estáticas: inicio y fin) y se gana seguridad legal total.
- **Opción B:** contratar la licencia comercial de Gym visual.
- **Opción C (statu quo seguro):** mantener los 16 GIFs, aplicar la atribución de arriba
  y **no ampliar** el set.

Mientras no haya respuesta, actuá como si fuera la **Opción C**.

#### A7 / A8 / A9 — Endurecer Supabase

Las dos migraciones **ya están escritas y revisadas**, con los predicados leídos de
`pg_policies` real (no inventados). No las reescribas. Sí:

1. Pedile al usuario un backup (panel → Database → Backups) y el **OK explícito**.
2. Aplicá `20260905_0002_alinear_esquema.sql` y después `20260905_0003_endurecer_rls.sql`.
   Son aditivas; ninguna política cambia su lógica (solo `auth.uid()` →
   `(select auth.uid())`, que lo convierte en InitPlan en vez de evaluarse por fila).
3. **A8 no es SQL:** pedile al usuario que active *Prevent use of leaked passwords* en
   Authentication → Sign In / Providers → Password. No podés hacerlo vos.
4. Verificá con los advisors de Supabase que los lints 0003 y 0028 desaparecieron.

**Ojo:** `20260905_0002` crea `nexfit_workout_sessions.routine_day_id`, pero esa columna
**no se puede poblar todavía** — el motivo está documentado dentro del propio archivo
(la tabla local `RoutineDays` no tiene `serverId`, así que no hay forma de traducir el
int local al uuid remoto). No intentes mandarla desde el cliente hasta resolver eso.

---

### BLOQUE B — Integridad de datos (P0/P1)

#### A25 — Las claves foráneas no se aplican · **HIGH**

`lib/core/local/database.dart` declara **5 acciones de FK** (`onDelete: KeyAction.cascade`
en `RoutineDays.routineId`, `RoutineExercises.dayId`, `WorkoutSets.sessionId`,
`PendingSetOps.sessionId`; `setNull` en `PersonalRecords.setId`). **Ninguna se aplica:**
SQLite ignora toda acción de clave foránea salvo que se ejecute `PRAGMA foreign_keys = ON`,
y esta base nunca lo activa. Lo detectó el test de `discard()` en la Fase 1 — por eso ese
método borra las filas hijas a mano.

Consecuencia real: borrar una rutina deja días y ejercicios de rutina huérfanos; borrar
una sesión por cualquier camino que no sea `discard()` deja series y `PendingSetOps`
huérfanos.

**Cómo abordarlo — en este orden, no saltes pasos:**
1. Escribí un test que **mida el daño actual**: creá una rutina con días y ejercicios,
   borrala, y contá las filas huérfanas que quedan. Eso te da el alcance real.
2. Auditá cada camino de borrado (`RoutineRepository`, `WorkoutRepository`,
   `WorkoutSessionSyncable._pushDelete`, `DataImportService`) y decidí cuáles dependen
   hoy del cascade que no existe.
3. **Después** decidí entre:
   - (a) activar `PRAGMA foreign_keys = ON` en un `beforeOpen` de `AppDatabase`, **más**
     una migración de datos que limpie los huérfanos ya existentes. Es lo correcto a
     largo plazo, pero es un cambio de comportamiento global: bases ya instaladas pueden
     tener huérfanos previos que empezarían a violar constraints.
   - (b) borrar las filas hijas explícitamente en cada repositorio, como ya hace
     `discard()`. Más pequeño, pero hay que acordarse siempre.
4. Presentá las dos opciones al usuario con lo que encontraste en el paso 1 **antes** de
   implementar. Esto no es un cambio quirúrgico.

#### A5 / A6 — Esquema remoto y ausencia de `pull`

- **A5** lo resuelve la migración `20260905_0002` (bloque A). Después de aplicarla,
  hacé que `WorkoutSessionSyncable` mande `title`, `exercise_notes` y `exercise_order`,
  y que `RoutineSyncable` mande las 5 columnas nuevas de `nexfit_routine_exercises`.
- **A6 (`pull`) es P3, no lo hagas todavía.** `SyncableEntity`
  (`lib/core/sync/syncable.dart`) solo declara `push`, y eso es una decisión documentada
  en `docs/adr/ADR-005-sync-solo-subida.md`. Reinstalar la app pierde todo. Implementar
  `pull` toca las 6 entidades y necesita resolución de conflictos por `updatedAt`: es su
  propio proyecto, con su propio ADR. Si el usuario lo pide, empezá por `ProfileSyncable`
  (el más visible: perfil vacío tras login en un dispositivo nuevo) y
  `WorkoutSessionSyncable` (el de mayor impacto).

#### A15 — Los ejercicios propios no sincronizan

Los ejercicios creados desde la app (`ExerciseRepository`, ids desde 1.000.000, slug
`custom-<id>`) existen **solo en local**: no hay `ExerciseSyncable`, así que reinstalar
los pierde y deja huérfanas las series que los referencian.

La tabla remota `nexfit_custom_exercises` ya está en la migración `20260905_0002`.
Creá `lib/core/sync/entities/exercise_syncable.dart` siguiendo el patrón de las 6
entidades existentes, y registralo en `lib/main.dart`. Upsert por `(user_id, slug)`.

**El catálogo base NO va a Supabase**: es estático, idéntico para todos, y vive en
`assets/data/exercises.json`. Replicarlo sería pagar lecturas y egress por datos que
nunca cambian.

---

### BLOQUE C — Rendimiento y UI (P1)

#### A10 — `ExerciseThumb` crea el `Future` dentro de `build()`

`lib/widgets/exercise_thumb.dart:53-54`:
```dart
child: FutureBuilder<ExerciseAnimation>(
  future: context.read<AnimationRepository>().getAnimation(slug),
```
Cada rebuild —cada `setState` del entrenamiento activo, cada tecla en el buscador del
picker— vuelve a resolver la animación de todas las filas visibles.

**Fix:** convertilo a `StatefulWidget`, resolvé una sola vez en `initState` guardando el
`Future` en un campo del `State`, y re-resolvé en `didUpdateWidget` solo si cambia el
`slug`.

**Test:** montá el widget con un `ExerciseAnimationProvider` falso que cuente llamadas,
forzá varios rebuilds, verificá que la cuenta queda en 1.

#### A11 — `CustomAnimationProvider` hace 5 cargas fallidas por consulta

`lib/main.dart` construye `AnimationRepository(providers: [CustomAnimationProvider(), GymVisualProvider()])`.
`CustomAnimationProvider` tiene **prioridad 0** (se prueba primero) y su carpeta
`assets/animations/custom/` está **vacía**, así que toda resolución paga 5
`rootBundle.load()` fallidos (mp4, webm, gif, json, webp) antes de llegar a GymVisual.
Combinado con A10, son cientos de cargas fallidas por segundo al scrollear.

**Fix:** sacalo de la lista en `main.dart` — un cambio de una línea. **No borres el
archivo**: es la extensión futura documentada para recursos propios.

#### A16 — Miniaturas con fondo blanco sobre tema casi negro

Los GIFs de Gym visual tienen fondo blanco puro y perforan la UI oscura. Se ve en
`docs/auditoria/baseline/18-entrenamiento-activo.png`.

**Fix:** en `ExerciseThumb`, mantené el `ClipRRect` + `Container` con
`color.withValues(alpha: 0.15)` que ya existen, y agregá un tratamiento consistente
(por ejemplo `ColorFiltered` con `BlendMode.multiply` sobre el color del grupo muscular,
o un borde/inset). Probá contra la captura y elegí lo que menos altere la identidad
actual. **Aplicá el mismo tratamiento en `ExerciseAnimationViewer`** para que no haya
dos aspectos distintos del mismo GIF.

#### A26 — `AppUpdater`: llamada HTTP sin costura y `catch` vacío

`lib/screens/home/home_shell.dart:33` llama a `AppUpdater.checkForUpdate(context, slug: 'nexfit')`
en cada montaje del shell. Hace una petición HTTP real con timeout, sin forma de
desactivarla. Consecuencia: **cualquier `testWidgets` que monte `HomeShell` queda con un
`Timer` pendiente y se cuelga** — por eso el test de regresión del banner (A2) no existe
hoy (ver "Deuda conocida" abajo).

Además `lib/core/app_updater.dart:78` tiene un `catch (_) {}` vacío (viola AG-CORE-001);
tiene un comentario que lo justifica, pero debería al menos registrar con
`developer.log`.

**Fix:** agregá a `HomeShell` un parámetro opcional
`final Future<void> Function(BuildContext)? onCheckForUpdate;` que por defecto llame al
real. Y reemplazá el `catch (_) {}` por uno que registre. **Solo hacelo si vas a escribir
el test que lo aprovecha** (ver más abajo) — si no, es una costura sin usuario.

---

### BLOQUE D — Accesibilidad (P1)

#### A18 — Solo 2 de 154 archivos usan `Semantics`

`lib/widgets/stepper_field.dart` ya lo hace bien y sus tests lo verifican
(`test/widgets/stepper_field_test.dart`, casos "D3"). **Usalo de modelo.**

Por orden de importancia:
1. Todo `IconButton` sin texto visible necesita `tooltip:` (Flutter lo convierte en
   etiqueta semántica). Buscá `IconButton(` sin `tooltip`.
2. El check por serie de `ActiveWorkoutScreen` (el círculo grande de la izquierda) debe
   anunciar "Serie N completada / sin completar".
3. Los `InkWell` que hacen de tarjeta clicable (`_StartCard`, `_PickerCard`, el banner de
   entrenamiento activo) necesitan `Semantics(button: true, label: ...)`.
4. Targets táctiles ≥ 48×48: revisá los `IconButton` con `dense: true`.

**No persigas los 154 archivos.** Cubrí `lib/screens/workout/`, `lib/screens/exercises/`
y `home_shell.dart`: es el 80 % del uso real.

---

### BLOQUE E — Limpieza (P2, cada punto requiere confirmación)

#### A20 — Visor 3D: feature muerta con dependencia cara

Estado real (distinto de lo que dicen documentos viejos): el botón "Ver en 3D" **ya está
detrás de `if (_has3DModel)`** en `lib/screens/exercises/exercise_detail_screen.dart`, así
que no aparece siempre. Pero `assets/models_3d/` está **vacía** (solo README), de modo que
`_has3DModel` es **siempre falso** y el botón no aparece nunca.

Lo que queda es el costo: `lib/features/exercise_3d/` (código muerto inalcanzable) y la
dependencia `flutter_3d_controller`, que arrastra `flutter_inappwebview` — y **eso es lo
que rompe el build de Windows con MSVC 14.5x** (por eso `.github/workflows/release.yml`
fija `windows-2022` en vez de `windows-latest`).

**Proponé al usuario:** borrar `lib/features/exercise_3d/`, el bloque `if (_has3DModel)`,
`assets/models_3d/` y `flutter_3d_controller` de `pubspec.yaml`. Verificá después si
`windows-latest` vuelve a compilar. **No lo hagas sin el sí.**

#### A14 — Coach IA: la tarjeta más destacada no funciona en producción

`SmartBackendAvailability.isConfigured` depende de `--dart-define=SMART_BACKEND_URL`, y
ese secret **no está** en `.github/workflows/release.yml` (verificado: 0 ocurrencias).
En todo APK publicado, la tarjeta "Gemelo Digital" del Dashboard —la de gradiente y
glow, la más prominente— abre `ComingSoonView`.

**Preguntá al usuario:** o se configura el secret en CI, o se quita la tarjeta del
Dashboard hasta que el backend exista. No dejes la función más visible rota.

#### A23 — `lib/main_audit.dart`

Archivo temporal de una auditoría anterior, todavía en `lib/`. Confirmá y borralo.

#### `lib/features/pose/`

347 líneas + los plugins nativos `camera` y `google_mlkit_pose_detection`, inalcanzables
detrás de `kShowPoseAnalysisEntryPoints = false` (`lib/core/feature_flags.dart`), sin
fecha de activación. **Decisión del usuario:** activarla o eliminarla con sus
dependencias.

---

## 4. DEUDA CONOCIDA QUE HEREDÁS

**A2 no tiene test de regresión.** El cambio de `Stack` a `Column` + `Expanded` en
`HomeShell` está aplicado y es correcto por inspección, pero sin cobertura automática.
Se intentó un `test/screens/home_shell_test.dart` que monta el shell completo y **se
cuelga**: el `IndexedStack` construye las 5 pestañas de golpe y alguna nunca resuelve
(sospecha principal: `WearablesScreen`, que toca el plugin `health`), más el `Timer`
pendiente de A26. Se borró — un test que cuelga bloquea la suite entera y es peor que
ninguno.

Si resolvés A26, **intentá de nuevo** ese test: montá `HomeShell` con
`onCheckForUpdate: (_) async {}`, usá `pump()` con duraciones fijas (nunca
`pumpAndSettle`, que no converge con cronómetros y spinners vivos), y verificá que al
tocar el FAB "Empezar entrenamiento" aparece el diálogo de entrenamiento activo. Si
vuelve a colgar, aislá qué pestaña lo causa antes de insistir.

Mientras tanto, **A2 se verifica a mano**: con un entrenamiento activo, ir a Entrenar y
comprobar que "Empezar entrenamiento" responde.

---

## 5. TRAMPAS DE TESTING (aprendidas a la mala)

- **`isNull` / `isNotNull` ambiguos.** Si un test importa `package:drift/drift.dart`
  (para `Value(...)`) y usa los matchers de `flutter_test`, el analyzer tira
  `ambiguous_import`. Solución: `import 'package:drift/drift.dart' hide isNotNull, isNull;`
- **`pumpAndSettle` no converge** en cualquier pantalla con un `CircularProgressIndicator`
  visible o un `Timer.periodic` vivo — que son casi todas las de esta app. Usá `pump()`
  con duraciones fijas.
- **Corré `flutter analyze` de verdad y leé la salida completa.** Un "11 issues found" al
  pie puede esconder errores arriba: los infos y los errores se mezclan en la misma
  lista.

---

## 6. CRITERIOS DE ACEPTACIÓN

- [ ] `flutter analyze --no-pub` → 0 errores, 0 warnings (los 11 infos preexistentes son
      tolerables; no agregues ninguno).
- [ ] `flutter test --no-pub` → 207 previos **+ los nuevos**, todos verdes.
- [ ] `flutter build apk --release --dart-define-from-file=env.json` compila.
- [ ] **A4:** la atribución "© Gym visual" es visible en toda pantalla que muestre esa
      media, y el texto sale de `ExerciseAnimation.attribution`, no hardcodeado.
- [ ] **A7:** las dos RPC `SECURITY DEFINER` ya no son ejecutables por `anon`, y el
      leaderboard solo responde a participantes o al dueño del reto.
- [ ] **A9:** el advisor de rendimiento de Supabase ya no reporta `auth_rls_initplan`.
- [ ] **A8:** leaked-password protection activada (confirmado por el usuario).
- [ ] **A25:** existe un test que demuestra que borrar una rutina o una sesión no deja
      filas huérfanas, y la decisión (pragma vs. borrado explícito) está documentada.
- [ ] **A10:** un test demuestra que `ExerciseThumb` resuelve la animación una sola vez
      ante varios rebuilds.
- [ ] **A11:** `CustomAnimationProvider` ya no está en la lista de `main.dart`, y el
      archivo sigue existiendo.
- [ ] **A18:** todo `IconButton` accionable de `workout/` y `exercises/` tiene `tooltip`.
- [ ] RLS sigue protegiendo los datos (`get_advisors` de Supabase: 0 lints de tabla sin RLS).
- [ ] Supabase no recibe ninguna consulta durante el uso normal (todo sale de Drift).
- [ ] **0 buckets y 0 objetos** en Supabase Storage.
- [ ] El diseño visual se conserva: compará contra `docs/auditoria/baseline/*.png` y
      justificá cualquier diferencia.
- [ ] La app funciona en modo avión (offline-first intacto).
- [ ] Ninguna funcionalidad existente se rompe.
- [ ] Ningún secreto en el código ni en git (`git log --all -- env.json` sigue vacío).
- [ ] Nada commiteado ni aplicado a Supabase sin pedirlo.

---

## 7. DECISIONES QUE NECESITÁS DEL USUARIO ANTES DE AVANZAR

Preguntá las cinco juntas, en un solo mensaje, al principio:

1. **Licencia de la media:** ¿migrar a `free-exercise-db` (Unlicense, pierde animación),
   contratar Gym visual, o mantener los 16 GIFs con atribución y no ampliar?
2. **¿Aplico las migraciones SQL** `20260905_0002` y `0003` al proyecto `appgym`?
   (¿Hiciste backup?)
3. **A25:** ¿pragma global de foreign keys, o borrado explícito por repositorio? (Te doy
   los números del daño real antes de que decidas.)
4. **Visor 3D:** ¿borro `features/exercise_3d/` + `flutter_3d_controller`?
5. **Coach IA:** ¿configuro `SMART_BACKEND_URL` en CI, o quito la tarjeta del Dashboard?
