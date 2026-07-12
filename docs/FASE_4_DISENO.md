# Fase 4 — Diseño del backend inteligente (propuesta, sin implementar)

Estado: **propuesta de diseño únicamente**. No hay código nuevo en este documento — se
implementa recién cuando el usuario apruebe este diseño y dé la orden explícita de
empezar la Fase 4, según la regla de "mostrar el plan antes de tocar código" que se viene
siguiendo en todas las fases anteriores.

Contexto que motiva este diseño: la auditoría de la sección 7 de
`docs/ARQUITECTURA_BACKEND.md` encontró que el Coach IA está roto hoy (401, porque nadie
emite ya un JWT propio de FastAPI) y que, aunque se arreglara el auth, su lógica de
contexto (`digital_twin.py`) lee de tablas de la base propia de FastAPI que dejaron de
recibir datos reales desde la Fase 2 — el historial de cualquier usuario real vive en
Supabase, no ahí. Este diseño parte de cero sobre esa base, no de "reconectar" el backend
viejo.

## 1. Objetivo y alcance

Único propósito de este backend: sostener lo que **no puede** ejecutarse en el cliente —
la API key del LLM y la orquestación de tool-calling. Todo lo demás (auth, datos de
usuario, cálculo de negocio) ya quedó resuelto en las Fases 1-3 y **no vuelve a este
backend bajo ningún diseño**.

Fuera de alcance explícito (ver instrucción del usuario, reafirmada en cada fase): nada
de lo migrado a Supabase o a on-device se toca ni se duplica acá.

## 2. Decisión de diseño central: ¿de dónde saca el contexto del usuario?

Esta es la pregunta que rompió el diseño anterior (`digital_twin.py` leía de una base que
ya no se llena). Dos opciones:

### Opción A — el cliente arma el contexto y lo manda (recomendada)

Flutter ya tiene, on-device y sin red, exactamente los mismos datos que `digital_twin.py`
necesitaba: `StatsRepository.strengthProfile()`/`.streak()`, `GoalRepository.list()`,
`GamificationRepository.profile()`. En vez de que el backend vuelva a calcular todo eso
consultando Supabase (una tercera implementación de la misma lógica de negocio, después de
FastAPI original y el port a Dart de la Fase 3), el cliente arma un resumen compacto y lo
manda como parte del request de chat. El backend queda como **proxy de orquestación
puro**: valida el JWT, arma el prompt con ese contexto + el mensaje, llama al LLM,
devuelve la respuesta. Cero acceso a datos de usuario, cero credencial de Supabase en este
backend.

- **Ventaja**: aislamiento total (el backend no necesita ninguna credencial de Supabase,
  ni siquiera la publishable key); no hay tercera copia de la lógica de negocio; menos
  superficie de ataque (nada que filtrar si este servidor se compromete, más allá de la
  key del LLM).
- **Contrapartida**: el tool-calling de rango de fechas libre (`consultar_historial`,
  hoy hasta 90 días) necesita que el cliente também pueda responder esa herramienta. Se
  resuelve con un segundo round-trip: si el LLM pide la herramienta, el backend responde
  al cliente pidiéndole el rango (en vez de resolverlo él mismo con una consulta a
  Supabase) y el cliente reintenta el mensaje con el detalle de esos días ya adjunto
  (mismo patrón de "traé vos los datos" que ya usa para el resumen inicial).

### Opción B — el backend consulta Supabase directo con el JWT del usuario reenviado

El backend recibe el JWT de Supabase del usuario, lo reenvía tal cual a PostgREST/Supabase
(o arma un cliente Supabase autenticado con ese JWT) para consultar `workout_sessions`,
`goals`, etc. — las RLS ya auditadas en la Fase 2 garantizan que solo ve sus propias filas,
sin necesitar ninguna service-role key. El backend reimplementa en Python las agregaciones
que hoy están en `StatsRepository`/`GoalRepository` (Dart) contra esas tablas.

- **Ventaja**: el tool-calling de rango libre se resuelve en una sola llamada, sin
  segundo round-trip con el cliente.
- **Contrapartida**: tercera implementación de la misma lógica de negocio (después de
  FastAPI original y el port a Dart) — cada cambio futuro a cómo se calcula el progreso de
  un objetivo o la racha habría que replicarlo en dos lenguajes. Mayor superficie: este
  backend pasa a necesitar la URL de Supabase y saber armar queries contra esas tablas.

**Recomendación**: empezar con la **Opción A**. Es más simple, más aislada, y coherente
con la decisión ya tomada en las Fases 1-3 de que el cálculo de negocio vive en un solo
lugar (el cliente). Si en el uso real el ida-y-vuelta del tool-calling resulta molesto
para la UX del chat, migrar puntualmente ese caso a la Opción B sin tocar el resto del
diseño.

## 3. Arquitectura

