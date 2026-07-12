# Fase 4 — Diseño del backend inteligente (propuesta, sin implementar)

Estado: **diseño aprobado por el usuario el 2026-07-12, incluido el contrato
`CoachContext` v1** (`docs/COACH_CONTEXT.md`). No hay código nuevo en este documento —
la implementación empieza recién cuando el usuario dé la orden explícita de comenzar la
Fase 4 (ver sección 10).

Contexto que motiva este diseño: la auditoría de la sección 7 de
`docs/ARQUITECTURA_BACKEND.md` encontró que el Coach IA está roto hoy (401, porque nadie
emite ya un JWT propio de FastAPI) y que, aunque se arreglara el auth, su lógica de
contexto (`digital_twin.py`) lee de tablas de la base propia de FastAPI que dejaron de
recibir datos reales desde la Fase 2 — el historial de cualquier usuario real vive en
Supabase, no ahí. Este diseño parte de cero sobre esa base, no de "reconectar" el backend
viejo.

## 1. Objetivo y alcance

Único propósito de este backend: sostener lo que **no puede** ejecutarse en el cliente —
la API key del LLM y la orquestación de la llamada. Todo lo demás (auth, datos de
usuario, cálculo de negocio) ya quedó resuelto en las Fases 1-3 y **no vuelve a este
backend bajo ningún diseño**. El usuario confirmó explícitamente esta dirección y pidió
llevarla más lejos: el backend no solo no debe *calcular* nada de negocio — no debe tener
ninguna forma de *volver a pedir* esos datos (nada de tool-calling contra una base de
datos). Todo lo que el Coach puede llegar a necesitar viaja en un único payload que arma
el cliente.

Fuera de alcance explícito (ver instrucción del usuario, reafirmada en cada fase): nada
de lo migrado a Supabase o a on-device se toca ni se duplica acá.

## 2. Decisión de diseño central: el cliente arma TODO el contexto, el backend es stateless

Se descarta por completo la alternativa de que el backend consulte Supabase (con el JWT
del usuario reenviado) para armar o completar el contexto. El usuario fue explícito:
*"el backend no debería reconstruir información que el teléfono ya posee"*. Flutter ya
tiene, on-device y sin red, exactamente los mismos datos que `digital_twin.py` necesitaba
— `StatsRepository`, `GoalRepository`, `RecoveryRepository`, `GamificationRepository`,
`ProfileRepository` — así que arma un `CoachContext` compacto (contrato completo en
`docs/COACH_CONTEXT.md`) y lo manda entero en el request de chat.

El backend queda reducido a exactamente 5 responsabilidades, ninguna más:

1. Validar el JWT de Supabase.
2. Verificar límites de uso (rate limiting — cuántos mensajes por usuario/minuto u hora,
   para no dejar la key del LLM expuesta a abuso).
3. Anteponer el system prompt.
4. Mandar la petición al LLM.
5. Devolver la respuesta.

Nada de tool-calling contra una base de datos propia ni contra Supabase. Si el LLM no
tiene suficiente información en el `CoachContext` para responder algo con precisión (p.
ej. una fecha muy vieja fuera de la ventana de "entrenamientos recientes" que manda el
cliente), el `SYSTEM_PROMPT` ya le indica que debe decirlo explícitamente en vez de
inventar — no que pida una herramienta. Esto elimina por completo el mecanismo de
segundo round-trip (`needs_tool_data`) que tenía la versión anterior de este documento.

**Backend 100% stateless — sin ninguna persistencia propia:**
- Sin PostgreSQL, sin SQLAlchemy, sin Alembic, sin modelos.
- Sin sincronización de ningún tipo (eso ya lo resuelve `SyncEngine`).
- Sin tablas propias de ninguna clase — ni siquiera para el rate limiting (se puede hacer
  en memoria de proceso o, si hace falta que sobreviva a reinicios/escale a más de una
  instancia, con un store externo simple como Redis — pero eso es un detalle de
  infraestructura, no una tabla de dominio, y no es indispensable para la v1).

