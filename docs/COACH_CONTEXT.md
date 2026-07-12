# Contrato `CoachContext` v1 — la "API" entre Flutter y el backend inteligente

**Estado: aprobado por el usuario el 2026-07-12. Congelado como versión 1.** Ningún
código de este documento existe todavía — es el contrato que implementará
`CoachContextBuilder` cuando se dé la orden explícita de empezar la Fase 4 (ver
`docs/FASE_4_DISENO.md` sección 10). Esta versión incorpora los 10 ajustes pedidos en la
revisión de aprobación (versión, `app`, split profile/preferences/settings,
`capabilities`, ventana configurable, resumen en vez de volcado completo, presupuesto de
tokens, `extensions`, `sessionId`, `generatedAt`).

## Propósito

`CoachContext` es el único objeto que Flutter le manda al backend inteligente junto con
la pregunta del usuario (`POST /api/v1/coach/chat`, ver `docs/FASE_4_DISENO.md` sección
5). Es el reemplazo completo de `digital_twin.build_user_context` (que hoy arma ese mismo
resumen en Python, consultando una base de datos que ya no recibe datos reales desde la
Fase 2) — acá lo arma el cliente, con datos que ya tiene local u offline-first.

Es un contrato, no una implementación: gracias al campo `version` y al espacio reservado
`extensions`, se puede evolucionar sin romper clientes ni backends viejos — la intención
explícita del usuario es que este contrato **cambie muy poco con el tiempo**.

## Quién lo arma

`CoachContextBuilder` (clase separada de `CoachRepository`, ver `docs/FASE_4_DISENO.md`
sección 3), combinando exclusivamente repositorios que ya existen — cero queries nuevas:

| Sección de `CoachContext` | Repositorio/fuente |
|---|---|
| `profile` | `ProfileRepository.get(userId)` |
| `preferences` | `ProfileRepository.get(userId)` (objetivo, experiencia) + config de rutina (`Routines.daysPerWeek`) |
| `settings` | Config del dispositivo/app (idioma, unidades, notificaciones) |
| `capabilities` | Disponibilidad real de cada dominio en esta sesión (ver sección "capabilities" abajo) |
| `goals` | `GoalRepository.list()` |
| `recovery` | `RecoveryRepository.index()` |
| `stats` | `StatsRepository.strengthProfile()` + `.streak()` |
| `recentWorkouts` | `WorkoutRepository` (sesiones/sets), resumidas y acotadas — ver regla de ventana |
| `personalRecords` | `PersonalRecords` locales (mismos que ya usa `GoalRepository`) |
| `achievements` | `GamificationRepository.profile()` |
| `sessionId`, `generatedAt`, `version`, `app` | Generados/leídos por `CoachContextBuilder` al momento de armar el contexto, no vienen de un repositorio de dominio |

## Esquema completo

```
CoachContext
├── version                int             -- =1 para este contrato. Permite evolucionar sin romper clientes/backends viejos.
├── sessionId              string (uuid)   -- generado por el cliente al abrir el chat (no por mensaje). Depuración/trazabilidad/métricas.
├── generatedAt            string (ISO 8601, con hora) -- cuándo se armó este contexto. El coach necesita saber qué tan reciente es.
│
├── app                     -- metadata de la aplicación/plataforma, no del usuario
│   ├── version              string          -- versión de la app (ej. "2.3.1")
│   ├── platform             "android" | "ios"
│   └── timezone             string          -- offset ISO 8601, ej. "-04:00"
│
├── profile                (puede venir con campos null si el usuario no completó el perfil)
│   ├── name                 string
│   ├── age                  int | null
│   ├── sex                  "male" | "female" | null
│   ├── heightCm              double | null
│   ├── weightKg               double | null
│   └── bodyFatPct            double | null
│
├── preferences             -- decisiones de entrenamiento del usuario (no confundir con "settings")
│   ├── goal                  string | null   -- ej. "hypertrophy", "fat_loss" (ver goalOptions)
│   ├── experienceLevel       string | null   -- "beginner" | "intermediate" | "advanced"
│   └── trainingDaysPerWeek   int | null      -- de la rutina activa, si tiene una
│
├── settings                -- configuración de la app, no del entrenamiento
│   ├── language              string          -- ej. "es" (hoy fijo, la app no tiene selector todavía)
│   ├── units                 "metric" | "imperial"  -- hoy fijo en "metric"
│   └── notificationsEnabled  bool | null     -- null hasta que exista un toggle real en Ajustes
│
├── capabilities            -- qué puede hacer ESTA sesión/build, para que el coach no asuma datos que no van a llegar
│   ├── nutrition             bool
│   ├── recovery              bool
│   ├── social                bool            -- false si `SupabaseClient` no está disponible (ver main.dart)
│   └── coach                 bool            -- siempre true si este payload se está armando
│
├── goals                   array de:
│   ├── title                 string
│   ├── metric                string          -- "body_weight_kg" | "body_fat_pct" | "exercise_max_weight" | "exercise_max_reps"
│   ├── progressPct           double
│   ├── achieved              bool
│   └── targetDate            string (ISO 8601) | null
│
├── recovery                objeto | null   -- null si el usuario nunca hizo un check-in
│   ├── recoveryIndex          int (0-100)
│   ├── level                  "recovered" | "medium" | "high_fatigue_risk"
│   ├── sleepHours             double
│   ├── perceivedFatigue       int (0-10)
│   └── checkinDate            string (ISO 8601)
│
├── stats
│   ├── weeklyVolumeKg           double
│   ├── currentStreakDays        int
│   ├── longestStreakDays        int
│   └── maxStrengthByExercise    array de { exerciseName: string, maxWeightKg: double }
│
├── recentWorkouts          array (RESUMIDO y ACOTADO -- ver regla de ventana más abajo)
│   ├── date                   string (ISO 8601, solo fecha)
│   ├── totalVolumeKg          double
│   └── exerciseSummaries     array de string  -- ej. "Sentadilla 100kg x 5 reps" (top set por ejercicio, no cada serie)
│
├── personalRecords         array de:
│   ├── exerciseName           string
│   ├── recordType             "max_weight" | "max_reps"
│   ├── value                   double
│   └── achievedAt             string (ISO 8601)
│
├── achievements
│   ├── level                   int
│   ├── levelBand               "novice" | "intermediate" | "advanced" | "elite"
│   ├── totalXp                  double
│   └── unlocked                array de string  -- solo códigos ya desbloqueados (ej. "first_workout", "30_day_streak")
│
└── extensions              {}              -- reservado, vacío en v1. Espacio para campos futuros sin bump de versión si son opcionales.
```