```
┌─────────────────────────┐         ┌──────────────────────────────┐        ┌─────────┐
│   Flutter (NexFit)       │  HTTPS  │  Backend inteligente          │  HTTPS │  Groq   │
│                          │ ───────►│  (FastAPI mínimo, standalone)  │───────►│  (LLM)  │
│ StatsRepository          │         │                                │◄───────│         │
│ GoalRepository           │         │  - Verifica JWT de Supabase    │        └─────────┘
│ GamificationRepository   │◄────────│  - Arma prompt (contexto del   │
│ (arman el contexto)      │         │    cliente + mensaje)          │
│                          │         │  - Orquesta tool-calling       │
│ supabase_flutter         │         │  - Sin DB propia, sin Alembic  │
│ (sesión ya autenticada)  │         │  - Sin SQLAlchemy              │
└─────────────────────────┘         └──────────────────────────────┘
```

Puntos clave de aislamiento:
- **Repo/deploy separado** del resto del backend legado (`backend/` actual queda tal cual,
  ver Fase 5 para su apagado). Este backend inteligente puede vivir en un directorio nuevo
  (`backend_ia/` o similar) o directamente migrarse a una Supabase Edge Function (Deno) —
  la decisión entre servidor propio vs. Edge Function queda abierta para cuando se
  implemente, pero el diseño de este documento (endpoints, auth, contrato) es el mismo en
  cualquiera de los dos.
- **Sin base de datos propia** (Opción A) — no hay `DATABASE_URL`, no hay Alembic, no hay
  modelos SQLAlchemy. Si más adelante se adopta la Opción B, la única DB que toca es
  Supabase (con el JWT del usuario), nunca una base propia de este servicio.
- **Sin el JWT propio de FastAPI** (`secret_key`/HS256 de `backend/app/core/security.py`)
  — se elimina esa dependencia por completo, se verifica el JWT de Supabase.

## 4. Autenticación — JWT de Supabase

El cliente ya tiene la sesión de Supabase activa (`supabase_flutter`, Fase 1). Cada
request a este backend manda `Authorization: Bearer <access_token de la sesión Supabase>`
— el mismo token que usa para hablar con Supabase directo, no uno nuevo.

Verificación en el backend, dos variantes según cómo esté configurado el proyecto:

- **Simple (recomendada para arrancar)**: llamar a `GET {SUPABASE_URL}/auth/v1/user` con
  ese `Authorization` header. Supabase responde con el usuario si el token es válido, 401
  si no. Cero secretos que guardar en este backend — solo necesita saber la URL pública
  del proyecto (ya expuesta en el cliente). Costo: una llamada de red extra por request de
  chat (aceptable, el chat ya implica latencia de LLM de todos modos).
- **Optimizada (si la latencia del paso anterior importa)**: verificar el JWT
  localmente contra las claves públicas de Supabase (`{SUPABASE_URL}/auth/v1/.well-known/
  jwks.json`, cacheadas con `PyJWKClient` de `PyJWT`). Evita el round-trip, pero exige
  mantener el cache de JWKS actualizado (rotación de claves). Se puede migrar a esto
  después, sin cambiar el contrato del endpoint.

En ambos casos, el `sub` del JWT (o el `id` que devuelve `/auth/v1/user`) es el mismo uuid
de Supabase que ya usan `Profiles`/`Routines`/etc. — no hace falta ningún mapeo a un id
propio como el `int` de `backend/app/models/user.py` (ese modelo queda huérfano, ver
sección 7.1 de `ARQUITECTURA_BACKEND.md`).

## 5. Endpoints propuestos

Todos bajo `/api/v1/coach`, mismo prefijo que hoy para minimizar el cambio del lado del
cliente.

### `POST /api/v1/coach/chat`

Reemplaza al endpoint actual. Request:

```json
{
  "message": "¿Cómo viene mi progreso esta semana?",
  "context": {
    "months_training": 4,
    "weekly_volume_kg": 4200,
    "current_streak_days": 3,
    "longest_streak_days": 12,
    "max_strength_by_exercise": [{"exercise_name": "Sentadilla", "max_weight_kg": 100}],
    "goals": [{"title": "Bajar 5kg", "progress_pct": 40, "achieved": false}],
    "today_summary": "Entrenamiento: Sentadilla 100kg x 5 reps...",
    "tool_result": null
  }
}
```

`context` lo arma el cliente combinando `StatsRepository`/`GoalRepository`/
`GamificationRepository` — es el equivalente directo a lo que hoy arma
`digital_twin.build_user_context`, solo que calculado en el dispositivo. `tool_result` va
`null` en el primer mensaje; se completa en el segundo round-trip si el LLM pidió la
herramienta `consultar_historial` (ver sección 2, Opción A).

Response:

```json
{
  "reply": "Vas bien: 3 días de racha y el volumen semanal se mantiene...",
  "needs_tool_data": null
}
```

Si el LLM pidió la herramienta y todavía no hay `tool_result` en el request, la respuesta
en vez de `reply` trae:

```json
{
  "reply": null,
  "needs_tool_data": {"start_date": "2026-06-01", "end_date": "2026-06-30"}
}
```