## 3. Arquitectura

### Lado del cliente — capas para desacoplar el proveedor de IA

El usuario pidió una interfaz intermedia para poder cambiar de proveedor de LLM (Groq →
OpenAI/Gemini/Claude/Ollama) sin tocar la UI:

```
CoachChatScreen
      │
      ▼
CoachProvider (estado del chat: mensajes, loading, error — patrón Provider ya usado
                por AuthProvider/ThemeProvider en el resto de la app)
      │
      ▼
CoachRepository (orquesta: pide el CoachContext al builder, agrega la pregunta del
                 usuario, llama a CoachGateway, devuelve la respuesta)
      │
      ▼
CoachContextBuilder (arma el CoachContext v1 combinando ProfileRepository/
                     GoalRepository/StatsRepository/RecoveryRepository/
                     GamificationRepository — con la ventana acotada y el
                     resumen de entrenamientos recientes, ver
                     docs/COACH_CONTEXT.md)
      │
      ▼
CoachContext v1 (objeto de datos puro, sin lógica — el contrato)
      │
      ▼ (vuelve a CoachRepository, que arma el request)
CoachGateway (interfaz abstracta: sendMessage(question, context) -> reply — el único
              punto que sabe la URL/forma del backend inteligente)
      │
      ▼
Backend inteligente (HTTP)
```

`CoachContextBuilder` es una clase separada de `CoachRepository` a propósito: su única
responsabilidad es transformar el estado de los repositorios en el objeto `CoachContext`
(incluyendo el resumen/truncado descrito en `docs/COACH_CONTEXT.md`), sin saber nada de
HTTP ni del backend — se puede testear con `AppDatabase.forTesting` igual que
`GoalRepositoryTest`/`RecoveryRepositoryTest`, sin mockear ninguna red.

`CoachGateway` es la interfaz (análoga a `AuthRepository` en la Fase 1): una clase
abstracta con una implementación real (`HttpCoachGateway`, habla con el backend
inteligente) y, si hiciera falta, una implementación *unavailable* para cuando
`SmartBackendAvailability.isConfigured` es `false` (mismo patrón que
`UnavailableAuthRepository`). Cambiar de proveedor de LLM en el futuro es un cambio
**solo dentro del backend** (ver sección 7) — `CoachGateway` no necesita saberlo, ya
manda `CoachContext` + pregunta y recibe una respuesta de texto sin importar qué LLM la
generó.

### Extremo a extremo

```
┌──────────────────────────┐        ┌───────────────────────────┐        ┌─────────┐
│ Flutter (NexFit)          │ HTTPS  │ Backend inteligente        │ HTTPS  │  LLM    │
│                           │───────►│ (stateless, standalone)    │───────►│ (Groq,  │
│ StatsRepository           │        │                            │◄───────│ swap-   │
│ GoalRepository            │        │ 1. Valida JWT de Supabase  │        │ eable)  │
│ RecoveryRepository        │        │ 2. Rate limit              │        └─────────┘
│ GamificationRepository    │        │ 3. Antepone system prompt  │
│ ProfileRepository         │        │ 4. Llama al LLM            │
│      │                    │        │ 5. Devuelve la respuesta   │
│      ▼                    │        │                            │
│ CoachRepository           │        │ Sin DB, sin Alembic, sin   │
│      │                    │        │ SQLAlchemy, sin tool-      │
│      ▼                    │        │ calling contra ninguna DB  │
│ CoachGateway ─────────────┘        └───────────────────────────┘
└──────────────────────────┘
```

