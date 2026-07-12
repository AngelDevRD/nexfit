# NexFit — Arquitectura objetivo y plan de migración del backend

Decisión arquitectónica: **la app debe poder publicarse y usarse por completo sin depender
de un backend FastAPI desplegado.** El backend queda reservado solo para lo que
técnicamente no puede vivir en el cliente ni en Supabase (Coach IA / tool-calling).

Este documento es la fuente de verdad de esa decisión. Actualizarlo cada vez que una fase
del plan avance, para que ninguna sesión futura tenga que re-analizar la arquitectura desde
cero. Ver también [SEGURIDAD_Y_EFICIENCIA.md](./SEGURIDAD_Y_EFICIENCIA.md) (checklist de
hardening, complementario a este documento).

---

## 1. Arquitectura actual

```
Flutter (Drift local + Provider)
        │  Bearer JWT
        ▼
FastAPI (SQLAlchemy, 12 routers)
        │
        ▼
Postgres (hosteado en Supabase, solo como DB gestionada)
```

- **Auth**: 100% FastAPI (`lib/services/auth_service.dart` → `/api/v1/auth/register|login`,
  `/api/v1/users/me`). No hay `supabase_flutter` en `pubspec.yaml`, no hay Supabase Auth, no
  hay recuperación de contraseña propia — todo pasa por el JWT que emite FastAPI
  (`backend/app/core/security.py`).
- **Offline-first parcial**: ya existe una base sólida en `lib/core/local/database.dart`
  (Drift) y `lib/core/sync/` (`SyncEngine` + contrato `SyncableEntity`). Rutinas
  (`RoutineSyncable`) y entrenamientos (`WorkoutSessionSyncable`) ya se guardan localmente
  primero y se suben con flag `dirty` cuando hay red — si el backend no responde, el push
  falla en silencio y se reintenta en la siguiente pasada, sin romper la UI. Goals,
  nutrición, recovery y social **no** están wireados al `SyncEngine` todavía: sus servicios
  llaman directo a FastAPI sin fallback local.
- **Hallazgo clave**: el proyecto Supabase para esta app **ya existe** (`AppGym`,
  `vywkyuuuxpovoevwdewh`, creado 2026-07-04). Hoy se usa **únicamente como Postgres
  gestionado** detrás de SQLAlchemy. Auth y el cliente PostgREST/Supabase **no** están en
  uso desde el cliente. Migrar a "Supabase" en este proyecto no es agregar infraestructura
  nueva — es empezar a consumir la infraestructura que ya está pagada y corriendo, en vez
  de solo usarla como disco duro de FastAPI.
  - **Corrección respecto a `SEGURIDAD_Y_EFICIENCIA.md`** (confirmado en Fase 0 vía MCP de
    Supabase, `list_tables`/`get_advisors`): RLS **ya está activado** en las 13 tablas de la
    app (`exercises`, `users`, `daily_checkins`, `goals`, `nutrition_logs`, `routines`,
    `routine_days`, `routine_exercises`, `workout_sessions`, `workout_sets`,
    `personal_records`, `challenges`, `challenge_participants`) — el checklist de
    hardening estaba desactualizado en ese punto. Falta activarlo solo en
    `public.alembic_version` (tabla interna de migraciones de Alembic, sin datos de
    usuario; advisory `critical` por exposición vía `anon key`, pendiente de decisión del
    usuario — no se aplicó automáticamente). Ninguna de las 13 tablas tiene **policies**
    todavía (RLS activo sin policies = deniega todo por defecto), así que escribirlas es
    trabajo real de la Fase 2, no algo ya resuelto.
- **Coach IA** (`lib/services/coach_service.dart` → `backend/app/routes/v1/coach.py` +
  `services/llm_client.py` + `services/digital_twin.py`): el único dominio que
  genuinamente necesita un servidor — sostiene la API key de Groq y orquesta tool-calling
  sobre datos agregados del usuario. No se puede mover al cliente ni a Supabase tal cual.
- **Bug ya identificado, sin corregir**: `lib/core/app_config.dart` apunta por defecto a
  `http://10.0.2.2:8000` (loopback de emulador) y el workflow de release no inyecta
  `--dart-define=API_BASE_URL`, por lo que el APK pública no puede hoy iniciar sesión.
  Este plan lo resuelve de raíz (elimina la dependencia dura del login hacia ese backend)
  en vez de solo parchear la URL.

## 2. Arquitectura objetivo

```
┌─────────────────────────────┐
│ Flutter (Drift + Provider)  │  ← funciona 100% solo, offline-first
│  UI · lógica local · sync   │
└───────────┬─────────────────┘
            │
   ┌────────┴─────────┐
   ▼                   ▼
Supabase          Backend inteligente (opcional)
Auth + Postgres    Coach IA / chat / tool-calling
+ RLS + Storage    (FastAPI adelgazado o Edge Function)
```

- **Cliente Flutter**: dueño de la experiencia. Debe arrancar, autenticar, y operar
  rutinas/entrenamientos/objetivos/nutrición sin que exista ningún servicio inteligente
  desplegado.
- **Supabase**: sustituye a FastAPI+SQLAlchemy para todo lo que es CRUD por usuario o
  multiusuario simple, usando Auth + RLS en vez de JWT casero + `WHERE user_id = ...` a mano.
- **Backend inteligente**: servicio aparte, **opcional en runtime**. Si no está configurado
  o no responde, la app lo detecta y degrada esa función puntual sin afectar al resto.

### 2.1 Clasificación por dominio

| Dominio | Destino | Por qué |
|---|---|---|
| Auth (registro, login, recuperar contraseña) | **Supabase Auth** | Ya es su función nativa; no requiere secretos de servidor propio. |
| Rutinas (`RoutineSyncable`, `routine_service.dart`) | **Supabase** | CRUD por usuario; ya offline-first vía `SyncEngine` — solo cambia el destino del `push()`. |
| Entrenamientos (`WorkoutSessionSyncable`, `workout_service.dart`) | **Supabase** | Igual que rutinas. |
| Objetivos (`goal_service.dart`) | **Supabase** | CRUD simple, hoy sin fallback offline — se gana offline-first de regalo. |
| Nutrición (`nutrition_service.dart`) | **Supabase** | Igual. |
| Recovery (`recovery_service.dart`) | **Supabase** | Igual. |
| Social / retos (`social_service.dart`) | **Supabase** | El leaderboard es multiusuario pero es una consulta agregada normal — resoluble con una vista o función RPC de Postgres, sin secretos. |
| Backup/exportación (`data_transfer_service.dart`) | **Supabase** (Storage o export directo de las tablas del usuario) | No depende de lógica privada. |
| Calendario (`calendar_service.dart`) | **Supabase** | CRUD simple. |
| Catálogo de ejercicios (`exercise_service.dart`) | **On-device** | Ya vive en `assets/data/exercises.json`; cortar cualquier llamada de red residual. |
| Calculadoras (`calculator_service.dart`) | **On-device** | Matemática pura, sin estado remoto. |
| Estadísticas (`stats_service.dart`) | **On-device** | Se recalculan desde las tablas Drift ya locales (rutinas/entrenamientos). |
| Gamificación (`gamification_service.dart`) | **On-device** | Igual — cálculo puro sobre datos ya locales. |
| Coach IA / chat / tool-calling (`coach_service.dart`) | **Backend inteligente** | Necesita sostener la API key del LLM y orquestar llamadas — no puede exponerse al cliente. |

