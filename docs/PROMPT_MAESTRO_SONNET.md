# PROMPT MAESTRO DE IMPLEMENTACIÓN — NEXFIT (para Claude Sonnet)

> Copiar y pegar este documento completo como primer mensaje en una sesión de Sonnet
> con acceso al repositorio `nexfit`. Sonnet no necesita repetir la auditoría: todo lo
> verificado está aquí. Auditoría completa de respaldo: `docs/AUDITORIA_2026-09-04.md`.

---

## 1. CONTEXTO DEL PROYECTO

App de gimnasio **NexFit** (`pubspec.yaml` → `name: appgym`, versión `1.1.4+7`).

- **Stack: Flutter / Dart.** NO es React ni TypeScript. No hay `src/`, `.tsx`, hooks ni
  Next.js. Las pantallas son widgets en `lib/screens/**`.
- **Estado:** `provider` (`ChangeNotifierProvider` / `Provider.value`), composition root
  en `lib/main.dart`.
- **Datos: offline-first.** La fuente de verdad es **SQLite local vía Drift**
  (`lib/core/local/database.dart`, `schemaVersion = 10`). Supabase es **solo destino de
  subida (backup)** — ver `docs/adr/ADR-002-offline-first.md` y `ADR-005-sync-solo-subida.md`.
- **Supabase:** proyecto `appgym`, ref `btrdczpnuutrvgoprqze`. 11 tablas `nexfit_*`,
  RLS activo en todas, **hoy con 0 filas**. Esquema versionado en
  `supabase/migrations/20260904_0001_nexfit_schema.sql`.
- **Credenciales:** `--dart-define-from-file=env.json` (ver `README.md`). `env.json` está
  en `.gitignore` y **nunca** estuvo en el historial de git. **No lo commitees jamás.**
- **Estado de calidad al empezar:** `flutter analyze` = 11 infos / 0 errores;
  `flutter test` = **196 tests en verde**. Ese es el baseline que no se puede romper.
- **Diseño:** sistema "Kinetic AI" documentado en `lib/core/theme.dart`. Tema oscuro,
  primario azul `#4F7CFF`, éxito verde `#22C55E`, acento violeta `#8B5CF6`, fondo
  `#0B0D12`. Capturas de referencia en `docs/auditoria/baseline/*.png`.

Una auditoría previa (`docs/AUDITORIA_2026-09-03.md`) ya se ejecutó: **sus órdenes
C1–C6, N1–N5, T1, T2, T4, T7 y U-F1 están implementadas. No las repitas.** Este prompt
cubre lo que quedó pendiente y lo que aquella auditoría no vio.

---

## 2. OBJETIVO

Ejecutar, **en el orden de las fases de la sección 25**, las correcciones y mejoras
listadas. Prioridad: **corrección > seguridad > UX > rendimiento > mantenibilidad >
coste > escalabilidad**.

---

## 3. REGLAS ABSOLUTAS

1. **NO rediseñes visualmente la app.** El diseño actual es la base. Reutiliza
   `AppColors`, `AppSpacing`, `AppRadius`, `AppGlow`, `Theme.of(context).textTheme`.
   Nunca escribas `TextStyle(fontSize: N)` ni un `Color(0x...)` a mano.
2. **Cambios quirúrgicos.** Máximo ~3 archivos por cambio lógico. Nada de features
   extra no pedidas.
3. **Nunca un `catch` vacío.** Si capturas, o lo manejas o lo registras con
   `developer.log(..., error: e, stackTrace: st)`.
4. **Nunca credenciales en el código.** Siguen viniendo de `String.fromEnvironment`.
5. **Después de CADA fase**, en este orden: `flutter analyze --no-pub` (0 errores,
   0 warnings) → `flutter test --no-pub` (196 tests + los nuevos, todos verdes).
   Si algo se pone rojo, **arréglalo antes de seguir**.
6. **No borres una función sin confirmar.** Todo lo marcado "decidir" en este documento
   requiere el sí explícito del usuario antes de tocarlo.
7. **No subas assets a Supabase Storage.** Razonado en la sección 12.
8. Comentarios y textos de UI **en español**. Nombres de código en inglés, como ya está.
9. **No `git push` ni `git commit`** salvo que el usuario lo pida.

---

## 4. DISEÑO QUE DEBE CONSERVARSE

No toques, salvo donde este documento lo diga explícitamente:

- `lib/core/theme.dart` completo (paleta, radios, espaciado, glow, gradientes).
- `lib/widgets/pill_tab_bar.dart`, `stat_tile.dart`, `stepper_field.dart`,
  `empty_state.dart`, `muscle_group_filter.dart`, `muscle_silhouette.dart`.
- La estructura de 5 destinos del `NavigationBar` en `home_shell.dart`.
- La estructura de tabs de `EntrenarHubScreen`, `ProgresoHubScreen`, `CuerpoHubScreen`.
- El layout de `ActiveWorkoutScreen`: fila de `StatTile` arriba, tarjetas
  `_ExerciseFocusCard` con columnas SET/KG/REPS/RPE, FAB extendido abajo.
- La tarjeta de racha y la tarjeta con gradiente del Dashboard (su *estilo*; el
  contenido de la de racha sí se corrige, ver F3.3).

---

## 5. ARQUITECTURA ACTUAL (para que no la busques)

```
lib/
├── main.dart                    composition root: 14 repos + SyncEngine + providers
├── core/
│   ├── local/database.dart      Drift, 14 tablas, schemaVersion 10
│   ├── local/local_bootstrap.dart  mergeExerciseCatalog (fusión idempotente por slug)
│   ├── theme.dart               sistema de diseño "Kinetic AI"
│   ├── sync/                    SyncEngine + SyncableEntity (SOLO push) + 6 entidades
│   ├── exercise_animation/      AnimationRepository + providers por prioridad
│   └── auth/                    AuthRepository, SupabaseAuthRepository, Unavailable...
├── repositories/                14 repos, acceso único a la base
├── screens/                     auth, home, entrenar, workout, exercises, routines,
│                                history, progreso, stats, goals, gamification, social,
│                                cuerpo, nutrition, recovery, measurements, wearables,
│                                calculators, profile, settings, coach
├── features/                    exercise_3d, pose, import_export, measurements_import
└── widgets/                     componentes compartidos
```