Puntos clave de aislamiento:
- **Repo/deploy separado** del resto del backend legado (`backend/` actual queda tal cual,
  ver Fase 5 para su apagado). Este backend inteligente puede vivir en un directorio nuevo
  (`backend_ia/` o similar) o directamente migrarse a una Supabase Edge Function (Deno) —
  la decisión entre servidor propio vs. Edge Function queda abierta para cuando se
  implemente, pero el diseño de este documento (endpoints, auth, contrato) es el mismo en
  cualquiera de los dos.
- **Sin base de datos propia, sin excepción** — a diferencia de la versión anterior de
  este documento, ya no queda ni siquiera la alternativa "B" de reenviar el JWT a
  Supabase. Cero conexión a ninguna base de datos desde este backend.
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
sección 7.1 de `ARQUITECTURA_BACKEND.md`). Ese mismo `sub` es la clave que usa el rate
limiting del punto siguiente (contador en memoria/Redis por uuid, no por IP).

## 5. Endpoints propuestos

Todos bajo `/api/v1/coach`, mismo prefijo que hoy para minimizar el cambio del lado del
cliente.

### `POST /api/v1/coach/chat`

Reemplaza al endpoint actual. Request:

```json
{
  "question": "¿Cómo viene mi progreso esta semana?",
  "context": { "...": "ver docs/COACH_CONTEXT.md para el esquema completo" }
}
```

`context` es exactamente el objeto `CoachContext` definido en `docs/COACH_CONTEXT.md` —
ese documento es el contrato fuente de verdad entre Flutter y este backend, no se
redefine acá. Lo arma `CoachRepository` combinando los repositorios ya existentes, sin
ninguna query nueva.

Response:

```json
{ "reply": "Vas bien: 3 días de racha y el volumen semanal se mantiene..." }
```

No hay ningún campo de "necesito más datos" ni segundo round-trip — si el contexto no
alcanza, el modelo lo dice en `reply` (instrucción explícita del `SYSTEM_PROMPT`, igual
que hoy).

### `GET /api/v1/coach/status`

Reemplaza el chequeo que hoy hace `SmartBackendAvailability` mirando si
`SMART_BACKEND_URL` está seteado en el cliente. Sin autenticación (público, solo dice si
el servicio está operativo):

```json
{ "available": true }
```

`available: false` si falta la API key del LLM en el backend — consultable antes de
mandar un mensaje (hoy el cliente se entera recién al fallar el POST con 503). No expone
qué proveedor/modelo corre detrás — es un detalle interno (sección 7).

### Sin más endpoints

No hay `/coach/context-preview` (era para debug, no lo usa ninguna pantalla), ni ningún
endpoint de datos de usuario, ni ninguna ruta de tool-calling — ese es exactamente el
punto de este rediseño.

## 6. Integración con el Coach IA (cliente)

- `CoachChatScreen` deja de usar `CoachService`/`ApiClient` (legado, roto) y pasa a
  consumir `CoachProvider` (estado del chat) → `CoachRepository` (arma el `CoachContext`
  + llama a `CoachGateway`) → `CoachGateway` (interfaz, implementación HTTP real) — ver
  sección 3.
- `CoachRepository` arma el `CoachContext` leyendo `ProfileRepository`,
  `GoalRepository.list()`, `StatsRepository` (perfil de fuerza, racha, tonelaje reciente),
  `RecoveryRepository.index()` y `GamificationRepository.profile()` — sin ninguna query
  nueva, solo reutilizar lo que esos repositorios ya exponen desde las Fases 2/3.
- `SmartBackendAvailability`/`ComingSoonView` (ya existen en el cliente desde la Fase 0,
  sin usar todavía) pasan a consultar `GET /coach/status` en vez de solo mirar si
  `SMART_BACKEND_URL` no está vacío — cubre también el caso "el servidor está desplegado
  pero sin la key del LLM configurada".

## 7. Integración con el LLM (Groq, intercambiable)

