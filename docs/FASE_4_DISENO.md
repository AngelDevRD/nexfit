# Fase 4 — Diseño del backend inteligente

Estado: **diseño aprobado 2026-07-12** (contratos `CoachContext`, `COACH_API`,
`COACH_SYSTEM_PROMPT` congelados) y **backend implementado y verificado el mismo día**
en `backend_ia/` (pasos 1-8 del orden acordado — ver sección 10 y
`backend_ia/README.md`). Pendiente: integración con Flutter (pasos 9-10).

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

### Extremo a extremo (diagrama definitivo)

```
Flutter
  │
  ▼
Repositories (Stats/Goal/Recovery/Gamification/Profile)
  │
  ▼
CoachContextBuilder
  │
  ▼
CoachContext v1
  │
  ▼
CoachRepository
  │
  ▼
CoachGateway
  │
  ▼
Backend IA (stateless, standalone, repo/deploy separado)
  │
  ▼
JWT Validator (Supabase)
  │
  ▼
Rate Limiter
  │
  ▼
LLMProvider ──► Groq / OpenAI / Gemini / Claude / Ollama
  │
  ▼
System Prompt (docs/COACH_SYSTEM_PROMPT.md)
  │
  ▼
Respuesta ──► Flutter
```

Sin DB, sin Alembic, sin SQLAlchemy, sin tool-calling contra ninguna base — en ningún
punto de este flujo el backend consulta Supabase ni ninguna otra base de datos.

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

**Contrato HTTP completo (headers, request, response, códigos de error) congelado en
`docs/COACH_API.md`** — no se repite acá para no tener dos fuentes de verdad. Resumen:

- `POST /api/v1/coach/chat` — reemplaza al endpoint actual. Body: `{ sessionId, message,
  context }`, donde `context` es exactamente el objeto `CoachContext` de
  `docs/COACH_CONTEXT.md`. Sin ningún campo de "necesito más datos" ni segundo
  round-trip — si el contexto no alcanza, el modelo lo dice en `reply` (instrucción
  explícita del system prompt, ver `docs/COACH_SYSTEM_PROMPT.md`).
- `GET /api/v1/coach/status` — reemplaza el chequeo que hoy hace
  `SmartBackendAvailability` mirando si `SMART_BACKEND_URL` está seteado en el cliente.
  Sin autenticación, dice si el servicio está operativo sin exponer qué proveedor/modelo
  corre detrás (detalle interno, sección 7).
- Sin más endpoints — no hay `/coach/context-preview` (era para debug, no lo usa ninguna
  pantalla), ni ningún endpoint de datos de usuario, ni ninguna ruta de tool-calling.

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

## 7. Integración con el LLM — interfaz `LLMProvider`, ningún SDK específico

Regla explícita del usuario: el backend **nunca depende de un SDK de proveedor
concreto**, solo de una interfaz propia:

```
LLMProvider (interfaz abstracta: complete(systemPrompt, userMessage) -> LlmReply)
    │
    ├── GroqProvider     (implementación real para arrancar — API compatible con OpenAI)
    ├── OpenAIProvider   (futura)
    ├── GeminiProvider   (futura)
    ├── ClaudeProvider   (futura)
    └── OllamaProvider   (futura, para correr un modelo local/self-hosted)
```

El resto del backend (validación de JWT, rate limiting, endpoints) solo conoce
`LLMProvider` — nunca importa `httpx` apuntando directo a Groq ni ningún detalle de un
proveedor puntual fuera de la implementación de su propio `*Provider`. Cambiar de
proveedor es: implementar una clase nueva que cumpla `LLMProvider` + cambiar qué
implementación se inyecta (por variable de entorno, ej. `LLM_PROVIDER=groq`) — cero
cambios en endpoints, en el contrato con Flutter, ni en `CoachGateway`.

- **`GroqProvider`** (primera implementación): reutiliza el diseño actual de
  `llm_client.ask_llm` — cliente HTTP contra una API compatible con OpenAI
  (`chat/completions`) — pero **sin tool-calling** (se elimina esa parte por completo,
  ver sección 2). Configurable por variables de entorno (`LLM_BASE_URL`, `LLM_API_KEY`,
  `LLM_MODEL`).
- **System prompt**: vive en `docs/COACH_SYSTEM_PROMPT.md` como recurso versionado, no
  incrustado en el código — el backend lo carga desde ahí (archivo/recurso), no lo
  redefine. Ver ese documento para personalidad, tono, límites y reglas de seguridad.
- El mismo manejo de "LLM no configurado" → 503, ahora también reflejado en
  `GET /coach/status`. Detalle completo de códigos de error en `docs/COACH_API.md`.

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
2. ✅ Definir el contrato `CoachContext` — `docs/COACH_CONTEXT.md`, **aprobado 2026-07-12
   como v1** con los 10 ajustes de esa revisión (versión, `app`, split
   profile/preferences/settings, `capabilities`, regla de ventana configurable, resumen en
   vez de volcado completo, presupuesto de tokens, `extensions`, `sessionId`,
   `generatedAt`).
3. ✅ Definir el contrato HTTP público — `docs/COACH_API.md`, **aprobado 2026-07-12**:
   endpoint, headers, request/response, y los 7 códigos de error (`400`, `401`, `403`,
   `429`, `500`, `503`, timeout) con su sobre de error uniforme.
4. ✅ Definir el system prompt como recurso versionado, separado del código —
   `docs/COACH_SYSTEM_PROMPT.md`, **aprobado 2026-07-12**: personalidad, límites, cómo
   responder con datos faltantes o funciones no disponibles, criterios de seguridad.
