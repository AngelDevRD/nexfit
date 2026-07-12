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

### Fase 1 — Auth a Supabase (desbloquea publicar ya)
- Reemplazar `AuthService`/`AuthProvider` para usar Supabase Auth (registro, login,
  recuperar contraseña) en vez de `/api/v1/auth/*`.
- Retirar la dependencia dura de `ApiClient` en el arranque de sesión.
- **Criterio de éxito**: registrarse, iniciar sesión y recuperar contraseña funcionan con
  cero backend FastAPI desplegado. Esto por sí solo ya cumple el bloqueador reportado por
  el usuario (login roto en producción).

### Fase 2 — Dominios de datos a Supabase
- Esquema Supabase espejo de las tablas Drift ya existentes (rutinas, días, ejercicios de
  rutina, sesiones de entrenamiento, objetivos, nutrición, recovery, retos sociales), con
  RLS `user_id = auth.uid()`.
- Como `SyncableEntity` ya es agnóstico del backend (`push(AppDatabase db)`), solo cambia
  el interior de `RoutineSyncable`/`WorkoutSessionSyncable` (llamar al cliente Supabase en
  vez de `RoutineService`/`ApiClient`) — **`SyncEngine` no se toca**.
- Crear `GoalSyncable`, `NutritionSyncable`, `RecoverySyncable`, `SocialSyncable` nuevos
  (hoy esos servicios no tienen offline-first; lo ganan en esta fase).
- Retirar los routers de FastAPI equivalentes solo después de verificar paridad,
  dominio por dominio (no es un corte único).
- **Criterio de éxito**: cada dominio migrado sigue funcionando offline y sincroniza al
  recuperar conexión, verificado uno por uno.

### Fase 3 — Dominios 100% on-device
- Confirmar y cortar cualquier llamada de red residual en `exercise_service.dart` (usar
  solo `assets/data/exercises.json` + caché Drift).
- Portar a Dart la lógica de `stats_service.dart`/`gamification_service.dart` para que
  lean directo de las tablas Drift locales, replicando `stats.py`/`gamification.py` del
  backend actual.
- **Criterio de éxito**: estas pantallas funcionan sin red y sin sesión Supabase activa
  (offline puro).

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
| 1 — Auth a Supabase | ⬜ No iniciada | — |
| 2 — Dominios de datos a Supabase | ⬜ No iniciada | — |
| 3 — Dominios on-device | ⬜ No iniciada | — |
| 4 — Backend inteligente aislado | ⬜ No iniciada | — |
| 5 — Cutover de CI y limpieza | ⬜ No iniciada | — |

### 5.1 Qué depende todavía del backend FastAPI (sin cambios en esta fase)

Todo lo funcional: auth completa, rutinas, entrenamientos, objetivos, nutrición, recovery,
social, calendario, exportación de datos y Coach IA siguen pasando 100% por
`ApiClient`/`http://10.0.2.2:8000` (o `API_BASE_URL` si se pasa por build), exactamente
igual que antes de la Fase 0. La Fase 0 no desactiva ni redirige ninguna llamada existente.

### 5.2 Qué se migra en la Fase 1 (siguiente paso, no iniciado)

Únicamente `AuthService`/`AuthProvider`/`lib/services/auth_service.dart` → Supabase Auth
(registro, login, recuperar contraseña). Nada más se toca en la Fase 1.

### 5.3 Componentes ya listos para usar en fases siguientes

- `Supabase.instance.client` — cliente global disponible en toda la app desde `main()`.
- `SupabaseConfig.url` / `SupabaseConfig.publishableKey` — para cualquier código que
  necesite las credenciales del proyecto.
- `SmartBackendAvailability.isConfigured` / `.baseUrl` — para gatear Coach IA en la Fase 4.
- `ComingSoonView` (`lib/widgets/coming_soon_view.dart`) — para reemplazar cualquier
  pantalla que dependa del backend inteligente mientras no esté configurado o falle.

Este documento se creó el 2026-07-11 como resultado del análisis de arquitectura
solicitado antes de tocar código, y se actualizó el mismo día al completar la Fase 0.
