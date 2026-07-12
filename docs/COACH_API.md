# Contrato HTTP del backend inteligente (`COACH_API.md`)

**Estado: aprobado por el usuario el 2026-07-12, congelado como v1.** Ningún código de
este documento existe todavía — es la interfaz que implementará el backend inteligente y
consumirá `CoachGateway` cuando se dé la orden explícita de empezar la Fase 4 (ver
`docs/FASE_4_DISENO.md`). Complementa a `docs/COACH_CONTEXT.md` (el objeto `context`) y a
`docs/COACH_SYSTEM_PROMPT.md` (lo que el backend antepone antes de llamar al LLM).

## Base URL

Un solo servicio, todos los endpoints bajo `/api/v1/coach` (mismo prefijo que el backend
legado, para minimizar el cambio de configuración del lado del cliente — ver
`SmartBackendAvailability` en `docs/FASE_4_DISENO.md` sección 6).

---

## `POST /api/v1/coach/chat`

Envía un mensaje del usuario al Coach IA junto con su contexto y recibe la respuesta del
LLM.

### Headers

```
Authorization: Bearer <Supabase JWT>
Content-Type: application/json
```

El JWT es el `access_token` de la sesión de Supabase ya activa en el cliente
(`supabase_flutter`) — no hay ningún login propio de este backend (ver
`docs/FASE_4_DISENO.md` sección 4 para el mecanismo de verificación).

### Request body

```json
{
  "sessionId": "b3f1c2b0-6e9d-4b3a-9e2e-1a2b3c4d5e6f",
  "message": "¿Cómo viene mi progreso esta semana?",
  "context": { "...": "objeto CoachContext v1 completo -- ver docs/COACH_CONTEXT.md" }
}
```

| Campo | Tipo | Obligatorio | Descripción |
|---|---|---|---|
| `sessionId` | string (uuid) | Sí | Identificador de la conversación, generado por el cliente al abrir el chat (no cambia entre mensajes de la misma conversación). Mismo valor que `context.sessionId` — viaja en ambos niveles: acá para poder loguear/trazar la request antes de siquiera validar el resto del body, y dentro de `context` porque forma parte del bundle que ve el modelo/logging de negocio. |
| `message` | string | Sí | La pregunta o mensaje del usuario, tal cual lo escribió. |
| `context` | objeto | Sí | `CoachContext` v1 completo — ver `docs/COACH_CONTEXT.md` para el esquema. El backend no lo completa ni lo corrige, solo lo usa para armar el prompt. |

### Response — 200 OK

```json
{
  "reply": "Vas bien: 3 días de racha y el volumen semanal se mantiene estable...",
  "model": "groq/llama-3.3-70b-versatile",
  "usage": {
    "promptTokens": 512,
    "completionTokens": 128,
    "totalTokens": 640
  }
}
```

| Campo | Tipo | Descripción |
|---|---|---|
| `reply` | string | Respuesta del Coach, lista para mostrar tal cual en el chat. |
| `model` | string | Identificador del proveedor+modelo que generó la respuesta (ej. `"groq/llama-3.3-70b-versatile"`). Informativo — el cliente no debe tomar decisiones de comportamiento en base a este valor, solo mostrarlo si hace falta para debug/soporte. |
| `usage` | objeto | Conteo de tokens de la llamada al LLM (`promptTokens`, `completionTokens`, `totalTokens`). Sirve para observabilidad de costo — el cliente no necesita mostrarlo, pero el backend siempre lo devuelve para que quede logueado en cualquier capa que sí lo consuma. |

No hay ningún campo de "necesito más datos" ni segundo round-trip — si el `context` no
alcanza para responder algo con precisión, el modelo lo dice dentro de `reply`, según la
instrucción explícita del system prompt (`docs/COACH_SYSTEM_PROMPT.md`).

### Errores

Todos los errores devuelven el mismo sobre (`envelope`) para que el cliente no tenga que
adivinar la forma según el código:

```json
{
  "error": {
    "code": "rate_limited",
    "message": "Superaste el límite de mensajes por minuto. Probá de nuevo en unos segundos."
  }
}
```