## 3. Comportamiento cuando el backend inteligente no existe

Componentes nuevos (a construir en la Fase 0, sin tocar pantallas todavía):

- `lib/core/smart_backend_availability.dart`: expone `bool get isConfigured` (verdadero
  solo si `--dart-define=SMART_BACKEND_URL` no viene vacío) y, opcionalmente, un healthcheck
  best-effort con timeout corto y caché en memoria por sesión.
- `lib/widgets/coming_soon_view.dart`: pantalla/mensaje reusable ("Próximamente" — mismo
  texto que ya redactó el usuario) para reemplazar cualquier error técnico cuando
  `!isConfigured` o cuando la llamada al backend inteligente falla en runtime.
- Regla de integración: **ninguna pantalla nueva llama directo a `coach_service.dart`** —
  siempre pasa primero por `SmartBackendAvailability.isConfigured`. Si es falso, se
  renderiza `ComingSoonView` en vez de construir el widget real. Si es true pero la llamada
  falla en runtime (backend caído), el mismo widget captura la excepción y muestra el
  mismo mensaje — nunca una excepción cruda ni pantalla en blanco.
- Las pantallas, rutas de navegación, modelos y contratos de Coach IA **se mantienen
  intactos** — esto es solo una capa de guarda delante, no una eliminación de feature.

## 4. Plan de migración por fases

Cada fase es desplegable y verificable por separado; ninguna deja la app en un estado
peor que el anterior.

### Fase 0 — Fundaciones (sin cambio visible para el usuario) ✅ completada 2026-07-11
- ✅ Agregado `supabase_flutter: ^2.8.0` a `pubspec.yaml` (resuelto en `2.16.0`, sin
  conflictos con las demás dependencias).
- ✅ Proyecto Supabase `AppGym` (`vywkyuuuxpovoevwdewh`) reactivado — estaba `INACTIVE`
  (pausado por inactividad), ahora `ACTIVE_HEALTHY`. RLS ya estaba activo en las 13 tablas
  (ver corrección en la sección 1); no se tocaron policies ni esquema.
- ✅ `lib/core/supabase_config.dart`: URL y publishable key del proyecto, con override por
  `--dart-define=SUPABASE_URL`/`SUPABASE_PUBLISHABLE_KEY` para builds de otro entorno.
- ✅ `Supabase.initialize(...)` llamado en `main()` (`lib/main.dart`), envuelto en
  `try/catch` — si falla, se loguea y la app sigue arrancando igual que antes. Ninguna
  pantalla ni provider consume `Supabase.instance.client` todavía.
- ✅ `lib/core/smart_backend_availability.dart`: `SmartBackendAvailability.isConfigured` /
  `.baseUrl`, basado en `--dart-define=SMART_BACKEND_URL`. Sin consumidores todavía.
- ✅ `lib/widgets/coming_soon_view.dart`: widget reusable con el texto "Próximamente"
  acordado. Sin consumidores todavía.
- ✅ Corregido de paso un test roto pre-existente (`test/widget_test.dart` esperaba el
  texto `"AppGym"`, pero el rebrand a `"NexFit"` del commit `d66fb78` nunca actualizó el
  test) — no relacionado con Supabase, detectado al correr la suite completa como
  verificación de esta fase.
- **Verificado**: `flutter analyze lib/` → *No issues found!* · `flutter test` → 12/12 ✅ ·
  `flutter build apk --release` → build exitoso (47.4MB). Cero cambios de comportamiento:
  auth, sync, y todos los servicios siguen usando exclusivamente `ApiClient`/FastAPI, tal
  como antes de esta fase.

### Fase 1 — Auth a Supabase (desbloquea publicar ya) ✅ completada 2026-07-11
- ✅ **Interfaz `AuthRepository`** (`lib/core/auth/auth_repository.dart`): contrato único
  de sesión/identidad (`restoreSession`, `authStateChanges`, `currentUser`, `register`,
  `login`, `logout`, `resetPassword`). `AuthProvider` y las pantallas dependen solo de esta
  interfaz — no importan Supabase en ningún punto.
- ✅ **`SupabaseAuthRepository`** (`lib/core/auth/supabase_auth_repository.dart`):
  implementación real sobre `supabase_flutter`. Persistencia de sesión y renovación
  automática de token las maneja el propio paquete (configurado en Fase 0); esta clase
  solo traduce la API de Supabase al contrato de la app.
- ✅ **`UnavailableAuthRepository`** (`lib/core/auth/unavailable_auth_repository.dart`):
  fallback si `Supabase.initialize` falla en `main()` — todas las acciones fallan con un
  mensaje claro en vez de crashear el arranque (antes de esta fase, un fallo de Supabase
  no importaba porque nada lo usaba; ahora sí, así que se cerró ese hueco).
- ✅ **`AuthProvider` reescrito** (`lib/providers/auth_provider.dart`) para recibir un
  `AuthRepository` inyectado en vez de construir `AuthService` directamente. Se suscribe a
  `authStateChanges` para reflejar logout/expiración de sesión disparados por el propio
  SDK de Supabase, no solo por acciones iniciadas desde la UI.
- ✅ **`AppUser.id`**: cambiado de `int` a `String` (antes solo servía el id numérico de
  FastAPI; ahora también puede ser un UUID de Supabase). Sin otros consumidores del campo
  en el resto del código — cambio de bajo riesgo, confirmado por grep antes de aplicarlo.
- ✅ **Recuperar contraseña** conectada de verdad: el botón "¿Olvidaste tu contraseña?" en
  `login_screen.dart` (antes un stub de "próximamente") ahora abre un diálogo y llama a
  `AuthProvider.resetPassword`, que dispara `supabase.auth.resetPasswordForEmail`.
- ✅ **`main.dart`**: `Supabase.initialize` ahora decide qué `AuthRepository` se inyecta
  (`SupabaseAuthRepository` si funcionó, `UnavailableAuthRepository` si falló) y se pasa a
  `AppGymApp` por constructor en vez de crearlo dentro de `initState`.
- **Explícitamente NO tocado en esta fase**: `lib/services/auth_service.dart` (register/
  login/me contra FastAPI) queda intacto en el repo tal cual — ya no lo llama nadie desde
  `AuthProvider` excepto `updateProfile` (perfil extendido, ver sección 5.1), pero el
  código no se borró, solo se desacopló.
- **Verificado**: `flutter analyze lib/ test/` → *No issues found!* · `flutter test` →
  12/12 ✅ · `flutter build apk --release` → build exitoso (47.4MB). No se probó en un
  emulador/dispositivo real porque este entorno no tiene uno disponible — falta una
  verificación manual del flujo completo (registrar, cerrar sesión, recuperar contraseña)
  en un dispositivo antes de considerar esto probado end-to-end.
