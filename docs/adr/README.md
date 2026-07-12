# Architecture Decision Records

Registro de *por qué* se tomaron las decisiones importantes de arquitectura de NexFit —
no de *cómo* funciona el sistema hoy (eso lo cubre
[`docs/ARQUITECTURA_BACKEND.md`](../ARQUITECTURA_BACKEND.md)).

Formato por ADR: Contexto → Decisión → Consecuencias. Un ADR no se edita para reflejar
cambios futuros — si una decisión se revierte, se agrega un ADR nuevo que la referencia y
la reemplaza; el original queda como registro histórico.

| # | Decisión |
|---|---|
| [001](./ADR-001-supabase-auth.md) | Migrar Auth de FastAPI/JWT propio a Supabase Auth |
| [002](./ADR-002-offline-first.md) | Dominios derivados (stats, gamificación, calculadoras, calendario, export/import) on-device en vez de en un servidor |
| [003](./ADR-003-coach-backend.md) | Coach IA en un backend mínimo y sin base de datos propia (`backend_ia`) |
| [004](./ADR-004-archive-fastapi.md) | Archivar el backend FastAPI original en vez de eliminarlo |
