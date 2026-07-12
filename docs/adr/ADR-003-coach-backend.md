# ADR-003 — Coach IA en un backend mínimo y sin base de datos propia

**Estado**: Aceptada e implementada (Fase 4, 2026-07-12).

## Contexto

El chat con IA (tool-calling sobre el historial del usuario) es el único dominio que
genuinamente no puede vivir en el cliente ni resolverse con Supabase directo: necesita
sostener la API key de un LLM (Groq) sin exponerla en el APK. La implementación original
(`digital_twin.py` dentro de FastAPI) leía de tablas propias de la base de datos del
backend, que quedaron vacías/obsoletas desde que el resto de los dominios migró a
Supabase en la Fase 2 — el Coach quedó roto (401 + contexto vacío) mucho antes de que se
decidiera qué hacer con él.

## Decisión

Aislar el Coach IA en un servicio propio, `backend_ia/`, sin relación de código con el
FastAPI legado y sin base de datos propia: el contexto del usuario se arma en el cliente
(`CoachContextBuilder`) y se envía ya construido; `backend_ia` solo orquesta la llamada al
LLM y el tool-calling sobre ese contexto. El cliente accede a través de
`CoachRepository` → `CoachGateway` (`HttpCoachGateway` si `SmartBackendAvailability.
isConfigured`, `ComingSoonView` si no).

## Consecuencias

- `backend_ia` no tiene su propio almacenamiento de datos de usuario que pueda quedar
  desincronizado de Supabase — el contexto siempre viene fresco del cliente en cada
  request, eliminando la clase de bug que rompió el Coach original.
- El Coach IA es la única función de la app que requiere un servicio desplegado; si
  `SMART_BACKEND_URL` no está configurado, la app entera sigue funcionando y esa pantalla
  degrada a `ComingSoonView` en vez de fallar.
- `backend_ia` se despliega y versiona independiente del resto del backend legado
  (`legacy/backend_fastapi/`, ver ADR-004) — no comparten pipeline ni repo lógico.