- **Punto abierto, sin decidir todavía**: si el proyecto Supabase tiene activado "Confirm
  email" (configuración del dashboard, no verificable con las herramientas usadas en esta
  fase), `register()` crea el usuario pero no deja sesión activa hasta que confirme por
  correo — el código ya contempla ese caso (`status` queda en `unauthenticated` si
  `currentUser` es null tras el signUp), pero no se decidió ni se comunicó explícitamente
  al usuario qué UX se espera en ese caso (hoy simplemente vuelve a la pantalla de login
  sin ningún mensaje).

### Fase 2 — Perfil + dominios de datos a Supabase ✅ completada 2026-07-12
Alcance ampliado por decisión explícita del usuario: el perfil extendido (edad, sexo,
altura, peso, objetivo, experiencia) se migra junto con rutinas/entrenamientos/objetivos/
nutrición/recovery en esta misma fase, en vez de quedar como módulo aparte — para no
terminar con login en Supabase, perfil en FastAPI y rutinas en Supabase al mismo tiempo.

- ✅ **Esquema Supabase**: tabla nueva `profiles` (uuid = id del propio usuario de Supabase
  Auth) + `routines`/`routine_days`/`routine_exercises`/`workout_sessions`/`workout_sets`/
  `personal_records`/`goals`/`nutrition_logs`/`daily_checkins`/`challenges`/
  `challenge_participants` recreadas con `id uuid default gen_random_uuid()` y
  `user_id uuid references auth.users(id)` (antes `int` referenciando la tabla propia de
  FastAPI). Las 13 tablas estaban en 0 filas — confirmado de nuevo justo antes de aplicar
  las migraciones — así que el `drop`+`create` no perdió ningún dato real.
- ✅ **RLS en las 11 tablas nuevas**: activado desde la creación, con policies
  `auth.uid() = user_id` (o el equivalente vía join para las tablas hijas como
  `routine_days`/`workout_sets`). `challenges`/`challenge_participants` usan una policy más
  estricta (solo participantes ven el reto) más dos funciones Postgres `security definer`
  (`join_challenge_by_code`, `challenge_leaderboard`) para las dos operaciones que
  necesitan cruzar datos de otros usuarios — RLS bloquea esa lectura a propósito desde el
  cliente directo, así que esas dos funciones son el único punto controlado de excepción.
- ✅ **Drift**: `schemaVersion` 3→4. `serverId` de `Routines`/`WorkoutSessions`/`WorkoutSets`/
  `PendingSetOps.serverSetId` pasa de `int` a `text` (uuid); la migración descarta
  explícitamente los valores viejos (apuntaban a un backend que ya no existe) y remarca
  esas filas `dirty` para resincronizar contra el esquema nuevo — los datos de negocio
  (nombres, sets, reps, fechas) no se tocan. Tablas nuevas: `Profiles`, `Goals`,
  `NutritionLogs`, `DailyCheckins`.
- ✅ **Repositorios offline-first nuevos** (mismo patrón que `RoutineRepository`, ya
  existente): `ProfileRepository`, `GoalRepository`, `NutritionRepository`,
  `RecoveryRepository`. `AuthProvider` ahora combina identidad (Supabase Auth, Fase 1) +
  perfil (`ProfileRepository`, local) en el mismo `AppUser` que ya consumía
  `profile_screen.dart` — esa pantalla no se tocó.
- ✅ **`RoutineSyncable`/`WorkoutSessionSyncable` reescritas** para Supabase (antes
  FastAPI/`ApiClient`) — `SyncEngine` no se tocó, sigue sin saber qué backend hay detrás.
- ✅ **Nuevos**: `ProfileSyncable`, `GoalSyncable`, `NutritionSyncable`, `RecoverySyncable`
  (offline-first real por primera vez para estos 4 dominios — antes llamaban directo a
  FastAPI sin ningún fallback local).
- ✅ **Social, excepción explícita**: `SocialRepository` reemplaza a `SocialService`
  hablando directo con Supabase (incluyendo las dos funciones `security definer`), sin
  tabla Drift ni sync offline — es la excepción acordada, la fuente de verdad sigue siendo
  Supabase en vivo.
- **No se tocó** ningún archivo de `backend/` (FastAPI) ni se borró `lib/services/
  goal_service.dart`/`nutrition_service.dart`/`recovery_service.dart`/`social_service.dart`
  (quedan sin usar, igual que `auth_service.dart` desde la Fase 1) — solo se restauraron
  sus `fromJson` en los modelos (`Goal`, `NutritionLog`, `RecoveryIndex`, `ChallengeSummary`,
  `ChallengeDetail`, `LeaderboardEntry`) porque seguían siendo válidos y usados por ese
  código legacy.
- **Simplificaciones documentadas, no ocultas** (ver sección 5.4).
- **Verificado**: `flutter analyze lib/ test/` → *No issues found!* · `flutter test` →
  12/12 ✅ · `flutter build apk --release` → build exitoso (47.5MB) · Security Advisor
  (`get_advisors(security)`) revisado antes y después — ver sección 5.5.

### Fase 3 — Dominios 100% on-device (dividida en sub-fases por su tamaño real)

#### Fase 3a — Récords personales, progreso de objetivos y factor de carga de recovery ✅ completada 2026-07-12
- ✅ **Récords personales**: ya se calculaban on-device desde antes de esta fase
  (`WorkoutRepository._checkPersonalRecords`, escribe en la tabla local `PersonalRecords`
  al agregar un set) — lo que faltaba era leerlos de vuelta, no calcularlos.
- ✅ **`GoalRepository`**: `_currentValueFor`/`_toGoal` replican `get_current_value`/
  `compute_goal_progress` de `backend/app/services/goals.py`, leyendo `Profiles` (peso/
  %grasa) o `PersonalRecords` (máximos por ejercicio) locales. Se corrigió de paso un bug
  de la Fase 2: `create()` fijaba `startingValue = 0` siempre; ahora usa el valor actual
  del usuario al crear el objetivo, igual que FastAPI.
- ✅ **`RecoveryRepository._weeklyLoadScore`**: replica el tercer factor de
  `compute_recovery_index` (`backend/app/services/recovery.py`) — tonelaje de esta semana
  vs. promedio de las 4 anteriores, leyendo `WorkoutSessions`/`WorkoutSets` locales.
  Reemplaza el valor neutro fijo (`load_score = 100`) de la Fase 2.
- ✅ **Tests nuevos** (`test/repositories/goal_repository_test.dart`,
  `recovery_repository_test.dart`): verifican los cálculos con casos concretos (objetivo de
  peso corporal, objetivo de fuerza con récord parcial y alcanzado, sobrecarga de tonelaje
  que baja el factor de carga a 0) — no solo que compile, que el número sea el esperado.
- **Verificado**: `flutter analyze lib/ test/` → *No issues found!* · `flutter test` →
  19/19 ✅ (7 nuevos) · `flutter build apk --release` → build exitoso (47.5MB).