**Cadena de resolución de animaciones** (esto es lo que hay que entender para la sección 11):
`ExerciseThumb` / `ExerciseAnimationViewer` → `AnimationRepository.getAnimation(slug)`
→ recorre proveedores ordenados por `priority` → `CustomAnimationProvider` (prio 0,
carpeta `assets/animations/custom/` **vacía**) → `GymVisualProvider` (prio 10, lee
`assets/data/gymvisual_animations.json`) → `ExerciseAnimation.placeholder`.

---

## 6. PROBLEMAS ENCONTRADOS (verificados, no inferidos)

| ID | Sev | Qué pasa |
|---|---|---|
| A1 | CRITICAL | El entrenamiento activo **no caduca nunca**: el draft (`ActiveWorkoutDrafts`, fila única id=1) solo se borra en `ActiveWorkoutRepository.finish()`. Minimizar o cerrar la app lo deja vivo para siempre → el banner aparece en cada arranque y `StartWorkoutScreen` redirige a la sesión vieja, imposibilitando empezar una nueva. Además `begin()` lanza `StateError` y `_start()` no lo captura. |
| A2 | CRITICAL | El banner global (`home_shell.dart:88`, `Positioned(bottom:0)`) se dibuja **encima** del `IndexedStack` y **tapa el FAB "Empezar entrenamiento"** de `EntrenarHubScreen` (su `Scaffold` no tiene `bottomNavigationBar`, así que el FAB queda a 16 px del borde). El botón no responde. |
| A3 | HIGH | `ActiveWorkoutDrafts.sessionId` no tiene FK. Si la sesión desaparece, `WorkoutRepository.get()` lanza y `_load()` no lo captura → `ActiveWorkoutScreen` se queda en `CircularProgressIndicator` **para siempre**. |
| A4 | HIGH | Los 16 GIFs de `assets/animations/gymvisual/` son **© Gym visual**, incluidos en el APK público. La licencia exige atribución visible en toda pantalla que los muestre, y **`ExerciseThumb` no la muestra** (listas, picker, entrenamiento activo). |
| A5 | HIGH | El esquema de Supabase **no refleja** el local: faltan `title`/`routine_day_id` en sesiones, `exercise_notes`/`exercise_order` en series, 5 columnas en `routine_exercises`, y las tablas de récords/medidas/ejercicios propios. |
| A7 | MED | `nexfit_challenge_leaderboard` y `nexfit_join_challenge_by_code` son `SECURITY DEFINER` **ejecutables por el rol `anon`**. |
| A8 | MED | Leaked-password protection desactivada en Supabase Auth. |
| A9 | MED | 16 políticas RLS usan `auth.uid()` sin `(select ...)` → se re-evalúa por fila. |
| A10 | MED | `ExerciseThumb` crea el `Future` **dentro de `build()`** (línea 53) → se re-resuelve en cada rebuild. |
| A11 | MED | `CustomAnimationProvider` (prioridad 0) hace **5 `rootBundle.load()` fallidos** por consulta porque su carpeta está vacía. |
| A12 | MED | `WorkoutSummaryScreen._loadComparisons` hace una query de historial completo **por grupo muscular**. |
| A13 | MED | `WorkoutRepository.history()` sin paginación en la carga inicial. |
| A14 | MED | `SMART_BACKEND_URL` **no está** en `.github/workflows/release.yml` → el Coach IA abre `ComingSoonView` en todo APK publicado. |
| A15 | MED | Los ejercicios propios no sincronizan (no existe `ExerciseSyncable`) → se pierden al reinstalar. |
| A16 | MED | Miniaturas con fondo blanco puro sobre tema casi negro. |
| A17 | MED | `_StreakCard` del Dashboard dibuja un gráfico con alturas **hardcodeadas** `[10,16,13,22,18,26,32]`. |
| A18 | HIGH | Accesibilidad: solo **2 de 154** archivos usan `Semantics`. |
| A20 | MED | Visor 3D con **0 modelos**; arrastra `flutter_3d_controller` → `flutter_inappwebview` → rompe el build de Windows con MSVC 14.5x. |
| A21 | LOW | El FAB "Agregar ejercicio" se **oculta** mientras corre el descanso (`active_workout_screen.dart:858`). |
| A23 | LOW | `lib/main_audit.dart` es un archivo temporal de la auditoría anterior, todavía presente. |

---

## 7. CAMBIOS DE ARQUITECTURA

Solo tres, y ninguno rompe lo existente:

1. **Ciclo de vida del entrenamiento activo** — el draft gana caducidad y una acción
   de descarte. Sección 22.1.
2. **Assets de ejercicio** — tres capas por prioridad, reusando `AnimationRepository`
   tal cual está: bundle curado → descarga bajo demanda con caché en disco →
   placeholder. Sección 12.
3. **Frontera de datos** — catálogo y media son **estáticos versionados con el código**;
   solo lo que genera el usuario viaja a Supabase.

---

## 8. CAMBIOS DE SUPABASE

Crear `supabase/migrations/20260905_0002_alinear_esquema.sql` con este contenido
(no lo apliques a producción sin el visto bueno del usuario; ver sección 26):