Se reutiliza el diseño actual de `llm_client.ask_llm` (cliente HTTP genérico contra una
API compatible con OpenAI — `chat/completions`), pero **sin tool-calling** (se elimina esa
parte por completo, ver sección 2) y detrás de una interfaz interna del backend
(`LlmProvider`/equivalente) para que cambiar de Groq a OpenAI/Gemini/Claude/Ollama sea
solo una implementación nueva de esa interfaz + variables de entorno, sin tocar los
endpoints ni el contrato con Flutter:
- Configurable por variables de entorno (`LLM_BASE_URL`, `LLM_API_KEY`, `LLM_MODEL`).
- El mismo `SYSTEM_PROMPT` (ajustado para explicitar que el contexto viene ya armado del
  cliente y es todo lo que el modelo va a tener disponible — sin herramientas).
- El mismo manejo de "LLM no configurado" → 503, ahora también reflejado en
  `GET /coach/status`.

## 8. Qué se elimina o no se lleva a este backend

- `app/models/`, `app/core/database.py`, Alembic, SQLAlchemy — no hacen falta, el backend
  es 100% stateless. Cero conexión a ninguna base de datos, propia o de terceros.
- `app/core/security.py` (JWT/bcrypt propios) — reemplazado por la verificación de JWT de
  Supabase (sección 4).
- `app/deps.get_current_user` — reemplazado por la verificación de Supabase.
- `ACTIVITY_LOG_TOOL`/tool-calling completo (`app/services/digital_twin.get_activity_log`,
  el parámetro `tools`/`tool_executor` de `llm_client.ask_llm`) — eliminado, no se lleva
  ninguna forma de que el backend vuelva a pedir datos.
- Todo lo demás de `backend/app/` (rutinas, objetivos, nutrición, stats, gamificación,
  etc.) — no se toca, no se lleva, queda para apagar en la Fase 5 según el inventario de
  la sección 7.1 de `ARQUITECTURA_BACKEND.md`.

## 9. Variables de entorno del backend inteligente

Solo las estrictamente necesarias — ninguna relacionada a Postgres/Alembic/auth propio:

| Variable | Propósito |
|---|---|
| `SUPABASE_URL` | Para verificar el JWT contra `/auth/v1/user` (o el JWKS si se optimiza después). Es la misma URL pública que ya usa el cliente. |
| `LLM_API_KEY` | Key del proveedor de LLM activo (Groq por defecto). |
| `LLM_BASE_URL` | Default `https://api.groq.com/openai/v1`. |
| `LLM_MODEL` | Default `llama-3.3-70b-versatile`. |
| `RATE_LIMIT_PER_MINUTE` | Límite de mensajes por usuario (uuid de Supabase) — protege la key del LLM de abuso. Valor por decidir en la implementación. |
| `CORS_ORIGINS` | Igual que hoy. |

## 10. Próximos pasos (orden acordado con el usuario)

1. ✅ Consolidar la auditoría (`docs/ARQUITECTURA_BACKEND.md` sección 7).
2. ✅ Definir el contrato `CoachContext` — `docs/COACH_CONTEXT.md`.
3. ✅ Revisar y aprobar ese contrato con el usuario — **aprobado 2026-07-12 como v1**,
   con los 10 ajustes de la revisión (versión, `app`, split profile/preferences/settings,
   `capabilities`, regla de ventana configurable, resumen en vez de volcado completo,
   presupuesto de tokens, `extensions`, `sessionId`, `generatedAt`).
4. **Implementar el backend inteligente mínimo y completamente stateless** (este
   documento) — pendiente de la orden explícita del usuario para empezar.
5. Conectar Flutter mediante `CoachContextBuilder` → `CoachRepository` →
   `CoachProvider`/`CoachGateway`.
6. Dejar Groq como un detalle interno del backend, intercambiable por cualquier otro
   proveedor sin tocar Flutter.

El contrato quedó congelado como v1 (`docs/COACH_CONTEXT.md`). No se implementa nada de
esto hasta recibir la orden explícita del usuario de empezar la Fase 4.