- **Fuera de esta sub-fase, sin tocar**: catálogo de ejercicios (sigue usando
  `ExerciseService`/`ApiClient`), calculadoras (no verificadas si ya eran locales),
  estadísticas de `stats_service.dart` (volumen muscular, perfil de fuerza, progreso por
  ejercicio, tonelaje histórico, racha, estándares de fuerza, predicción de récords) y
  gamificación (`gamification_service.dart`) — quedan para 3b/3c.

#### Fase 3b — Estadísticas (`stats_service.dart`) ✅ completada 2026-07-12
- ✅ **`StatsRepository`** (nuevo, `lib/repositories/stats_repository.dart`): port directo
  de los 7 cálculos de `backend/app/services/stats.py` +
  `backend/app/services/strength_standards.py` + `backend/app/services/predictions.py` —
  volumen muscular (con el mismo ranking relativo alto/medio/bajo/muy_bajo), perfil de
  fuerza (máximos por ejercicio + volumen/frecuencia semanal), progreso por ejercicio,
  tonelaje histórico (semanal/mensual, con la misma lógica de floor-division para el
  bucketing de meses), racha de entrenamiento, estándares de fuerza (mismos umbrales de
  `backend/app/data/strength_standards.py`, portados tal cual) y predicción de récords
  (misma regresión lineal por mínimos cuadrados). Todo lee `WorkoutSessions`/
  `WorkoutSets`/`PersonalRecords`/`Profiles`/`Exercises` locales, sin red.
- ✅ Las 5 pestañas de `StatsHubScreen` + `DashboardScreen` (racha) migradas de
  `StatsService`/`ApiClient` a `StatsRepository` vía Provider.
- ✅ **Tests nuevos** (`test/repositories/stats_repository_test.dart`, 6 casos): niveles de
  volumen relativos entre 3 grupos musculares, orden y máximos de progreso por ejercicio,
  racha con corte en el primer salto de días, ratio/percentil de estándares de fuerza,
  predicción de récord con regresión lineal y su rechazo con menos de 3 puntos.

#### Fase 3c — Gamificación + catálogo de ejercicios + calculadoras ✅ completada 2026-07-12
- ✅ **`GamificationRepository`** (nuevo): port directo de
  `backend/app/services/gamification.py` (XP por sesión/serie/récord/racha, niveles,
  bandas, los 6 logros) leyendo las mismas tablas locales que `StatsRepository` (reutiliza
  su `streak()`). Como Drift es de un solo usuario, no hace falta filtrar por `user_id`
  como en FastAPI. `GamificationScreen` + `DashboardScreen` migradas.
- ✅ **`ExerciseRepository`** (nuevo): el catálogo ya vivía completo en
  `Exercises.detailJson` desde que se sembró offline (`seedExercisesIfEmpty`) — esto solo
  cortó la llamada de red residual que `exercise_list_screen.dart`/
  `exercise_detail_screen.dart` seguían haciendo contra `ExerciseService`/`ApiClient` pese a
  que el dato ya estaba en el dispositivo (`exercise_picker_screen.dart` ya lo hacía bien
  desde antes y sirvió de referencia).
- ✅ **Calculadoras**: la verificación encontró que en realidad *no* eran locales — las 4
  pantallas (1RM, IMC/masa magra, nutrición, ritmo de pérdida de grasa) llamaban a
  `CalculatorService`/`ApiClient` pese a que el propio backend las servía con `auth: false`
  (funciones puras del input del usuario, sin depender de historial ni sesión). Se creó
  `lib/core/calculators.dart` (port directo y sin estado de
  `backend/app/services/calculators.py`) y se migraron las 4 pantallas.
- ✅ **Tests nuevos** (`test/core/calculators_test.dart`, 6 casos) y
  (`test/repositories/gamification_repository_test.dart`, 2 casos): fórmulas de 1RM/IMC/masa
  magra/nutrición/ritmo de pérdida verificadas con valores concretos; XP/nivel/logros
  verificados con un perfil sin actividad y uno con 5 sesiones + récord + racha.
- ✅ **Criterio de éxito de la Fase 3 completa**: estas pantallas (estadísticas, logros,
  catálogo de ejercicios, calculadoras) funcionan sin red y sin sesión Supabase activa
  (offline puro) — confirmado por grep: cero importadores de `StatsService`,
  `GamificationService`, `ExerciseService` o `CalculatorService` en todo `lib/screens/` y
  `lib/core/`. La sincronización se sigue usando solo para compartir resultados entre
  dispositivos (vía `PersonalRecords`/`Profiles` ya sincronizados en la Fase 2), no para
  hacer ningún cálculo.
- **Verificado**: `flutter analyze lib/ test/` → *No issues found!* · `flutter test` →
  33/33 ✅ (14 nuevos entre 3b y 3c) · `flutter build apk --release` → build exitoso
  (47.6MB).

### Fase 4 — Backend inteligente aislado y opcional
- Adelgazar FastAPI a solo lo que sostiene Coach IA (`coach`, `llm_client`,
  `digital_twin`) — evaluar en esa fase si conviene mantenerlo como servicio propio o
  migrarlo a una Supabase Edge Function (Deno) para no operar dos despliegues distintos.
  Esta decisión queda abierta para cuando se llegue a esta fase.
- Conectar `coach_service.dart` a `SmartBackendAvailability`/`ComingSoonView` (sección 3).
- **Criterio de éxito**: con `SMART_BACKEND_URL` vacío, el Coach muestra "Próximamente" sin
  romper nada más; con la URL configurada, funciona igual que hoy.

### Fase 5 — Cutover de CI y limpieza
- CI de release: `SUPABASE_URL`/`SUPABASE_ANON_KEY` pasan a ser obligatorios;
  `SMART_BACKEND_URL` queda opcional (vacío hasta que se despliegue la Fase 4).
- Eliminar el default `10.0.2.2:8000` de `app_config.dart` y el código de `ApiClient` que ya
  no tenga consumidores.
- **Criterio de éxito**: build de release público, funcional de punta a punta sin ningún
  backend propio desplegado.

## 5. Estado de implementación

| Fase | Estado | Fecha |
|---|---|---|
| 0 — Fundaciones | ✅ Completada | 2026-07-11 |
| 1 — Auth a Supabase | ✅ Completada | 2026-07-11 |
| 2 — Perfil + rutinas + entrenamientos + objetivos + nutrición + recovery a Supabase | ✅ Completada | 2026-07-12 |
| 3a — Récords personales + progreso de objetivos + factor de carga de recovery | ✅ Completada | 2026-07-12 |
| 3b — Estadísticas (`stats_service.dart`) | ✅ Completada | 2026-07-12 |
| 3c — Gamificación + catálogo de ejercicios + calculadoras | ✅ Completada | 2026-07-12 |
| 4 — Backend inteligente aislado | ✅ Completada (backend + integración Flutter) | 2026-07-12 |
| 5 — Cutover de CI y limpieza | 🟡 En progreso — Bloque 1 (migrar calendario + export/import) y Bloque 2 (eliminar `ApiClient`/`*_service.dart`/`AppConfig`) completados; pendiente archivar/eliminar `backend/` y limpieza de CI | Bloque 1: 2026-07-12 · Bloque 2: 2026-07-12 |