```sql
-- Alinea el esquema remoto con el local (Drift schemaVersion 10).
-- Todas las sentencias son aditivas e idempotentes: no borran ni renombran nada.

alter table public.nexfit_workout_sessions
  add column if not exists routine_day_id uuid,
  add column if not exists title text,
  add column if not exists updated_at timestamptz not null default now();

alter table public.nexfit_workout_sets
  add column if not exists exercise_notes text,
  add column if not exists exercise_order integer;

alter table public.nexfit_routine_exercises
  add column if not exists target_weight_kg double precision,
  add column if not exists set_type text default 'normal',
  add column if not exists tempo text,
  add column if not exists target_rpe double precision,
  add column if not exists target_rir integer;

-- Índice faltante detectado por el linter de Supabase (0001).
create index if not exists nexfit_workout_sessions_routine_id_idx
  on public.nexfit_workout_sessions(routine_id);

-- Ejercicios propios del usuario (hoy solo existen en la base local y se
-- pierden al reinstalar). El catálogo base NO va acá: es estático y vive en
-- assets/data/exercises.json.
create table if not exists public.nexfit_custom_exercises (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  slug text not null,
  name text not null,
  muscle_group text not null,
  difficulty text not null,
  detail_json jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now(),
  unique (user_id, slug)
);
create index if not exists nexfit_custom_exercises_user_id_idx
  on public.nexfit_custom_exercises(user_id);
alter table public.nexfit_custom_exercises enable row level security;
create policy nexfit_custom_exercises_own_rows on public.nexfit_custom_exercises
  for all using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
```

---

## 9. CAMBIOS DE RLS Y SEGURIDAD

Crear `supabase/migrations/20260905_0003_endurecer_rls.sql`:

```sql
-- (A9) Las 16 politicas re-evaluan auth.uid() POR FILA. Envolverlo en un
-- subselect lo convierte en un InitPlan que se evalua una sola vez.
-- Linter: 0003_auth_rls_initplan.
alter policy nexfit_profiles_own_row on public.nexfit_profiles
  using ((select auth.uid()) = id) with check ((select auth.uid()) = id);
alter policy nexfit_routines_own_rows on public.nexfit_routines
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
alter policy nexfit_workout_sessions_own_rows on public.nexfit_workout_sessions
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
alter policy nexfit_goals_own_rows on public.nexfit_goals
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
alter policy nexfit_daily_checkins_own_rows on public.nexfit_daily_checkins
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
alter policy nexfit_nutrition_logs_own_rows on public.nexfit_nutrition_logs
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
-- Hacer lo mismo con las politicas via_routine / via_session / de retos:
-- sustituir cada `auth.uid()` por `(select auth.uid())` SIN cambiar la logica.

-- (A7) Las dos RPC son SECURITY DEFINER y hoy las puede llamar el rol anon.
-- Linter: 0028. Solo un usuario autenticado debe poder invocarlas.
revoke execute on function public.nexfit_challenge_leaderboard(uuid) from anon, public;
revoke execute on function public.nexfit_join_challenge_by_code(text) from anon, public;
grant execute on function public.nexfit_challenge_leaderboard(uuid) to authenticated;
grant execute on function public.nexfit_join_challenge_by_code(text) to authenticated;

-- (A7 bis) nexfit_challenge_leaderboard devuelve el leaderboard de CUALQUIER
-- reto a cualquier autenticado que adivine el uuid. Acotarlo a participantes:
-- agregar al principio del cuerpo de la funcion una guarda que lance excepcion
-- si auth.uid() no esta en nexfit_challenge_participants de ese reto.
```

**(A8) Manualmente en el panel** (no es SQL): Authentication → Policies → activar
**Leaked password protection**. Pídeselo al usuario, no puedes hacerlo tú.

**No toques** las políticas existentes en su lógica: ya son correctas (cada usuario ve
solo lo suyo, las tablas hijas resuelven por jerarquía). Solo se optimiza la evaluación.

---

## 10. SISTEMA DE EJERCICIOS

Estado actual verificado: **40 ejercicios** en `assets/data/exercises.json`, ids 1–40,
`image_url` **null en los 40**. Los ejercicios propios usan ids desde 1.000.000 y slug
`custom-<id>`, por lo que quedan fuera del merge del catálogo por construcción.

**Decisión de arquitectura (no la cambies):** el catálogo base es **estático**, vive en
`assets/data/exercises.json` y se siembra en Drift con `mergeExerciseCatalog`
(`lib/core/local/local_bootstrap.dart`). **NO se replica en Supabase**: serían cientos
de filas idénticas para todos los usuarios, pagando lecturas y egress por dato que
nunca cambia. `mergeExerciseCatalog` ya está bien resuelto (fusión idempotente por
`slug`, versionada por hash, nunca cambia el id de una fila existente) — **no lo toques**.