## Ejemplo concreto

```json
{
  "version": 1,
  "sessionId": "b3f1c2b0-6e9d-4b3a-9e2e-1a2b3c4d5e6f",
  "generatedAt": "2026-07-12T18:42:00-04:00",
  "app": {
    "version": "2.3.1",
    "platform": "android",
    "timezone": "-04:00"
  },
  "profile": {
    "name": "Angel",
    "age": 28,
    "sex": "male",
    "heightCm": 175,
    "weightKg": 78.5,
    "bodyFatPct": 18
  },
  "preferences": {
    "goal": "hypertrophy",
    "experienceLevel": "intermediate",
    "trainingDaysPerWeek": 4
  },
  "settings": {
    "language": "es",
    "units": "metric",
    "notificationsEnabled": null
  },
  "capabilities": {
    "nutrition": true,
    "recovery": true,
    "social": true,
    "coach": true
  },
  "goals": [
    { "title": "Bajar a 75kg", "metric": "body_weight_kg", "progressPct": 40, "achieved": false, "targetDate": "2026-09-01" }
  ],
  "recovery": {
    "recoveryIndex": 72,
    "level": "medium",
    "sleepHours": 6.5,
    "perceivedFatigue": 4,
    "checkinDate": "2026-07-12"
  },
  "stats": {
    "weeklyVolumeKg": 4200,
    "currentStreakDays": 3,
    "longestStreakDays": 12,
    "maxStrengthByExercise": [
      { "exerciseName": "Sentadilla", "maxWeightKg": 100 },
      { "exerciseName": "Press banca", "maxWeightKg": 80 }
    ]
  },
  "recentWorkouts": [
    { "date": "2026-07-12", "totalVolumeKg": 1400, "exerciseSummaries": ["Sentadilla 100kg x 5 reps", "Peso muerto 120kg x 3 reps"] },
    { "date": "2026-07-10", "totalVolumeKg": 1100, "exerciseSummaries": ["Press banca 80kg x 5 reps"] }
  ],
  "personalRecords": [
    { "exerciseName": "Sentadilla", "recordType": "max_weight", "value": 100, "achievedAt": "2026-07-01" }
  ],
  "achievements": {
    "level": 4,
    "levelBand": "intermediate",
    "totalXp": 850,
    "unlocked": ["first_workout", "first_pr"]
  },
  "extensions": {}
}
```

## `capabilities`: por qué existe

El backend no debe asumir que todos los campos van a estar siempre poblados de la misma
forma en el futuro — por ejemplo, `social` depende de que `SupabaseClient` esté
disponible (`main.dart`: `_socialRepository = supabase != null ? SocialRepository(supabase)
: null`). `capabilities` le dice al modelo qué dominios están activos en esta sesión para
que no invente datos de un dominio deshabilitado ni sugiera acciones que la app no puede
ejecutar hoy (ej. no recomendar "revisá el chat de tu reto" si `social: false`). Hoy los
4 valores son casi siempre `true` salvo `social` en el caso sin Supabase — el campo existe
para que agregar un quinto dominio (o desactivar uno temporalmente) sea un cambio de
datos, no de contrato.