### 5.1 Qué ya usa Supabase

- **Identidad/sesión** (Fase 1): registro, login, logout, recuperar contraseña,
  persistencia y renovación automática de sesión — `AuthRepository`.
- **Perfil** (`profiles`): edad, sexo, altura, peso, %grasa, objetivo, experiencia —
  offline-first vía `ProfileRepository` + `ProfileSyncable`, combinado en `AuthProvider`.
- **Rutinas y entrenamientos** (`routines`, `routine_days`, `routine_exercises`,
  `workout_sessions`, `workout_sets`, `personal_records`) — mismo `SyncEngine` de antes,
  destino reescrito de FastAPI a Supabase.
- **Objetivos** (`goals`), **nutrición** (`nutrition_logs`), **recovery**
  (`daily_checkins`) — offline-first nuevo, antes llamaban directo a FastAPI sin ningún
  fallback local.
- **Social** (`challenges`, `challenge_participants`) — excepción explícita: lectura/
  escritura directa a Supabase sin Drift, la fuente de verdad es siempre el servidor.

### 5.2 Qué sigue dependiendo de FastAPI

- **Coach IA** (`coach_service.dart` → `backend/app/routes/v1/coach.py` +
  `services/llm_client.py` + `services/digital_twin.py`): sin tocar, como estaba previsto
  — es el único dominio reservado para la Fase 4.
- **Calendario, exportación de datos** (`calendar_service.dart`,
  `data_transfer_service.dart`): no estaban en el alcance explícito de esta fase (el
  usuario los dejó fuera de la lista de dominios de Fase 2); siguen apuntando a FastAPI sin
  cambios y sin verificar todavía si funcionan (ver 5.4).
- **`lib/services/{auth,goal,nutrition,recovery,social,stats,gamification,exercise,
  calculator}_service.dart` (FastAPI)**: código intacto, sin borrar, ya desconectado de
  toda pantalla real (verificado con grep: cero importadores en `lib/screens/` ni
  `lib/core/`). Se restauraron los `fromJson` en los modelos (`Goal`, `NutritionLog`,
  `RecoveryIndex`, `ChallengeSummary`, `ChallengeDetail`, `LeaderboardEntry`) que
  `social_service.dart` sigue necesitando para compilar, aunque nada lo llame.

### 5.3 Qué se migró en la Fase 3b/3c (completo, ver 5.4)

Estadísticas (`StatsRepository`: volumen muscular, perfil de fuerza, progreso por
ejercicio, tonelaje histórico, racha, estándares de fuerza, predicción de récords),
gamificación (`GamificationRepository`), catálogo de ejercicios (`ExerciseRepository`,
cortó la llamada de red residual) y calculadoras (`lib/core/calculators.dart` — no eran
locales como se asumía, ahora sí).

### 5.4 Simplificaciones de la Fase 2 — resueltas en las Fases 3a/3b/3c

- **Progreso de objetivos**: ✅ resuelto. `GoalRepository` ahora calcula
  `currentValue`/`progressPct`/`achieved` de verdad, leyendo `PersonalRecords` (récords ya
  se calculaban on-device desde antes de la Fase 2, solo no se leían de vuelta) y
  `Profiles` locales — réplica de `compute_goal_progress` en FastAPI. Se corrigió además
  un bug real de la Fase 2: `create()` fijaba `startingValue = 0` siempre en vez del valor
  actual del usuario al crear el objetivo.
- **Índice de recovery**: ✅ resuelto. `RecoveryRepository._weeklyLoadScore` calcula el
  tercer factor (tonelaje de esta semana vs. promedio de las 4 anteriores) leyendo
  `WorkoutSessions`/`WorkoutSets` locales — réplica de `compute_recovery_index` en
  FastAPI. Ya no usa el valor neutro fijo.
- **Estadísticas y gamificación**: ✅ resuelto (Fase 3b/3c). `StatsRepository`/
  `GamificationRepository` reemplazan por completo a `StatsService`/`GamificationService`.
- **Catálogo de ejercicios y calculadoras**: ✅ resuelto (Fase 3c). Se asumía que ya eran
  locales (el catálogo lo era desde el seed inicial, las calculadoras no) — ambos casos
  quedaron corregidos con `ExerciseRepository`/`lib/core/calculators.dart`.
- **`join`/`leave`/`remove` de retos y el leaderboard** siguen dependiendo de dos
  funciones Postgres `security definer` (`join_challenge_by_code`, `challenge_leaderboard`)
  — es el diseño correcto (Social es la excepción acordada), no una simplificación
  pendiente de resolver.

### 5.5 Security Advisor

Revisado antes y después de aplicar las migraciones (`get_advisors(type: security)`):

- **2 findings `INFO`, preexistentes, no introducidos por esta fase**: `public.exercises`
  y `public.users` tienen RLS activo sin policies (deniega todo por defecto — es el lado
  seguro, no una tabla expuesta). Son las tablas propias de FastAPI que esta fase
  explícitamente no tocó.
- **2 findings `WARN` encontrados y corregidos en el momento**: las dos funciones
  `security definer` (`join_challenge_by_code`, `challenge_leaderboard`) se crearon con
  `EXECUTE` otorgado a `PUBLIC` por defecto (comportamiento estándar de Postgres al crear
  una función), lo que las hacía invocables por el rol `anon` sin sesión. Corregido con
  `revoke ... from public` + `grant ... to authenticated` — verificado con un segundo
  `get_advisors` que el hallazgo para `anon` desapareció.
- **2 findings `WARN` restantes, revisados y aceptados a propósito**: las mismas dos
  funciones siguen figurando como "el rol `authenticated` puede ejecutarlas" — eso es
  exactamente su propósito (todo usuario logueado necesita poder unirse a un reto o ver un
  leaderboard). No es un hallazgo pendiente, es el diseño; cada función valida membresía
  del caller (`auth.uid()`) antes de devolver o modificar cualquier dato.

### 5.6 Auditoría de consolidación (2026-07-12, previa a la Fase 3)

Antes de dar la Fase 2 por cerrada del todo se auditaron, con evidencia (no solo lectura de
código), cuatro puntos:

**a) Ciclo de vida de sync, entidad por entidad** — las 7 entidades (`Profiles`,
`Routines`, `WorkoutSessions`, `WorkoutSets`, `Goals`, `NutritionLogs`, `DailyCheckins`)
siguen `crear/modificar local → dirty=true (default de columna o explícito en la
mutación) → SyncEngine.syncNow() las recoge automáticamente (listener de conectividad +
timer de respaldo, sin cambios desde antes de la Fase 2) → push() al destino → dirty=false
si tuvo éxito`. Hay **tres formas** de `push()`, cada una con una razón concreta, no
arbitraria:
  - *Create-or-delete* (`Routines`, `Goals`): la UI nunca edita después de crear, así que
    no hace falta soportar diff.
  - *Upsert por clave natural* (`Profiles` por `id`=usuario; `NutritionLogs`/
    `DailyCheckins` por fecha): son dominios de "una fila por \[usuario\|día\]", no hay
    concepto de "borrar" en la UI actual.
  - *Create + cola de operaciones incrementales* (`WorkoutSessions`/`WorkoutSets` vía
    `PendingSetOps`): es el único dominio donde la UI sí edita/borra ítems hijos
    (sets) después de sincronizados, así que necesita un diff granular en vez de
    reenviar el árbol completo. `WorkoutSets` en particular **no tiene columna `dirty`
    propia** — su sync se rastrea enteramente vía `PendingSetOps`, que es la diferencia de
    diseño real y ya estaba documentada en el código antes de esta fase (no la introduje).
  - **Política de conflictos, uniforme en las tres formas**: last-write-wins sin merge —
    el último `push()` exitoso sobrescribe lo que hubiera en el servidor. No hay vector de
    versión ni resolución automática de conflictos entre dispositivos; es una decisión de
    diseño consciente (dominio de un solo usuario editando mayormente desde un dispositivo
    a la vez), no un vacío.