Campos que **faltan** y hay que añadir al esquema del JSON cuando se amplíe el catálogo
(no antes): `alternative_names` (array, para que buscar "bench press" encuentre "Press
banca"), `source`, `license`, `tags`. Y usar de una vez `image_url` en lugar de
mantener el mapeo en un archivo aparte (A22).

---

## 11. SISTEMA DE GIFs E IMÁGENES

### Lo que hay (no lo redescubras)

- 16 GIFs en `assets/animations/gymvisual/`, **todos 180×180**, 61–128 KB, 1,5 MB total.
- Mapeo `slug → gif_path` en `assets/data/gymvisual_animations.json`.
- `assets/images/exercises/` y `assets/models_3d/`: **vacías** (solo README).
- Cobertura: **16 de 40** ejercicios (60 % sin animación).
- Origen: https://github.com/hasaneyldrm/exercises-dataset — **datos MIT, media
  © Gym visual**, con esta condición textual del README del origen: *"Keep the
  `© Gym visual — https://gymvisual.com/` attribution intact. Reuse is governed by Gym
  visual's Terms & Conditions; obtain your own license there."*

### Correcciones obligatorias (P0/P1)

**(A4) Atribución en las miniaturas.** En `lib/widgets/exercise_thumb.dart`, cuando la
animación resuelta tenga `attribution != null` y se esté renderizando la media real
(no el placeholder), la pantalla debe mostrar la atribución. Como una miniatura de
56 px no puede llevar texto, **la solución correcta es mostrarla una vez por pantalla**:
añade un widget `AttributionFooter` en `lib/widgets/` y colócalo al pie de
`ExerciseListScreen`, `ExercisePickerScreen` y `ActiveWorkoutScreen` cuando al menos un
ejercicio visible use media de un proveedor con atribución. **No hardcodees el texto**:
sácalo de `ExerciseAnimation.attribution` (`GymVisualProvider` ya lo provee), para que
el día que se cambie de proveedor no quede rastro de esa licencia en la UI.

**(A10) Cachear el future.** En `ExerciseThumb`, conviértelo a `StatefulWidget` y
resuelve la animación **una sola vez** en `initState` (guardando el `Future` en un campo
del `State`), con `didUpdateWidget` para re-resolver solo si cambia el `slug`. Hoy el
`Future` se crea en `build()` (línea 53) y se re-resuelve en cada rebuild.

**(A11) Quitar el proveedor vacío.** En `lib/main.dart`, el `AnimationRepository` se
construye con `providers: [CustomAnimationProvider(), GymVisualProvider()]`.
`CustomAnimationProvider` tiene prioridad 0 y su carpeta está vacía, así que **toda**
resolución paga 5 `rootBundle.load()` fallidos. Dos opciones, elige la primera:
(a) sacarlo de la lista hasta que haya assets propios — **no borres el archivo**, es la
extensión futura documentada; (b) darle un caché negativo interno. La opción (a) es un
cambio de una línea en `main.dart`.

**(A16) Fondo de las miniaturas.** Los GIFs tienen fondo blanco puro y perforan el tema
oscuro. En `ExerciseThumb`, envuelve la `Image.asset` para que el blanco no domine:
mantén el `ClipRRect` + el `Container` con `color.withValues(alpha: 0.15)` que ya
existe, y añade un tratamiento consistente (por ejemplo `ColorFiltered` con
`BlendMode.multiply` sobre el color del grupo muscular, o un borde/inset). Prueba
visualmente contra `docs/auditoria/baseline/18-entrenamiento-activo.png` y elige lo que
menos altere la identidad actual. **Aplica el mismo tratamiento en
`ExerciseAnimationViewer`** para que no haya dos aspectos distintos del mismo GIF.

### Decisión que NO puedes tomar tú

Pregunta al usuario y **espera respuesta** antes de ampliar el set de GIFs:

- **Opción A (recomendada):** migrar a **`yuhonas/free-exercise-db`** —
  https://github.com/yuhonas/free-exercise-db — 800+ ejercicios, **Unlicense (dominio
  público)**, sin atribución ni restricción de uso comercial. Se pierde la animación
  (pasa a 2 imágenes estáticas por ejercicio: inicio y fin del movimiento) y se gana
  seguridad legal total. Implica borrar `GymVisualProvider` y los 16 GIFs.
- **Opción B:** contratar la licencia comercial de Gym visual y mantener los GIFs.
- **Opción C (statu quo seguro):** mantener los 16 GIFs, aplicar ya la atribución de
  arriba y **no ampliar** el set hasta decidir A o B.

Mientras no haya respuesta, **actúa como si fuera la Opción C.**

---

## 12. OPTIMIZACIÓN DE STORAGE Y BANDWIDTH

**Regla dura: no subas ni un byte de media a Supabase Storage.** Hoy el proyecto tiene
**0 buckets y 0 objetos**, y así debe seguir. Motivos verificados:
1. 1.324 GIFs × ~90 KB ≈ **120 MB** de los 1 GB del plan Free, más egress por cada
   visualización de cada usuario.
2. La app es **offline-first**: un asset remoto rompe esa promesa justo en el gimnasio,
   donde no hay señal.

Arquitectura objetivo, en tres capas — `AnimationRepository` ya la soporta sin cambios
estructurales, solo hay que añadir un proveedor:

1. **Bundle (prioridad 0-10):** subconjunto curado de ~60–80 ejercicios de mayor uso,
   en **WebP animado** (`AnimationType.image` ya existe en el enum). WebP pesa 30–50 %
   menos que el mismo GIF. Presupuesto: **≤ 4 MB añadidos al APK**. Mide antes y después
   con `flutter build apk --analyze-size`.
2. **Descarga bajo demanda (prioridad 20):** crear
   `lib/core/exercise_animation/providers/http_animation_provider.dart`, que implemente
   `ExerciseAnimationProvider`, resuelva la URL desde un manifest y descargue a
   `path_provider.getApplicationSupportDirectory()`. **Cache-first**: si el archivo ya
   está en disco no toca la red; si no hay red, devuelve `null` y deja pasar al
   placeholder. Nunca descargues en bloque: solo el ejercicio que se está mostrando.
3. **Placeholder:** el actual por grupo muscular. Ya funciona, no lo toques.

El **manifest** (`slug → ruta local o URL`) sigue siendo un **asset estático versionado
con el código**, no una tabla. Es dato inmutable e idéntico para todos los usuarios.

---

## 13. OPTIMIZACIÓN PARA SUPABASE FREE

La base de datos **no es el problema**: un año entero de entrenamiento (4 sesiones por
semana × 20 series) son ~4.200 filas y **menos de 2 MB**, contra 500 MB disponibles. El
egress del sync es despreciable porque solo sube deltas marcados `dirty`.

Lo que hay que preservar (y que ya está bien hecho — **no lo rompas**):
- La lectura normal de la app **nunca** pega a Supabase: todo sale de Drift.
- El sync sube solo filas `dirty`, con backoff por conectividad y timer periódico
  configurable desde Ajustes.
- El catálogo y la media son estáticos y no generan tráfico.