| HTTP | `error.code` | Cuándo pasa | Qué debe hacer el cliente |
|---|---|---|---|
| `400` | `invalid_request` | Body malformado: falta `message`/`context`/`sessionId`, `context.version` no es un entero soportado, o el JSON no parsea. | Mostrar el mensaje de error tal cual (son mensajes pensados para mostrarse) — es un bug del cliente, no algo que el usuario pueda resolver reintentando. |
| `400` | `context_too_large` | El `context` serializado supera el límite duro del servidor (ver presupuesto de tamaño en `docs/COACH_CONTEXT.md` — el servidor puede rechazar en vez de truncar). | El cliente debería haber truncado antes de mandar (regla de `CoachContextBuilder`) — si pasa, es un bug del builder, reportar/loguear. |
| `401` | `unauthorized` | JWT ausente, inválido o expirado. | Refrescar la sesión de Supabase (`supabase_flutter` ya maneja el refresh automático, ver Fase 1) y reintentar una vez; si sigue fallando, llevar al login. |
| `403` | `forbidden` | JWT válido pero la cuenta no tiene permiso de usar el Coach (ej. una futura restricción de plan/moderación — no existe ningún caso real todavía, el código queda reservado). | Mostrar el mensaje del servidor, no reintentar automáticamente. |
| `429` | `rate_limited` | Se superó el límite de mensajes por usuario en la ventana configurada (`RATE_LIMIT_PER_MINUTE`, ver `docs/FASE_4_DISENO.md` sección 9). Incluye header `Retry-After: <segundos>`. | Esperar el tiempo de `Retry-After` antes de reintentar; deshabilitar el botón de enviar mientras tanto. |
| `500` | `internal_error` | Error inesperado en el backend (bug, respuesta del LLM en un formato no esperado, etc.). | Mostrar un mensaje genérico ("Algo salió mal, probá de nuevo") y permitir reintentar manualmente. |
| `503` | `llm_unavailable` | Falta configurar la API key del proveedor de LLM en el backend (mismo criterio que hoy expone `GET /coach/status`). | Mostrar el mismo aviso que ya existe hoy en `CoachChatScreen` ("El chat con IA todavía no está activado..."). |
| `504` / timeout de cliente | `timeout` | El backend no obtuvo respuesta del proveedor de LLM dentro del timeout configurado (recomendado: 30s, mismo valor que ya usa `llm_client` hoy). El cliente debería aplicar su propio timeout HTTP igual o levemente mayor (ej. 35s) para no quedarse esperando indefinidamente si la respuesta del servidor se pierde en la red. | Mostrar "El Coach tardó demasiado en responder, probá de nuevo" y permitir reintentar. No reintentar automáticamente sin confirmación del usuario (evita duplicar llamadas al LLM, que tienen costo). |

---

## `GET /api/v1/coach/status`

Chequeo de disponibilidad, público (sin `Authorization`) — reemplaza el chequeo que hoy
hace `SmartBackendAvailability` mirando solo si `SMART_BACKEND_URL` no está vacío.

### Response — 200 OK

```json
{ "available": true }
```

`available: false` si falta la API key del proveedor de LLM configurada en el backend
(mismo caso que dispara `503 llm_unavailable` en `/chat`). No expone qué proveedor/modelo
corre detrás — el cliente no debe tomar ninguna decisión de UI en base a eso, es un
detalle interno intercambiable (`docs/FASE_4_DISENO.md` sección 7).

Este endpoint **nunca** devuelve error 401/403/429 — si el servicio está caído del todo,
el cliente lo verá como una falla de red normal (timeout/connection refused), no como un
error de este contrato.

---

## Qué no expone esta API (a propósito)

- Ningún endpoint de datos de usuario (perfil, rutinas, objetivos, etc.) — todo eso ya
  vive en Supabase, este backend no los sirve ni los espeja.
- Ningún endpoint de tool-calling ni de consulta de historial por rango de fechas — se
  eliminó por completo (ver `docs/FASE_4_DISENO.md` sección 2).
- `/coach/context-preview` del backend legado no se lleva — era solo para debug del
  diseño anterior, ninguna pantalla lo usa.

## Próximo paso

Con `docs/COACH_CONTEXT.md`, este documento y `docs/COACH_SYSTEM_PROMPT.md` aprobados, el
diseño de la Fase 4 queda completo. Falta únicamente la orden explícita del usuario para
empezar la implementación (`docs/FASE_4_DISENO.md` sección 10).