**b) Auditoría de RLS con evidencia SQL** — se consultó `pg_policies` directamente (no
solo `get_advisors`) para las 11 tablas nuevas. **Se encontró y corrigió un bug real**: la
policy `challenges_select_participants` comparaba `cp.challenge_id = cp.id` (columna `id`
propia de `challenge_participants`, no la de `challenges`) por no calificar la tabla
externa — la condición nunca era verdadera para nadie, ni siquiera el dueño del reto. Se
corrigió calificando explícitamente `challenges.id` (migración
`fix_challenges_select_policy_column_collision`), verificado leyendo la policy resultante
de vuelta desde `pg_policies`. El resto de las policies (14 en total) fueron revisadas una
por una: todas usan `auth.uid() = user_id`/`owner_id`/`id` (directo o vía `EXISTS` con
join al padre) tanto en `USING` como en `WITH CHECK`, sin ningún `using (true)` — un
usuario no puede leer, modificar, insertar ni borrar filas de otro. `get_advisors`
después del fix: mismos 4 hallazgos que antes (2 `INFO` preexistentes de tablas de
FastAPI, 2 `WARN` intencionales ya explicados en 5.5), cero regresiones.

**c) Uniformidad de repositorios** — `ProfileRepository`/`GoalRepository`/
`NutritionRepository`/`RecoveryRepository`/`RoutineRepository` comparten estructura
(constructor `(AppDatabase db)`, sin estado propio más allá de `db`). Los nombres de
método difieren **solo cuando el dominio lo justifica**: `list/create/delete` para los
dominios create-or-delete, `get/upsert` para los de fila única (`Profile`) o por fecha
(`Nutrition`/`Recovery`) — no hay dos repos con la misma forma de dominio implementados de
formas distintas.

**d) FastAPI fuera del flujo principal** — confirmado por grep, no por inspección visual:
cero archivos bajo `lib/screens/` o `lib/core/sync/` importan `ApiClient` ni ningún
`*_service.dart` de los 6 dominios migrados (perfil, rutinas, entrenamientos, objetivos,
nutrición, recovery). Los archivos `auth_service.dart`, `goal_service.dart`,
`nutrition_service.dart`, `recovery_service.dart`, `social_service.dart`,
`routine_service.dart`, `workout_service.dart` siguen en el repo, compilando, sin ningún
importador real — exactamente "código por compatibilidad", como pediste.

**Fase 2: consolidada.** Con el fix de RLS aplicado y verificado, no queda ningún punto
abierto de esta fase.

### 5.7 Componentes ya listos para usar en fases siguientes

- `AuthRepository` (`lib/core/auth/auth_repository.dart`) — sin cambios, sigue siendo el
  único punto de verdad para el usuario autenticado.
- `ProfileRepository`/`GoalRepository`/`NutritionRepository`/`RecoveryRepository` — mismo
  patrón (`db`, offline-first, dirty-flag) reutilizable para cualquier dominio nuevo que
  aparezca más adelante.
- `SocialRepository` — patrón de referencia para cualquier futuro dominio que necesite
  leer datos de otros usuarios vía función `security definer`.
- `SmartBackendAvailability.isConfigured` / `.baseUrl` y `ComingSoonView` — sin usar
  todavía, listos para gatear Coach IA en la Fase 4.

### 5.8 Mejora pendiente, señalada por el usuario (no bloqueante)

El `try/catch` silencioso alrededor de `Supabase.initialize` en `main.dart` está bien para
esta transición, pero no debe quedar así de forma permanente: en una fase posterior hay
que registrar ese error en un servicio real (Crashlytics o equivalente) en vez de solo
`developer.log`. Sigue marcado con `// TODO(fase-posterior)` en `lib/main.dart` — sin
cambios en esta fase, no era su alcance.

## 6. Distribución actual de responsabilidades

Foto tomada el 2026-07-12, al cerrar la Fase 3 completa (3a+3b+3c). Cualquiera debería
poder entender la arquitectura actual leyendo solo esta sección.

### Flutter + Drift (cliente, offline-first)

- Toda la UI y la navegación.
- Base de datos local (SQLite vía Drift): fuente de verdad inmediata para rutinas,
  entrenamientos, perfil, objetivos, nutrición y recovery — la app es 100% funcional sin
  red para crear/editar/ver estos datos.
- Cola de sincronización (`SyncEngine` + `SyncableEntity`), disparada por conectividad y
  por un timer de respaldo.
- **Todo el cálculo de negocio es on-device (Fase 3 completa)**: récords personales
  (`PersonalRecords`, calculados al agregar un set), progreso de objetivos
  (`GoalRepository`), factor de carga del índice de recovery (`RecoveryRepository`),
  estadísticas — volumen muscular, perfil de fuerza, progreso por ejercicio, tonelaje
  histórico, racha, estándares de fuerza, predicción de récords (`StatsRepository`),
  gamificación (`GamificationRepository`), catálogo de ejercicios (`ExerciseRepository`) y
  calculadoras (`lib/core/calculators.dart`) — todos leyendo solo Drift local o funciones
  puras del input, sin ninguna llamada a Supabase ni a FastAPI para el cálculo en sí (la
  sincronización solo comparte el resultado entre dispositivos donde aplica).
- **No queda ningún dominio de usuario pendiente de mover acá.** Lo único fuera de este
  cliente es Coach IA (Fase 4, deliberadamente reservado para backend inteligente).

### Supabase (identidad + datos del usuario)

- **Auth**: registro, login, logout, recuperar contraseña, sesión persistida y renovación
  automática de token.
- **Datos por usuario, con RLS** (`auth.uid() = user_id`, auditado en 5.6): perfil,
  rutinas, entrenamientos, objetivos, nutrición, check-ins de recovery.
- **Social** (retos): única excepción sin caché local — lectura/escritura en vivo,
  incluyendo dos funciones `security definer` para las operaciones que cruzan datos de
  otros usuarios (unirse por código, leaderboard).

### Backend inteligente (`backend_ia/`, Fase 4 — completada 2026-07-12)