Lo único que hay que añadir: aplicar la migración 20260905_0003 (RLS con
`(select auth.uid())`), que reduce el coste por consulta cuando las tablas crezcan.

**Prohibido:** replicar el catálogo de ejercicios en Supabase, subir media a Storage,
habilitar Realtime en tablas de historial, o hacer polling contra la API.

---

## 14. CAMBIOS DE UX/UI

| # | Cambio | Archivo | Cómo |
|---|---|---|---|
| UX1 | El banner de entrenamiento activo no debe tapar nada | `home_shell.dart`, `entrenar_hub_screen.dart` | Ver 22.2 |
| UX2 | Poder descartar un entrenamiento abandonado | `start_workout_screen.dart` | Ver 22.1 |
| UX3 | El FAB "Agregar ejercicio" no debe desaparecer durante el descanso | `active_workout_screen.dart:858` | Quita la condición `_restEndsAt != null ? null : ...`. Si estorba al banner de descanso, desplázalo con `floatingActionButtonLocation` o reduce el FAB a `FloatingActionButton` (solo icono) mientras haya descanso — pero **no lo elimines** |
| UX4 | (A17) Gráfico de racha con datos reales | `dashboard_screen.dart` → `_StreakCard` | `StatsRepository.trainedLast7Days()` **ya existe y ya se está cargando** en `_load()`. Úsalo para las 7 barras (marcada = día entrenado) y añade etiquetas L-M-M-J-V-S-D. Si no queda bien, **elimina el gráfico**: un gráfico decorativo que finge datos es peor que ninguno |
| UX5 | (U1) Pluralización | `dashboard_screen.dart`, `progreso_resumen_tab.dart` | "Racha de 1 día" / "de N días". Busca todos los `${n} días`, `${n} series`, `${n} ejercicios` |
| UX6 | (U18) Un solo nombre | `home_shell.dart` (label "Cuenta") vs `profile_screen.dart` (título "Perfil") | Elige uno y aplícalo en ambos |
| UX7 | (U12) El FAB tapa el último elemento | `exercise_list_screen.dart`, `routine_list_screen.dart`, `history_list_screen.dart` | `padding: EdgeInsets.only(bottom: 96)` en cada `ListView` bajo un FAB. `ActiveWorkoutScreen` ya usa 120, cópialo |
| UX8 | (U17) RPE `0.0` no es un RPE | `active_workout_screen.dart` | Mostrar "–" cuando sea nulo o 0 |
| UX9 | (U11) Placeholder como etiqueta | `profile_screen.dart`, `nutrition_screen.dart`, `recovery_screen.dart`, `routine_builder_screen.dart` | Cambiar `hintText:` por `labelText:` donde el hint sea el nombre del campo |
| UX10 | (A18) Accesibilidad | ~15 archivos | Ver sección 21 |

---

## 15. PANTALLAS A MODIFICAR

`home_shell.dart`, `entrenar_hub_screen.dart`, `start_workout_screen.dart`,
`active_workout_screen.dart`, `dashboard_screen.dart`, `exercise_thumb.dart`,
`exercise_list_screen.dart`, `exercise_picker_screen.dart`,
`workout_summary_screen.dart`, `history_list_screen.dart`,
`exercise_detail_screen.dart`.

## 16. PANTALLAS A FUSIONAR

Ambas requieren confirmación del usuario antes de ejecutarse (son cambios de
navegación visibles). **No las hagas en la Fase 1.**

- **U-F5:** absorber la pestaña **Logros** dentro de **Progreso → Resumen**.
  `ProgresoHubScreen` pasa de 5 a 4 pestañas; el contenido de `GamificationScreen`
  (nivel, XP, medallas) se mueve a `ProgresoResumenTab`. `HomeShell._openProgresoTab`
  usa índices de pestaña: **actualízalos** o romperás la insignia de XP del Dashboard.
- **U-F2:** conectar **Cuerpo → Nutrición** con **Cuerpo → Herramientas → Calculadora
  de nutrición**: la calculadora produce exactamente los objetivos que al registro le
  faltan. Objetivo arriba, consumido del día contra ese objetivo abajo.

## 17. PANTALLAS NUEVAS

**Ninguna.** La app ya tiene 22 pantallas; el problema es profundidad, no superficie.
No crees pantallas nuevas en este trabajo.

## 18. FUNCIONALIDADES NUEVAS (solo P2, tras las fases 1–3)

| Función | Problema que resuelve | Dónde | Datos | Impacto Supabase | Prio |
|---|---|---|---|---|---|
| Descartar entrenamiento abandonado | A1: hoy no hay salida | `StartWorkoutScreen` | ninguno nuevo | ninguno | **P0** |
| `ExerciseSyncable` | A15: los ejercicios propios se pierden al reinstalar | `core/sync/entities/` | tabla `nexfit_custom_exercises` | +1 tabla, tráfico mínimo | **P1** |
| Favoritos y recientes en el picker | Encontrar rápido lo que se usa siempre | `ExercisePickerScreen` | tabla Drift nueva `ExerciseFavorites` | opcional | **P2** |
| Superseries en la UI | La columna `supersetGroupId` existe en la base y solo la usa el importador | `ActiveWorkoutScreen` | ninguno nuevo | ninguno | **P2** |

**No agregues nada más.** Nada de fotos de progreso, notificaciones, base de alimentos,
red social ni plantillas: no están pedidas y la app no las necesita hoy.

## 19. COMPONENTES A CREAR

- `lib/widgets/attribution_footer.dart` — pie de atribución de media, alimentado desde
  `ExerciseAnimation.attribution` (sección 11).
- `lib/core/exercise_animation/providers/http_animation_provider.dart` — solo en la
  Fase 4, y solo si se aprueba la sección 12.

## 20. COMPONENTES A REUTILIZAR (no crees equivalentes)