El cliente arma el detalle día-por-día de ese rango (ya tiene toda esa data en Drift,
mismo formato que hoy calcula `_day_block`/`get_activity_log` en Python, portado a Dart) y
reenvía el mismo mensaje con `context.tool_result` completo.

### `GET /api/v1/coach/status`

Reemplaza el chequeo que hoy hace `SmartBackendAvailability` mirando si
`SMART_BACKEND_URL` está seteado en el cliente. Sin autenticación (público, solo dice si
el servicio está operativo):

```json
{ "available": true, "model": "llama-3.3-70b-versatile" }
```

`available: false` si falta `LLM_API_KEY` en el backend — mismo criterio que hoy usa
`LlmNotConfiguredError`, pero consultable antes de mandar un mensaje (hoy el cliente se
entera recién al fallar el POST con 503).

### Sin más endpoints

No hay `/coach/context-preview` (era para debug, no lo usa ninguna pantalla), ni ningún
endpoint de datos de usuario — ese es exactamente el punto de este rediseño.

## 6. Integración con el Coach IA (cliente)

- `CoachChatScreen` deja de usar `CoachService`/`ApiClient` (legado, roto) y pasa a un
  nuevo `CoachRepository` o similar que:
  1. Arma el `context` combinando los repositorios ya existentes (sin queries nuevas, solo
     reutilizar lo que devuelven).
  2. Llama a `POST /coach/chat` con el JWT de la sesión Supabase activa
     (`Supabase.instance.client.auth.currentSession?.accessToken`).
  3. Si la respuesta trae `needs_tool_data`, arma el detalle día-por-día de ese rango
     desde Drift (mismo patrón que `get_activity_log`, portado a Dart) y reintenta.
- `SmartBackendAvailability`/`ComingSoonView` (ya existen en el cliente desde la Fase 0,
  sin usar todavía) pasan a consultar `GET /coach/status` en vez de solo mirar si
  `SMART_BACKEND_URL` no está vacío — cubre también el caso "el servidor está desplegado
  pero sin `LLM_API_KEY` configurada".

## 7. Integración con el LLM (Groq u otros)

Se reutiliza el diseño actual de `llm_client.ask_llm` (ya well hecho): cliente HTTP
genérico contra una API compatible con OpenAI (`chat/completions`), configurable por
variables de entorno (`LLM_BASE_URL`, `LLM_API_KEY`, `LLM_MODEL`) — no queda atado a Groq
específicamente, cambiar de proveedor es solo cambiar esas tres variables. Se mantiene:
- Tool-calling en el formato OpenAI (`tools`/`tool_choice`/`tool_calls`) — ya es el
  estándar que siguen Groq, OpenAI y la mayoría de proveedores compatibles.
- El mismo `SYSTEM_PROMPT` (ajustado para explicitar que el contexto viene ya armado del
  cliente, no de una consulta propia del backend).
- El mismo manejo de `LlmNotConfiguredError` → 503, ahora también reflejado en
  `GET /coach/status`.

## 8. Qué se elimina o no se lleva a este backend

- `app/models/`, `app/core/database.py`, Alembic, SQLAlchemy — no hacen falta si se
  adopta la Opción A. Cero conexión a ninguna base de datos propia.
- `app/core/security.py` (JWT/bcrypt propios) — reemplazado por la verificación de JWT de
  Supabase (sección 4).
- `app/deps.get_current_user` — reemplazado por la verificación de Supabase.
- Todo lo demás de `backend/app/` (rutinas, objetivos, nutrición, stats, gamificación,
  etc.) — no se toca, no se lleva, queda para apagar en la Fase 5 según el inventario de
  la sección 7.1 de `ARQUITECTURA_BACKEND.md`.

## 9. Variables de entorno del backend inteligente

Solo las estrictamente necesarias — ninguna relacionada a Postgres/Alembic/auth propio:

| Variable | Propósito |
|---|---|
| `SUPABASE_URL` | Para verificar el JWT contra `/auth/v1/user` (o el JWKS si se optimiza después). Es la misma URL pública que ya usa el cliente. |
| `LLM_API_KEY` | Key de Groq (u otro proveedor compatible). |
| `LLM_BASE_URL` | Default `https://api.groq.com/openai/v1`. |
| `LLM_MODEL` | Default `llama-3.3-70b-versatile`. |
| `CORS_ORIGINS` | Igual que hoy. |

## 10. Próximos pasos (cuando se apruebe este diseño)

1. Confirmar Opción A vs. B (o el detalle de tool-calling) con el usuario.
2. Decidir servidor propio vs. Supabase Edge Function para el deploy.
3. Implementar en una rama/commit propio, con los mismos gates de siempre (analyze/test/
   build, un commit por sub-paso, sin tocar nada del `backend/` legado ni de los
   repositorios ya migrados).
4. Actualizar `docs/ARQUITECTURA_BACKEND.md` marcando la Fase 4 como completada, con el
   mismo nivel de detalle que las fases anteriores.

No se implementa nada de esto hasta recibir la aprobación explícita del usuario.