- **Coach IA / chat**: único dominio que necesita un servidor propio (sostiene la API key
  del LLM). Implementado como servicio standalone y **100% stateless** — sin PostgreSQL,
  SQLAlchemy, Alembic ni tool-calling contra ninguna base (diseño completo en
  `docs/FASE_4_DISENO.md`, contratos en `docs/COACH_CONTEXT.md`/`docs/COACH_API.md`/
  `docs/COACH_SYSTEM_PROMPT.md`). El cliente arma todo el `CoachContext` — el backend
  solo valida el JWT de Supabase, aplica rate limiting, antepone el system prompt y llama
  al `LLMProvider` activo (`GroqProvider` hoy, intercambiable sin tocar endpoints).
- **Calendario y exportación/importación de datos**: estaban **rotos** al momento de esta
  auditoría (ver 7.1) — su destino nunca fue este backend, eran cálculo derivado y
  transferencia de archivo local respectivamente. Portados a Flutter/Drift en la Fase 5,
  Bloque 1 (2026-07-12) — ver actualización al final de esta sección.
- El resto de FastAPI legado (`backend/app/`) permanece intacto en el repo, sin borrar
  nada, pero **orbita sin ningún cliente real** — ver el inventario completo en 7.1;
  apagado/limpieza queda para la Fase 5.

Este documento se creó el 2026-07-11 como resultado del análisis de arquitectura
solicitado antes de tocar código, se actualizó el 2026-07-12 al completar y consolidar la
Fase 2, y se amplió el mismo día con la auditoría de consolidación de la sección 7 previa
a la Fase 4.

## 7. Auditoría de consolidación (Fases 1-3, previa a la Fase 4)

Auditoría solicitada explícitamente por el usuario tras cerrar la Fase 3, antes de tocar
código de la Fase 4: "congelar el estado, documentarlo y verificar que no quedaron
dependencias ocultas". Todo lo de esta sección es diagnóstico — **no se cambió código**.

### 7.1 Inventario de dependencias FastAPI restantes

**Hallazgo crítico, no documentado hasta ahora**: las 3 pantallas que todavía llaman a
FastAPI están **rotas en producción**, no solo "pendientes de migrar". La Fase 1 reemplazó
el login por Supabase y `AuthProvider`/`SupabaseAuthRepository` nunca llaman a
`ApiClient.setToken(...)` (ese método solo lo invoca `auth_service.dart`, que no tiene
ningún importador real). Confirmado con grep: `setToken`/`clearToken` no se llaman desde
ningún flujo activo. Resultado: `ApiClient.token` es `null` para absolutamente todos los
usuarios de hoy, así que cada request de las 3 pantallas de abajo sale sin header
`Authorization`, y `OAuth2PasswordBearer` en `backend/app/deps.py` responde `401` antes de
ejecutar cualquier lógica. Además, aunque se reparara el token, `digital_twin.py` (el
contexto que arma el Coach IA) consulta `WorkoutSession`/`NutritionLog`/`DailyCheckIn` **de
la base propia de FastAPI** — tablas que dejaron de recibir escrituras reales desde la
Fase 2, porque esos datos ahora viven en Supabase. Es decir: aunque el auth se arreglara
tal cual está, el Coach seguiría respondiendo con el historial vacío de cualquier usuario
que se registró o entrenó después de la Fase 1.

| Archivo(s) | Motivo por el que sigue llamando a FastAPI | ¿Imprescindible? | ¿Migrable a Supabase? | Destino correcto |
|---|---|---|---|---|
| `lib/screens/coach/coach_chat_screen.dart`, `lib/services/coach_service.dart` → `POST /api/v1/coach/chat` | Chat con LLM (Groq), tool-calling sobre el historial. **Roto hoy: 401** (sin token) y, aunque se arreglara el auth, el contexto que arma `digital_twin.py` lee de tablas de FastAPI vacías desde la Fase 2 (los datos reales están en Supabase). | Sí — el LLM y su API key no pueden vivir en el cliente. | No aplica (no es dato de usuario, es orquestación de IA). | **Backend inteligente** — pero reescribiendo `digital_twin.py` para leer de Supabase (o recibir el contexto ya armado desde Flutter), no de la DB propia. Alcance central de la Fase 4. |
| `lib/screens/calendar/calendar_screen.dart`, `lib/services/calendar_service.dart` → `GET /api/v1/calendar/overview` | Combina `get_deload_recommendation` (umbral sobre tonelaje semanal) + objetivos próximos + predicción de récords. **Roto hoy: 401.** | No — es 100% cálculo derivado, sin ningún dato que solo exista en el backend. | No aplica (no hay tabla que sincronizar, es agregación). | **Flutter + Drift.** `get_tonnage_history`/`predict_next_record` ya están portados en `StatsRepository` (Fase 3b) y `GoalRepository` ya expone el progreso (Fase 3a) — solo falta un repositorio pequeño que combine esos tres on-device. No es trabajo de Fase 4. |
| `lib/screens/settings/settings_screen.dart`, `lib/services/data_transfer_service.dart` → `GET /api/v1/users/me/export`, `POST /api/v1/users/me/import` | Backup/restore de todos los datos del usuario como archivo `.json`. **Roto hoy: 401.** | No — todo el dato ya vive en Drift local (y sincronizado en Supabase). | No aplica (es transferencia de archivo, no un dominio de datos). | **Flutter + Drift.** Leer/escribir directo las tablas Drift (`Routines`, `WorkoutSessions`, `Goals`, `NutritionLogs`, `DailyCheckins`) y armar/parsear el JSON en el cliente — sin red. No es trabajo de Fase 4. |
| ~~`lib/core/api_client.dart`, `lib/services/auth_service.dart`~~ | **Ya eliminados** (Fase 5, Bloque 2, 2026-07-12). Login/registro/logout contra el JWT propio de FastAPI, reemplazado enteramente por `SupabaseAuthRepository` desde la Fase 1. | No — cero importadores reales (confirmado por grep). | Ya migrado (Fase 1). | — (ya resuelto) |
| ~~`lib/services/{goal,nutrition,recovery,routine,workout,social,stats,gamification,exercise,calculator}_service.dart`~~ | **Ya eliminados** (Fase 5, Bloque 2, 2026-07-12). Reemplazados por repositorios locales/Supabase en las Fases 2 y 3. | No — cero importadores reales (confirmado por grep en cada fase). | Ya migrado. | — (ya resuelto) |
| `backend/app/routes/v1/{auth,users,goals,nutrition,recovery,routines,workouts,social,stats,gamification,exercises,calculators}.py` y sus `services/*.py` asociados | Ningún cliente Flutter los llama ya (los de arriba). Siguen desplegados y respondiendo si alguien les pega directo con curl/Postman y un JWT propio válido — pero no hay ningún flujo de la app que hoy pueda emitir ese JWT. | No. | Ya migrado (Supabase) u on-device (Drift). | Apagar/eliminar en la Fase 5 (limpieza del `backend/` — Bloque 3, aún no confirmado). |
| `backend/app/routes/v1/coach.py`, `services/{llm_client,digital_twin}.py` | Única parte del backend con un propósito futuro real. | Sí. | No aplica. | **Backend inteligente**, con la reescritura de `digital_twin.py` señalada arriba. Ver propuesta de diseño en `docs/FASE_4_DISENO.md`. |