`EmptyState` (y `EmptyState.error`), `StatTile`, `StepperField`, `PillTabBar`,
`MuscleChip` / `showMuscleGroupFilterSheet`, `ExerciseThumb`,
`ExerciseAnimationViewer`, `RestTimerBanner`, `AppColors`/`AppSpacing`/`AppRadius`/
`AppGlow`, `formatWeight` de `core/units.dart`.

## 20-bis. COMPONENTES A REFACTORIZAR

- `ExerciseThumb` → `StatefulWidget` con el future cacheado (A10).
- `ActiveWorkoutScreen` (1.512 líneas) → extrae `_ExerciseFocusCard` y sus subwidgets a
  `lib/screens/workout/exercise_focus_card.dart`. **Solo movimiento de código, sin
  cambio de comportamiento**, y solo después de que las fases 1–2 estén verdes.
- `ExerciseDetailScreen` (1.113 líneas) → extrae las secciones de ficha técnica.

## 20-ter. COMPONENTES A ELIMINAR (cada uno requiere confirmación)

| Qué | Por qué | Arrastra |
|---|---|---|
| `lib/main_audit.dart` | Archivo temporal de la auditoría anterior | — |
| `lib/features/exercise_3d/` + botón "Ver en 3D" de `exercise_detail_screen.dart:307` | 0 modelos en `assets/models_3d/`; nunca funcionó | `flutter_3d_controller` → `flutter_inappwebview` (rompe el build de Windows) |
| `lib/features/pose/` + `camera` + `google_mlkit_pose_detection` | Oculto tras `kShowPoseAnalysisEntryPoints = false`, sin fecha de activación | 2 plugins nativos |
| Tarjeta "Gemelo Digital" del Dashboard | Siempre "Próximamente" en builds publicados (A14) | alternativa: configurar el secret en CI |

---

## 21. CAMBIOS DE CÓDIGO (accesibilidad, A18)

Solo **2 de 154** archivos usan `Semantics`. `StepperField` ya lo hace bien y sus tests
lo verifican (`test/widgets/stepper_field_test.dart`, casos "D3") — **úsalo de modelo**.

Prioridad, del más al menos importante:
1. Todo `IconButton` sin texto visible necesita `tooltip:` (Flutter lo convierte en
   etiqueta semántica). Busca `IconButton(` sin `tooltip` y añádelo.
2. El check por serie de `ActiveWorkoutScreen` (el círculo grande) debe anunciar
   "Serie N completada / sin completar".
3. Los `InkWell` que hacen de tarjeta clicable (`_StartCard`, `_PickerCard`, el banner
   de entrenamiento activo) necesitan `Semantics(button: true, label: ...)`.
4. Targets táctiles ≥ 48×48: revisa los `IconButton` con `dense: true` y los steppers.

**No** persigas los 154 archivos. Cubre el bucle de entrenamiento (`workout/`),
`exercises/` y `home_shell.dart`; eso es el 80 % del uso real.

---

## 22. INSTRUCCIONES EXACTAS PARA LOS DOS BUGS CRÍTICOS

### 22.1 — A1: el entrenamiento activo no caduca

**Archivo 1: `lib/repositories/active_workout_repository.dart`**

- Añade `Future<void> discard(int sessionId)`: borra la fila de `ActiveWorkoutDrafts`
  **y** la sesión de `WorkoutSessions` (el cascade de Drift ya borra sus `WorkoutSets`).
  Es distinto de `finish()`: descartar no cierra la sesión, la elimina, para que no
  contamine el historial ni las estadísticas.
- Añade `Future<int?> staleSessionId({Duration threshold = const Duration(hours: 6)})`:
  devuelve el `sessionId` del draft **solo si** la sesión existe y
  `DateTime.now().difference(session.startedAt) > threshold`. `null` en cualquier otro
  caso.
- **Corrige `currentSessionId()`**: hoy devuelve `draft?.sessionId` sin comprobar que la
  sesión exista. Si el draft apunta a una sesión inexistente, **borra el draft y
  devuelve `null`** (esto también cierra A3 en el origen). Aplica la misma corrección
  en `watchCurrentSessionId()`.

**Archivo 2: `lib/screens/workout/start_workout_screen.dart`**

- En `_init()` (línea ~36): **deja de hacer `pushReplacement` en silencio**. Si hay
  sesión activa, muestra un `AlertDialog` con tres salidas:
  "Continuar entrenamiento" (comportamiento actual) · "Descartar y empezar uno nuevo"
  (llama `discard()` y sigue el flujo normal) · "Cancelar" (`Navigator.pop`).
  Si `staleSessionId()` devuelve algo, el diálogo debe decir cuántas horas lleva abierta.
- En `_start()`: envuelve la llamada a `begin()` en `try/catch` sobre `StateError` y
  muestra un `SnackBar` en vez de dejar escapar la excepción. Y `setState(() =>
  _starting = false)` en el `catch`, o el botón queda cargando para siempre.

**Archivo 3: `lib/core/local/database.dart`**

- Sube `schemaVersion` a 11 y añade en `onUpgrade` un paso `if (from < 11)` que **borre
  los drafts huérfanos** (`delete from active_workout_drafts where session_id not in
  (select id from workout_sessions)`). Es la migración de datos que limpia las
  instalaciones ya afectadas.

**Test obligatorio** en `test/repositories/active_workout_repository_test.dart`:
`currentSessionId()` devuelve `null` y borra el draft cuando la sesión no existe;
`discard()` elimina sesión y draft; `staleSessionId()` respeta el umbral.

### 22.2 — A2: el banner tapa el FAB

**Archivo: `lib/screens/home/home_shell.dart`**

El `_ActiveWorkoutBanner` está en un `Positioned(bottom: 0)` dentro del mismo `Stack`
que el `IndexedStack`, así que se dibuja encima del FAB de `EntrenarHubScreen`.