## Regla de ventana de `recentWorkouts` (reemplaza al tool-calling)

La versión anterior del backend permitía que el LLM pidiera, vía tool-calling, el detalle
de un rango de fechas arbitrario contra la base de datos. Esa capacidad se elimina (ver
`docs/FASE_4_DISENO.md` sección 2) — en su lugar, `recentWorkouts` manda una ventana fija
por una regla configurable, no un número fijo hardcodeado:

> **Máximo 10 sesiones o 14 días de antigüedad, lo que ocurra primero.**

Algoritmo: recorrer las sesiones del usuario de la más reciente a la más vieja,
acumulando hasta 10; si al llegar a una sesión ya pasaron más de 14 días desde hoy, se
corta ahí aunque no se hayan juntado 10 todavía. El límite es un parámetro de
`CoachContextBuilder` (constantes `maxRecentSessions = 10`, `maxRecentDays = 14`), no un
valor mágico repetido en el código — cambiarlo es una sola línea, sin tocar el contrato.

Si el usuario pregunta por algo fuera de esa ventana, el `SYSTEM_PROMPT` le indica al
modelo que debe decir explícitamente que no tiene ese dato — no inventarlo — en vez de
intentar pedirlo.

## Contexto resumido, no volcado completo

`CoachContextBuilder` **resume**, no vuelca: por cada sesión de `recentWorkouts`, el
`exerciseSummaries` condensa todas las series de un mismo ejercicio en una sola línea
(ej. el mejor set: `"Sentadilla 100kg x 5 reps"`), no una entrada por serie individual.
Con sesiones de 15-30 series esto evita mandar cientos de líneas cuando 3-6 resúmenes por
sesión ya representan el entrenamiento. Mismo criterio para `personalRecords`: solo el
récord vigente por ejercicio/tipo, no el historial de progresión completo (para eso ya
existe `StatsRepository.exerciseProgress` en la pantalla de Estadísticas, no hace falta
duplicarlo acá).

## Presupuesto de tokens / tamaño

**Límite objetivo: 15 KB de JSON, o aproximadamente 4 000 tokens**, lo que sea más
restrictivo. Con la ventana de 10 sesiones/14 días y el resumen descrito arriba, un
usuario típico genera un `CoachContext` muy por debajo de ese límite. Si un usuario con
muchísimo volumen de entrenamiento se acercara al límite, el orden de recorte de
`CoachContextBuilder` (del menos al más importante para responder) es:
1. Reducir `recentWorkouts` de 10 a 5 sesiones.
2. Recortar `exerciseSummaries` a máximo 3 líneas por sesión (las de mayor volumen).
3. Recortar `personalRecords` a los 5 ejercicios con récord más reciente.

Este orden es una guía de diseño para la implementación, no un mecanismo que exista hoy —
se implementa junto con `CoachContextBuilder` en la Fase 4.

## Qué NO incluye este contrato (a propósito)

- **Ningún dato sensible más allá de lo necesario para entrenar**: no viaja email,
  contraseña, ni ningún identificador que no sea el `sessionId` (que no identifica al
  usuario, solo la conversación) — el `userId` real ya lo tiene el backend del JWT
  verificado, no hace falta mandarlo de nuevo en el body.
- **Ningún historial ilimitado**: `recentWorkouts` está acotado (ver regla de ventana);
  `personalRecords` manda solo los récords vigentes por ejercicio.
- **Nada de retos/social**: fuera del alcance del Coach IA — `capabilities.social` solo
  informa si el dominio está activo, no manda datos de retos.

## Versionado del contrato

- `version: 1` viaja en cada request desde el día uno de la implementación.
- Mientras un campo nuevo sea **opcional** y no cambie el significado de uno existente,
  se puede agregar dentro de `extensions` sin subir la versión.
- Un cambio que rompa compatibilidad (renombrar/quitar un campo, cambiar un tipo) exige
  subir a `version: 2` y que el backend siga aceptando `version: 1` durante una
  transición, o rechazarlo explícitamente con un mensaje claro — a decidir en el momento
  según cuántos clientes viejos sigan circulando.
- Cualquier cambio de forma debe:
  1. Actualizarse acá primero.
  2. Reflejarse en `CoachContextBuilder` (cliente) y en el modelo de request del backend
     en el mismo cambio — nunca desincronizados.
  3. Documentarse en `docs/ARQUITECTURA_BACKEND.md` como parte del changelog de la Fase 4.

## Próximo paso

Contrato aprobado y congelado como v1. El siguiente paso es implementar la Fase 4
completa (`docs/FASE_4_DISENO.md`) cuando el usuario dé la orden explícita — empezando
por `CoachContextBuilder` en el cliente (testeable sin red, mismo patrón que
`GoalRepositoryTest`/`RecoveryRepositoryTest`).