5. ✅ Formalizar la interfaz `LLMProvider` (sección 7) — el backend nunca depende de un
   SDK de proveedor específico, solo de esa interfaz; `GroqProvider` es la primera
   implementación.
6. ✅ **Implementado el backend inteligente mínimo y completamente stateless** —
   `backend_ia/` (2026-07-12), siguiendo el orden de capas pedido por el usuario:
   1. Estructura base (`backend_ia/app/`, `requirements.txt`, `pytest.ini`, `ruff.toml`).
   2. Interfaz `LLMProvider` (`app/llm/base.py`).
   3. `GroqProvider` (`app/llm/groq_provider.py`) — sin tool-calling, solo
      `chat/completions`.
   4. Validación de JWT de Supabase (`app/auth.py`, variante simple contra
      `GET /auth/v1/user`).
   5. Rate limiter en memoria por usuario (`app/rate_limiter.py`).
   6. Carga de `COACH_SYSTEM_PROMPT` como recurso versionado
      (`app/prompt.py` + `prompts/coach_system_v1.txt`).
   7. `POST /api/v1/coach/chat` (`app/routes/coach.py`).
   8. `GET /api/v1/coach/status` (mismo archivo).

   **Verificado en cada paso** (regla 4 de la orden de implementación): 37 tests
   (`pytest`) + `ruff check .` en verde tras cada componente. Incidencia encontrada y
   corregida durante las pruebas del rate limiter: `InMemoryRateLimiter` reventaba con
   `IndexError` cuando `max_requests_per_window=0` (caso límite sin ningún hit previo del
   que calcular el `Retry-After`) — corregido y cubierto con un test específico antes de
   seguir. Detalle completo en `backend_ia/README.md`.

7. ✅ **Conectada la integración con Flutter** (2026-07-12), con las capas exactas
   aprobadas por el usuario (incluido el ajuste de último momento:
   `CoachContextSource` como interfaz de lectura, para que `CoachContextBuilder` no
   conozca ningún repositorio concreto):

   ```
   CoachChatScreen → CoachProvider → CoachRepository → CoachContextBuilder
                                            │                   │
                                            │             CoachContextSource
                                            │           (DefaultCoachContextSource)
                                            ▼
                                       CoachGateway (HttpCoachGateway)
   ```

   - `lib/core/coach/coach_context_source.dart` — interfaz `CoachContextSource` +
     `DefaultCoachContextSource` (combina `ProfileRepository`/`GoalRepository`/
     `RecoveryRepository`/`StatsRepository`/`GamificationRepository` y una lectura
     directa de `AppDatabase` para `recentWorkouts`/`personalRecords`, mismo patrón de
     lectura que ya usa `StatsRepository`).
   - `lib/core/coach/coach_context_builder.dart` — **puro**: no importa `http`,
     Supabase, FastAPI, Groq ni ningún widget. Aplica la ventana de 10
     sesiones/14 días, condensa `exerciseSummaries` (un resumen por ejercicio, no
     serie por serie) y el orden de recorte de tamaño de `docs/COACH_CONTEXT.md`
     (15KB) si hiciera falta.
   - `lib/core/coach/coach_exception.dart` — el único modelo de error que ve la UI
     (`CoachUnauthorizedException`, `CoachForbiddenException`,
     `CoachRateLimitedException`, `CoachInvalidContextException`,
     `CoachUnavailableException`, `CoachTimeoutException`, `CoachUnknownException`).
   - `lib/core/coach/coach_gateway.dart` + `http_coach_gateway.dart` — interfaz +
     única implementación HTTP, exactamente `docs/COACH_API.md` (request/response,
     mapeo de cada `error.code` y de los status HTTP de respaldo a su
     `CoachException`). Sin lógica de negocio, sin armar contexto.
   - `lib/repositories/coach_repository.dart` — único punto de entrada de la UI;
     mantiene un `sessionId` (uuid v4 generado localmente, sin dependencia nueva)
     estable durante toda la conversación y arma el `CoachContext` **bajo demanda**,
     solo al mandar un mensaje (nunca de forma continua).
   - `lib/providers/coach_provider.dart` — estado del chat (`ChangeNotifier`),
     traduce cada `CoachException` a un mensaje de chat sin que la UI interprete
     ningún código HTTP.
   - `lib/screens/coach/coach_chat_screen.dart` — único archivo de pantalla tocado;
     si `SmartBackendAvailability.isConfigured` es `false` muestra `ComingSoonView`
     (ya existía desde la Fase 0, nunca se había conectado a una pantalla real).

   **Verificado** (regla 7 de la orden de implementación): 26 tests nuevos de Flutter
   (`CoachContextBuilder` 8, `HttpCoachGateway` 12, `CoachRepository` 6) +
   `flutter analyze lib/ test/` sin issues + `flutter test` 59/59 + `flutter build apk
   --release` exitoso (47.6MB) + `pytest`/`ruff` del backend re-verificados sin cambios
   (37/37, 0 issues). Solo se tocó `lib/screens/coach/coach_chat_screen.dart` entre los
   archivos ya existentes — ningún otro archivo de la app fue modificado.

El diseño y la implementación de la Fase 4 (contratos + backend + integración Flutter)
están **completos**. Pendiente, fuera de esta fase: `RoutineRepository` no tiene
concepto de "rutina activa", así que `CoachContext.preferences.trainingDaysPerWeek` queda
`null` por ahora (documentado en el código, no es un bug).