Solución **sin cambiar la apariencia**: saca el banner del `Stack` y ponlo en una
`Column` junto al `IndexedStack`, de modo que **ocupe su propio espacio** en lugar de
solaparse:

```dart
body: Column(
  children: [
    Expanded(
      child: IndexedStack(index: _index, children: [ /* ...igual... */ ]),
    ),
    const _ActiveWorkoutBanner(),   // ya devuelve SizedBox.shrink() si no hay sesión
  ],
),
```

`_ActiveWorkoutBanner` ya devuelve `SizedBox.shrink()` cuando no hay sesión activa, así
que sin entrenamiento en curso el layout queda **idéntico al actual**. Verifícalo
comparando con `docs/auditoria/baseline/01-dashboard.png`.

Comprueba después que el FAB de `EntrenarHubScreen` responde con un entrenamiento
activo, y que el banner sigue viéndose sobre las 5 pestañas.

---

## 23. CAMBIOS DE CÓDIGO — RENDIMIENTO

- **(A12)** `lib/screens/workout/workout_summary_screen.dart` → `_loadComparisons`
  llama a `history(muscleGroup:)` **una vez por grupo muscular**, y cada llamada lee
  todas las sesiones + todas las series + todo el catálogo. Sustitúyelo por **una sola**
  consulta que traiga lo necesario y agrupe en memoria. Añade un test que cuente las
  consultas o que verifique el resultado con 5 grupos musculares.
- **(A13)** `lib/repositories/workout_repository.dart` → `history()` ya acepta
  `limit`/`offset` (comentario U3 en el código). Úsalos desde
  `history_list_screen.dart` con scroll infinito o un botón "Cargar más". No cargues
  todo de entrada.
- **(A10, A11)** ya descritos en la sección 11.
- **`ExercisePickerScreen`**: cambia el `ListView(children: [...])` por
  `ListView.builder`, y añade `if (!mounted) return;` antes del `setState` del
  `.then()` de `initState` (T8, pendiente).

---

## 24. MIGRACIONES

| Archivo | Qué hace | Reversible |
|---|---|---|
| `supabase/migrations/20260905_0002_alinear_esquema.sql` | Solo `add column if not exists` + `create table if not exists`. **Nada destructivo** | Sí (`drop column`) |
| `supabase/migrations/20260905_0003_endurecer_rls.sql` | `alter policy` (misma lógica) + `revoke`/`grant`. **No cambia quién ve qué** | Sí |
| Drift `schemaVersion` 10 → 11 | Borra drafts huérfanos. **No toca sesiones ni series** | No aplica (limpieza) |

---

## 25. PLAN DE IMPLEMENTACIÓN POR FASES

Ejecuta **una fase completa a la vez**. Al final de cada una: `flutter analyze --no-pub`
→ `flutter test --no-pub` → resume al usuario qué cambió y qué verificar a mano.

### FASE 1 — Los dos bugs críticos (bloqueante)
1. A1 — sección 22.1 (3 archivos + migración Drift + tests).
2. A2 — sección 22.2 (1 archivo).
3. A3 — queda cubierto por la corrección de `currentSessionId()`; añade además un
   `try/catch` en `ActiveWorkoutScreen._load()` que, ante un fallo, muestre
   `EmptyState.error` con un botón "Volver" en lugar del spinner infinito.

**Criterio de salida:** con un entrenamiento abandonado de días, se puede descartar y
empezar uno nuevo; el FAB "Empezar entrenamiento" responde; ninguna pantalla se queda
en spinner.

### FASE 2 — Seguridad y datos
1. Escribir las dos migraciones SQL (secciones 8 y 9). **No aplicarlas sin el OK.**
2. Pedir al usuario que active leaked-password protection en el panel (A8).
3. A4 — atribución en las miniaturas + plantear las opciones A/B/C de licencia.
4. Verificar que un push a Supabase escribe de verdad: iniciar sesión, registrar una
   serie, forzar `syncNow()` y comprobar que `nexfit_workout_sessions` deja de tener 0
   filas. **Hoy no hay ninguna evidencia de un push exitoso.** Si falla, el error queda
   en `SyncEngine.lastError` y se ve en Ajustes.

### FASE 3 — Rendimiento y limpieza visual
1. A10, A11, A16 (sección 11).
2. A12, A13 y las correcciones del picker (sección 23).
3. UX4, UX5, UX6, UX7, UX8, UX9 (sección 14).

### FASE 4 — Producto (cada punto requiere confirmación)
1. A20 — eliminar visor 3D + `flutter_3d_controller`.
2. A14 — Coach: configurar `SMART_BACKEND_URL` en CI o quitar la tarjeta.
3. A15 — `ExerciseSyncable` + la tabla de la migración 0002.
4. Decidir la licencia de la media y, si es la Opción A, ejecutar la migración de dataset.
5. A23 — borrar `main_audit.dart`. Decidir sobre `features/pose/`.

### FASE 5 — Accesibilidad y refactor
1. A18 (sección 21).
2. Extraer `_ExerciseFocusCard` y las secciones de `ExerciseDetailScreen`.
3. U-F5 y U-F2 (sección 16).

### FASE 6 — Opcional
Arquitectura de assets en 3 capas (sección 12), favoritos, superseries, responsive.

---

## 26. NO HACER CAMBIOS DESTRUCTIVOS SIN JUSTIFICACIÓN

Antes de cualquiera de estas acciones, **detente y pide confirmación explícita**,
indicando riesgo, migración, backup y rollback:

