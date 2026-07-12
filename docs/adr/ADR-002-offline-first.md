# ADR-002 — Dominios derivados on-device en vez de en un servidor

**Estado**: Aceptada e implementada (Fases 3 y 5, 2026-07-12).

## Contexto

Estadísticas, gamificación, calculadoras, catálogo de ejercicios, calendario inteligente
(recomendación de descarga + predicción de récords) y exportación/importación de datos
vivían como endpoints FastAPI que recalculaban sobre datos que, para entonces, ya estaban
duplicados en Drift (local) y Supabase (remoto). Ninguno de estos dominios tiene un dato
que *solo* exista en el servidor ni requiere un secreto que no pueda vivir en el cliente
— son agregaciones/cálculos puros sobre datos que la app ya tiene localmente.

## Decisión

Portar la lógica de estos dominios directamente a Flutter (`StatsRepository`,
`GamificationRepository`, `lib/core/calculators.dart`, `DataExportService`/
`DataImportService`, `StatsRepository.deloadRecommendation()`/
`upcomingRecordPredictions()` + `GoalRepository.list()` para el calendario), leyendo/
escribiendo Drift directo, en vez de mantenerlos como llamadas de red a un backend.

## Consecuencias

- Estos dominios funcionan sin conexión y sin ningún backend desplegado — coherente con
  la decisión raíz del proyecto ("la app debe poder publicarse y usarse por completo sin
  depender de un backend FastAPI desplegado", `ARQUITECTURA_BACKEND.md` §1).
- La lógica portada replica fórmulas exactas del backend original (umbrales, ventanas de
  tiempo, regresión lineal para predicción de récords) para no introducir regresiones de
  comportamiento — documentado inline con referencia al archivo Python de origen
  (`legacy/backend_fastapi/app/services/...`).
- El formato de exportación/importación es propio del cliente (JSON versionado con
  `version` obligatorio e ignorado de campos/entidades desconocidas para forward
  compatibility) — no necesita coincidir con el schema Pydantic del backend, porque el
  backend se retira por completo.
- Social/retos es la única excepción deliberada: queda contra Supabase en vivo, sin caché
  local, porque el leaderboard es una agregación multiusuario que no tiene sentido
  duplicar on-device.