### 7.2 Código legado (ya eliminado del lado Flutter; el `backend/` Python sigue en pie)

| Archivo(s) | Por qué ya no se usa | Estado |
|---|---|---|
| ~~`lib/services/{auth,goal,nutrition,recovery,routine,workout,social,stats,gamification,exercise,calculator}_service.dart` (12 archivos)~~ | Reemplazados por repositorios locales/Supabase en las Fases 1-3. Confirmado cero importadores por grep antes de cada borrado. | **Ya eliminados** (Fase 5, Bloque 2, 2026-07-12) |
| ~~`lib/services/calendar_service.dart`, `data_transfer_service.dart`~~ | Reemplazados por `StatsRepository.deloadRecommendation()`/`upcomingRecordPredictions()` + `GoalRepository.list()` (calendario) y `DataExportService`/`DataImportService` (export/import), ambos on-device contra Drift. | **Ya eliminados** (Fase 5, Bloque 1, 2026-07-12) |
| ~~`lib/core/api_client.dart`, `lib/core/api_exception.dart`~~ | Ya no los importaba ninguna pantalla; solo los 12 `*_service.dart` de arriba y `main.dart` (que lo instanciaba/proveía sin consumirlo). Eliminados en orden: primero los 12 servicios, luego confirmado por grep que `ApiClient` quedó sin importadores, luego el cliente, luego su registro en `main.dart`. | **Ya eliminados** (Fase 5, Bloque 2, 2026-07-12) |
| ~~`lib/core/app_config.dart`~~ | Único consumidor era `api_client.dart`; ya estaba huérfano incluso antes de esta limpieza. | **Ya eliminado** (Fase 5, Bloque 2, 2026-07-12) |
| `lib/models/social.dart`: factories `LeaderboardEntry.fromJson`/`ChallengeSummary.fromJson`/`ChallengeDetail.fromJson` | Único consumidor era `social_service.dart`. Las clases en sí siguen vivas (las usa `SocialRepository` contra Supabase) — solo se quitaron los constructores JSON muertos. | **Ya eliminados** (Fase 5, Bloque 2, 2026-07-12) |
| `backend/app/routes/v1/{auth,users,goals,nutrition,recovery,routines,workouts,social,stats,gamification,exercises,calculators}.py` + `services/*.py` asociados (`goals.py`, `recovery.py`, `social.py`, `stats.py`, `strength_standards.py`, `predictions.py`, `records.py`, `calculators.py`) | Sin ningún cliente que los llame — ver 7.1. No se tocó en Bloque 2 (solo limpieza del lado Flutter). | Pendiente — Fase 5, ítem "archivar/eliminar `backend/`" (aún no confirmado con el usuario) |

### 7.3 Flujo de datos

**Flujo de datos de usuario (todo lo migrado en Fases 1-3):**

```
Usuario
  │
  ▼
Flutter (pantalla)
  │
  ▼
Repositorio (ProfileRepository / RoutineRepository / WorkoutRepository /
             GoalRepository / NutritionRepository / RecoveryRepository /
             StatsRepository / GamificationRepository / ExerciseRepository)
  │
  ▼
Drift (SQLite local) — fuente de verdad inmediata, lectura/escritura offline
  │
  ▼ (si hay conexión: listener de conectividad o timer de respaldo cada 3h)
SyncEngine → SyncableEntity.push(db)
  │
  ▼
Supabase Postgres (RLS: auth.uid() = user_id) — respaldo + fuente para otros dispositivos
  │
  ▼
Sincronización de vuelta: el mismo SyncEngine, al arrancar en otro dispositivo con la
misma cuenta, trae lo que ya esté en Supabase hacia el Drift local de ese dispositivo.
```

Nota: `StatsRepository`/`GamificationRepository`/`ExerciseRepository`/`Calculators` no
tienen flecha hacia Supabase — leen y calculan 100% dentro de Drift/memoria, la
sincronización nunca participa de ese cálculo (ver sección 6).

**Excepción — Social (retos):** sin paso por Drift, lectura/escritura directa:

```
Usuario → Flutter → SocialRepository → Supabase (en vivo, sin caché local)
```

**Flujo de Coach IA (diseño actual del backend, roto — ver 7.1):**

```
Usuario
  │
  ▼
Flutter (CoachChatScreen)
  │
  ▼ (falla acá: sin token válido → 401)
FastAPI (/api/v1/coach/chat)
  │
  ▼
digital_twin.build_user_context() — lee WorkoutSession/NutritionLog/DailyCheckIn
                                     de la base PROPIA de FastAPI (vacía/obsoleta
                                     desde la Fase 2 para cualquier usuario real)
  │
  ▼
llm_client.ask_llm() → Groq (API OpenAI-compatible, modelo llama-3.3-70b-versatile)
  │
  ▼
Respuesta (con tool-calling opcional: consultar_historial)
```

El diseño propuesto para que este flujo funcione de verdad queda en
`docs/FASE_4_DISENO.md`.

### 7.4 Estado del proyecto por dominio

| Dominio | Estado |
|---|---|
| Auth | ✅ Supabase (Fase 1) |
| Perfil | ✅ Supabase (Fase 2) |
| Rutinas | ✅ Supabase (Fase 2) |
| Entrenamientos | ✅ Supabase (Fase 2) |
| Nutrición | ✅ Supabase (Fase 2) |
| Recovery | ✅ Supabase (Fase 2) |
| Objetivos | ✅ Supabase (Fase 2) + progreso on-device (Fase 3a) |
| Récords personales | ✅ On-device (ya desde antes de la Fase 2) |
| Estadísticas | ✅ On-device (Fase 3b) |
| Gamificación | ✅ On-device (Fase 3c) |
| Catálogo de ejercicios | ✅ On-device (Fase 3c) |
| Calculadoras | ✅ On-device (Fase 3c) |
| Social (retos) | ✅ Supabase, en vivo sin caché (Fase 2, excepción acordada) |
| Calendario inteligente | ✅ On-device — `StatsRepository.deloadRecommendation()`/`upcomingRecordPredictions()` + `GoalRepository.list()` (Fase 5, Bloque 1, 2026-07-12) |
| Exportar/importar datos | ✅ On-device — `DataExportService`/`DataImportService` leyendo/escribiendo Drift directo (Fase 5, Bloque 1, 2026-07-12) |
| Coach IA / chat | ✅ Backend inteligente (`backend_ia/`) + `CoachContextBuilder`/`CoachRepository`/`CoachGateway` en Flutter (Fase 4, completada 2026-07-12) |
| Wearables (pasos/pulso/sueño) | ✅ On-device desde su creación (Health Connect/HealthKit, `HealthService` — nunca dependió de ningún backend) |
| Análisis de técnica (pose) / vista 3D de ejercicios | ✅ On-device desde su creación (cámara + modelo local / assets 3D — nunca dependió de ningún backend) |

Auditoría de rendimiento correspondiente: ver `docs/SEGURIDAD_Y_EFICIENCIA.md`, sección
"Auditoría de rendimiento (Fase 3)".