| Acción | Riesgo | Antes de hacerlo |
|---|---|---|
| Aplicar una migración a Supabase producción | Irreversible en datos | Las dos migraciones propuestas son **puramente aditivas**. Aun así, pide el OK |
| `drop`/`rename` de columna o tabla | Pérdida de datos | **Prohibido en este trabajo.** Ninguna mejora lo requiere |
| Cambiar ids de ejercicios | Rompe todas las series ya registradas | **Prohibido.** `mergeExerciseCatalog` ya lo evita a propósito |
| Borrar `features/exercise_3d/` o `features/pose/` | Pérdida de código funcional | Confirmación del usuario |
| Tocar la lógica de las políticas RLS | Exposición de datos entre usuarios | Solo se optimiza la **evaluación**, no el **predicado** |
| `git commit` / `git push` | — | Solo si el usuario lo pide. Autor: Angel. **Nunca** `Co-Authored-By` de IA |

Antes de tocar Supabase, pide un backup: panel → Database → Backups.

---

## 27. TESTS

Suite actual: **196 tests en verde** (`flutter test --no-pub`). Ninguno puede quedar
rojo. Tests **nuevos** obligatorios por fase:

| Fase | Test | Archivo |
|---|---|---|
| 1 | `currentSessionId()` devuelve null y borra el draft si la sesión no existe | `test/repositories/active_workout_repository_test.dart` |
| 1 | `discard()` borra sesión + series + draft | ídem |
| 1 | `staleSessionId()` respeta el umbral de 6 h | ídem |
| 1 | El diálogo de "hay un entrenamiento activo" ofrece las 3 salidas | `test/screens/start_workout_screen_test.dart` |
| 1 | Con sesión activa, el FAB de `EntrenarHubScreen` sigue siendo pulsable | test de widget nuevo sobre `HomeShell` |
| 1 | `ActiveWorkoutScreen` con `sessionId` inexistente muestra error, no spinner | `test/screens/active_workout_screen_test.dart` |
| 2 | La atribución aparece cuando hay media de GymVisual en pantalla | test nuevo sobre `ExerciseListScreen` |
| 3 | `ExerciseThumb` resuelve la animación **una sola vez** ante varios rebuilds | test nuevo con un provider que cuente llamadas |
| 3 | El resumen de entrenamiento produce el mismo resultado con una sola query | `test/screens/` |
| 3 | `history()` paginado devuelve las páginas correctas sin solapamiento | `test/repositories/workout_repository_test.dart` |

**Comprobación manual después de cada fase** (no automatizable):
autenticación · navegación por los 5 destinos y sus pestañas · iniciar/reanudar/
descartar/finalizar entrenamiento · el picker carga los 40 ejercicios · los GIFs se ven
y no perforan el fondo · el fallback aparece en los 24 ejercicios sin GIF · estados
loading/error/empty · sin conexión (modo avión) la app sigue funcionando entera ·
`SyncEngine.lastError` visible en Ajustes · 360 px de ancho y tablet.

---

## 28. CRITERIOS DE ACEPTACIÓN

- [ ] `flutter analyze --no-pub` → 0 errores, 0 warnings (los 11 infos preexistentes son
      tolerables; no añadas ninguno nuevo).
- [ ] `flutter test --no-pub` → 196 tests previos **+ los nuevos**, todos en verde.
- [ ] `flutter build apk --release --dart-define-from-file=env.json` compila.
- [ ] **A1 cerrado:** con un entrenamiento abandonado se puede descartar y empezar uno
      nuevo; el diálogo dice cuánto lleva abierto.
- [ ] **A2 cerrado:** con un entrenamiento activo, el FAB "Empezar entrenamiento"
      responde al toque.
- [ ] **A3 cerrado:** un draft huérfano no produce spinner infinito; se limpia solo.
- [ ] **A4 cerrado:** la atribución "© Gym visual" es visible en **toda** pantalla que
      muestre esa media, y el texto sale de `ExerciseAnimation.attribution`, no
      hardcodeado en la UI.
- [ ] Autenticación funciona; RLS sigue impidiendo ver datos de otros usuarios
      (verificable con `get_advisors` de Supabase: 0 lints de tabla sin RLS).
- [ ] Las dos RPC `SECURITY DEFINER` ya **no** son ejecutables por `anon`.
- [ ] Los 40 ejercicios cargan en el picker; los 16 con GIF lo muestran; los 24 sin GIF
      caen al icono por grupo muscular, no a un hueco.
- [ ] `ExerciseThumb` no re-resuelve la animación en cada rebuild.
- [ ] No se descarga ni se carga ningún asset que no se esté mostrando.
- [ ] Las listas largas usan `ListView.builder` y el historial pagina.
- [ ] Supabase no recibe ninguna consulta durante el uso normal (todo sale de Drift).
- [ ] **0 buckets y 0 objetos** en Supabase Storage.
- [ ] El diseño visual original se conserva: compara contra
      `docs/auditoria/baseline/*.png` y justifica cualquier diferencia.
- [ ] No hay componentes duplicados: nada de un segundo `EmptyState`, `StatTile` o
      tarjeta base.
- [ ] Estados loading / error / empty implementados en cada pantalla tocada.
- [ ] Ninguna funcionalidad existente se rompe.
- [ ] La app funciona en modo avión (offline-first intacto).
- [ ] Ningún secreto en el código ni en git (`git log --all -- env.json` sigue vacío).

---

## 29. CHECKLIST FINAL ANTES DE ENTREGAR

1. [ ] `flutter analyze --no-pub` limpio.
2. [ ] `flutter test --no-pub` todo verde, con los tests nuevos incluidos.
3. [ ] Ninguna migración aplicada a Supabase sin el OK explícito del usuario.
4. [ ] Ninguna eliminación de código hecha sin confirmación.
5. [ ] `env.json` sigue sin commitear.
6. [ ] Sin `git commit` / `git push` no pedidos.
7. [ ] Resumen final al usuario: qué se cambió, qué archivo, qué falta, qué decisiones
       quedan pendientes de su respuesta (licencia de la media, Coach en CI, visor 3D,
       pose, fusiones de pantallas).
