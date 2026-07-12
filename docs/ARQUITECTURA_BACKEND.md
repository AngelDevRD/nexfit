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
  `vywkyuuuxpovoevwdewh`, creado 2026-07-04, actualmente `INACTIVE` por inactividad —
  confirmado vía MCP de Supabase). Hoy se usa **únicamente como Postgres gestionado**
  detrás de SQLAlchemy (ver `SEGURIDAD_Y_EFICIENCIA.md`: "Pooler de Supabase", "Activar
  RLS... 13 tablas"). Auth, RLS y el cliente PostgREST/Supabase **no** están en uso. Migrar
  a "Supabase" en este proyecto no es agregar infraestructura nueva — es empezar a consumir
  la infraestructura que ya está pagada y corriendo, en vez de solo usarla como disco duro
  de FastAPI.
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

### Fase 0 — Fundaciones (sin cambio visible para el usuario)
- Agregar `supabase_flutter` a `pubspec.yaml`.
- Reactivar el proyecto Supabase `AppGym` (`vywkyuuuxpovoevwdewh`, hoy `INACTIVE`) y activar
  RLS en sus 13 tablas (pendiente ya anotado en `SEGURIDAD_Y_EFICIENCIA.md`).
- Construir `SmartBackendAvailability` + `ComingSoonView` (sección 3), sin conectarlos
  todavía a ninguna pantalla real.
- **Criterio de éxito**: build verde, cero cambios de comportamiento.

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
| 0 — Fundaciones | ⬜ No iniciada | — |
| 1 — Auth a Supabase | ⬜ No iniciada | — |
| 2 — Dominios de datos a Supabase | ⬜ No iniciada | — |
| 3 — Dominios on-device | ⬜ No iniciada | — |
| 4 — Backend inteligente aislado | ⬜ No iniciada | — |
| 5 — Cutover de CI y limpieza | ⬜ No iniciada | — |

Este documento se creó el 2026-07-11 como resultado del análisis de arquitectura
solicitado antes de tocar código. Ningún archivo de `lib/` ni `backend/` fue modificado
para producir este plan.
