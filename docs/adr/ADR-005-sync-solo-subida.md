# ADR-005 — Sync sigue siendo solo de subida; no se implementa `pull`/restore en Fase 1

**Estado**: Aceptada (Fase 1 de `docs/AUDITORIA_2026-09-03.md`, 2026-09-03).

## Contexto

`docs/AUDITORIA_2026-09-03.md` (C3) documenta que `SyncableEntity` (`lib/core/sync/syncable.dart`)
solo declara `push(AppDatabase db)`: ninguna entidad (`ProfileSyncable`, `WorkoutSessionSyncable`,
`RoutineSyncable`, etc.) ni `SyncEngine` implementan una ruta de bajada. Consecuencia real:
reinstalar la app o cambiar de teléfono pierde todo el historial local, aunque Ajustes lo
presentaba como "Mis datos (backup)" y hablaba de "subir a la nube" — un texto que sugiere
restauración automática que la app no ofrece.

El documento de auditoría plantea dos salidas y pide decidir una y documentarla:
- (a) Implementar `pull` en `SyncableEntity` + resolución de conflictos por `updatedAt`,
  empezando por `ProfileSyncable` y `WorkoutSessionSyncable`.
- (b) Dejar el sync como está y corregir el copy de Ajustes para no prometer un backup
  restaurable.

## Decisión

**(b)** — no se implementa `pull`/restore en esta fase. Se corrige el copy de
`lib/screens/settings/settings_screen.dart` para que no prometa una restauración que no
existe: la sección pasa de "Mis datos (backup)" a "Mis datos", y el texto ahora dice
explícitamente que exportar/importar manual es *la única forma de recuperar el historial hoy*
si se reinstala o se cambia de teléfono.

Motivo: (a) es la orden de mayor esfuerzo de todo el roadmap (5 sobre la escala del
documento) y toca `SyncableEntity` y cada entidad sincronizable — arquitectura central que
excede el alcance de "Fase 1: integridad de datos" (bloqueante, cambios quirúrgicos). El
riesgo real hoy no es la ausencia de `pull` en sí, sino que la UI **miente** sobre lo que el
sync hace. Arreglar la mentira es la orden C3 real y correcta para esta fase; implementar
`pull` completo queda pendiente para una fase posterior, con su propio scope (resolución de
conflictos, qué entidades primero, qué pasa con ids locales vs. `serverId`).

## Consecuencias

- El único camino de restauración sigue siendo el export/import manual de
  `DataExportService`/`DataImportService` (JSON versionado, ver ADR-002). La UI ahora lo dice
  explícitamente en vez de sugerir un backup automático.
- `ProfileScreen` sigue leyendo la tabla local `profiles`, que no se puebla desde el servidor
  al loguearse en un dispositivo nuevo — sigue siendo un problema real, pero es consecuencia
  directa de esta misma decisión (sin `pull`, no hay de dónde poblarla) y no un bug nuevo. No
  se toca en Fase 1.
- Implementar `pull` real (opción a) queda como trabajo futuro explícito, no descartado —
  cuando se aborde, empezar por `ProfileSyncable` (el caso más visible, perfil vacío tras
  login) y `WorkoutSessionSyncable` (el de mayor impacto), con resolución de conflictos por
  `updatedAt` tal como propone la auditoría.
