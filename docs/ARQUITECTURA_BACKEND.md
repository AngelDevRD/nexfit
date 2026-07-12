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

#### Fase 3b — Estadísticas (`stats_service.dart`) ⬜ no iniciada
`stats.py` tiene 7 cálculos distintos (volumen muscular, perfil de fuerza, progreso por
ejercicio, tonelaje histórico, racha de entrenamiento, estándares de fuerza, predicción de
récords) — se porta como su propia sub-fase para poder revisarla con el mismo detalle que
3a, no de un salto grande sin poder probarse en dispositivo.

#### Fase 3c — Gamificación + catálogo de ejercicios + calculadoras ⬜ no iniciada
Gamificación (`gamification_service.dart`), corte de la llamada de red residual del
catálogo de ejercicios, y verificación de que las calculadoras ya son 100% locales.

- **Criterio de éxito de la Fase 3 completa**: estas pantallas funcionan sin red y sin
  sesión Supabase activa (offline puro), sin ninguna llamada innecesaria a Supabase para
  datos que puedan calcularse localmente. La sincronización se sigue usando solo para
  compartir el resultado entre dispositivos (vía `PersonalRecords`/`Profiles` ya
  sincronizados en la Fase 2), no para hacer el cálculo.

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
| 3b — Estadísticas (`stats_service.dart`) | ⬜ No iniciada | — |
| 3c — Gamificación + catálogo de ejercicios + calculadoras | ⬜ No iniciada | — |
| 4 — Backend inteligente aislado | ⬜ No iniciada | — |
| 5 — Cutover de CI y limpieza | ⬜ No iniciada | — |

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
- **Catálogo de ejercicios, calculadoras, stats, gamificación**: dominio de la Fase 3
  (on-device), sin tocar en esta fase.
- **`lib/services/{auth,goal,nutrition,recovery,social}_service.dart` (FastAPI)**: código
  intacto, sin borrar, ya desconectado de toda pantalla real. Se restauraron los
  `fromJson` en los modelos (`Goal`, `NutritionLog`, `RecoveryIndex`, `ChallengeSummary`,
  `ChallengeDetail`, `LeaderboardEntry`) que estos archivos siguen necesitando para
  compilar, aunque nada los llame.

### 5.3 Qué se migra en la Fase 3b/3c (siguiente paso, no iniciado)

Estadísticas (`stats_service.dart`: volumen muscular, perfil de fuerza, progreso por
ejercicio, tonelaje histórico, racha, estándares de fuerza, predicción de récords),
gamificación (`gamification_service.dart`), catálogo de ejercicios (cortar cualquier
llamada de red residual) y verificación de las calculadoras.

### 5.4 Simplificaciones de la Fase 2 — resueltas en la Fase 3a

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

Foto tomada el 2026-07-12, al cerrar la Fase 3a. Cualquiera debería poder entender la
arquitectura actual leyendo solo esta sección.

### Flutter + Drift (cliente, offline-first)

- Toda la UI y la navegación.
- Base de datos local (SQLite vía Drift): fuente de verdad inmediata para rutinas,
  entrenamientos, perfil, objetivos, nutrición y recovery — la app es 100% funcional sin
  red para crear/editar/ver estos datos.
- Cola de sincronización (`SyncEngine` + `SyncableEntity`), disparada por conectividad y
  por un timer de respaldo.
- **Cálculo de negocio ya on-device (Fase 3a)**: récords personales (`PersonalRecords`,
  calculados al agregar un set), progreso de objetivos (`GoalRepository`), factor de carga
  del índice de recovery (`RecoveryRepository`) — todos leyendo solo Drift local, sin
  ninguna llamada a Supabase para el cálculo en sí (la sincronización solo comparte el
  resultado entre dispositivos).
- **Pendiente de mover acá (Fase 3b/3c)**: el resto de estadísticas (volumen muscular,
  perfil de fuerza, progreso por ejercicio, tonelaje histórico, racha, estándares de
  fuerza, predicción de récords) y gamificación. `stats_service.dart`/
  `gamification_service.dart` siguen apuntando a FastAPI sin usarse desde ninguna pantalla
  activa (ver 5.2).

### Supabase (identidad + datos del usuario)

- **Auth**: registro, login, logout, recuperar contraseña, sesión persistida y renovación
  automática de token.
- **Datos por usuario, con RLS** (`auth.uid() = user_id`, auditado en 5.6): perfil,
  rutinas, entrenamientos, objetivos, nutrición, check-ins de recovery.
- **Social** (retos): única excepción sin caché local — lectura/escritura en vivo,
  incluyendo dos funciones `security definer` para las operaciones que cruzan datos de
  otros usuarios (unirse por código, leaderboard).

### Backend inteligente (FastAPI hoy, pendiente de aislar en la Fase 4)

- **Coach IA / chat / tool-calling**: el único dominio que sigue — y seguirá — necesitando
  un servidor propio, porque sostiene la API key del LLM y orquesta llamadas que no pueden
  exponerse al cliente.
- **Sin decidir todavía** (fuera del alcance de la Fase 2, no tocado): calendario y
  exportación de datos (`calendar_service.dart`, `data_transfer_service.dart`) siguen
  apuntando a FastAPI sin verificar si de hecho funcionan hoy.
- El resto de FastAPI (`backend/app/`) permanece intacto en el repo, sin borrar nada,
  hasta la limpieza final de la Fase 5.

Este documento se creó el 2026-07-11 como resultado del análisis de arquitectura
solicitado antes de tocar código, y se actualizó el 2026-07-12 al completar y consolidar
la Fase 2.
