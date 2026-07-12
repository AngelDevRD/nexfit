# ADR-004 — Archivar el backend FastAPI original en vez de eliminarlo

**Estado**: Aceptada e implementada (Fase 5, 2026-07-12).

## Contexto

Con ADR-001, ADR-002 y ADR-003 completos, ningún flujo de la app dependía ya del backend
FastAPI de 12 routers (confirmado por grep antes de cada borrado a lo largo de las Fases
1-5: cero importadores reales en `lib/`). El código representaba meses de trabajo real —
auth, CRUD de los 8 dominios de datos, cálculos de estadísticas/gamificación/calendario ya
usados como referencia para portar la lógica a Flutter (ADR-002) — y no estorbaba: no se
desplegaba, no lo construía ningún workflow de CI.

## Decisión

Mover `backend/` completo a `legacy/backend_fastapi/` (con historial de git preservado vía
rename, no un borrado + recreación) en vez de eliminarlo del repositorio. Se agrega un
aviso explícito al inicio de su `README.md` marcándolo como archivado, desconectado de la
app y reemplazado por Supabase + `backend_ia` + on-device.

## Consecuencias

- Se conserva el historial completo de implementación para consulta futura (p. ej. si
  aparece una duda sobre el comportamiento exacto de una fórmula portada en ADR-002) sin
  mantenerlo como código vivo.
- El código archivado no se actualiza ni se testea a partir de este punto — no forma parte
  de `flutter analyze`/`flutter test`/CI, y no debe usarse como base para trabajo nuevo.
- `docker-compose.yml` (orquestación local de desarrollo del backend, único consumidor de
  `Dockerfile`) se movió junto con el backend a `legacy/backend_fastapi/docker-compose.yml`
  — nunca fue parte de CI, así que este movimiento no tiene impacto en el pipeline.
- Si en el futuro se decide que ni siquiera vale la pena conservarlo como referencia, la
  eliminación completa queda como una decisión posterior y explícita (nuevo ADR), no un
  efecto colateral de esta.
