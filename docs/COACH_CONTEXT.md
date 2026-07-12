# Contrato `CoachContext` — la "API" entre Flutter y el backend inteligente

Estado: **propuesta de contrato, pendiente de aprobación**. Ningún código de este
documento existe todavía. Es el segundo paso del orden acordado para la Fase 4 (ver
`docs/FASE_4_DISENO.md` sección 10) — se implementa recién después de aprobarse.

## Propósito

`CoachContext` es el único objeto que Flutter le manda al backend inteligente junto con
la pregunta del usuario (`POST /api/v1/coach/chat`, ver `docs/FASE_4_DISENO.md` sección
5). Es el reemplazo completo de `digital_twin.build_user_context` (que hoy arma ese mismo
resumen en Python, consultando una base de datos que ya no recibe datos reales desde la
Fase 2) — acá lo arma el cliente, con datos que ya tiene local u offline-first.

Es un contrato, no una implementación: si en el futuro se agrega una métrica nueva o se
cambia de proveedor de LLM, alcanza con **extender este documento y el builder que lo
arma** — no hace falta rediseñar el backend ni la UI del chat.

## Quién lo arma

`CoachRepository` (ver `docs/FASE_4_DISENO.md` sección 3), combinando exclusivamente
repositorios que ya existen — cero queries nuevas:

| Sección de `CoachContext` | Repositorio/fuente |
|---|---|
| `profile` | `ProfileRepository.get(userId)` |
| `goals` | `GoalRepository.list()` |
| `recovery` | `RecoveryRepository.index()` |
| `stats` | `StatsRepository.strengthProfile()` + `.streak()` |
| `recentWorkouts` | `WorkoutRepository` (sesiones/sets de una ventana acotada de días) |
| `personalRecords` | `StatsRepository`/`PersonalRecords` locales (ya usados por `GoalRepository`) |
| `achievements` | `GamificationRepository.profile()` |
| `preferences` | Config del dispositivo/app (idioma, unidades) |

## Esquema completo

```
CoachContext
├── profile              (objeto, puede venir con campos null si el usuario no completó el perfil)
│   ├── name              string
│   ├── age               int | null
│   ├── sex               "male" | "female" | null
│   ├── heightCm           double | null
│   ├── weightKg            double | null
│   ├── bodyFatPct         double | null
│   ├── goal                string | null   -- ej. "hypertrophy", "fat_loss" (ver goalOptions)
│   └── experienceLevel    string | null   -- "beginner" | "intermediate" | "advanced"
│
├── monthsTraining        int             -- meses desde la primera sesión registrada (0 si no hay ninguna)
│
├── goals                 array de:
│   ├── title              string
│   ├── metric             string          -- "body_weight_kg" | "body_fat_pct" | "exercise_max_weight" | "exercise_max_reps"
│   ├── progressPct        double
│   ├── achieved           bool
│   └── targetDate         string (ISO 8601) | null
│
├── recovery               objeto | null   -- null si el usuario nunca hizo un check-in
│   ├── recoveryIndex       int (0-100)
│   ├── level               "recovered" | "medium" | "high_fatigue_risk"
│   ├── sleepHours          double
│   ├── perceivedFatigue    int (0-10)
│   └── checkinDate         string (ISO 8601)
│
├── stats
│   ├── weeklyVolumeKg          double
│   ├── currentStreakDays       int
│   ├── longestStreakDays       int
│   └── maxStrengthByExercise   array de { exerciseName: string, maxWeightKg: double }
│
├── recentWorkouts        array de (ventana acotada -- ver "Ventana de historial reciente" abajo)
│   ├── date                string (ISO 8601, solo fecha)
│   ├── totalVolumeKg       double
│   └── exerciseSummaries  array de string  -- ej. "Sentadilla 100kg x 5 reps"
│
├── personalRecords       array de:
│   ├── exerciseName        string
│   ├── recordType          "max_weight" | "max_reps"
│   ├── value                double
│   └── achievedAt          string (ISO 8601)
│
├── achievements
│   ├── level                int
│   ├── levelBand            "novice" | "intermediate" | "advanced" | "elite"
│   ├── totalXp               double
│   └── unlocked             array de string  -- solo los códigos ya desbloqueados (ej. "first_workout", "30_day_streak")
│
└── preferences
    ├── language              string  -- ej. "es" (idioma de la UI, hoy fijo en español)
    └── units                 "metric" | "imperial"  -- hoy fijo en "metric", la app no tiene selector todavía
```

## Ejemplo concreto

```json
{
  "profile": {
    "name": "Angel",
    "age": 28,
    "sex": "male",
    "heightCm": 175,
    "weightKg": 78.5,
    "bodyFatPct": 18,
    "goal": "hypertrophy",
    "experienceLevel": "intermediate"
  },
  "monthsTraining": 4,
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
  "preferences": {
    "language": "es",
    "units": "metric"
  }
}
```

## Ventana de historial reciente (reemplazo del tool-calling)

La versión anterior del backend permitía que el LLM pidiera, vía tool-calling, el detalle
de un rango de fechas arbitrario contra la base de datos. Esa capacidad se elimina (ver
`docs/FASE_4_DISENO.md` sección 2) — en su lugar, `recentWorkouts` manda una ventana fija
y acotada por adelantado.

**Ventana propuesta: últimas 2 semanas o últimas 10 sesiones, lo que sea menor.** Es
suficiente para responder la gran mayoría de preguntas del chat ("¿cómo vengo esta
semana?", "¿qué entrené ayer?") sin que el payload crezca sin límite para usuarios con
meses de historial. Si el usuario pregunta por algo fuera de esa ventana, el
`SYSTEM_PROMPT` le indica al modelo que debe decir explícitamente que no tiene ese dato
— no inventarlo — en vez de intentar pedirlo.

## Qué NO incluye este contrato (a propósito)

- **Ningún dato sensible más allá de lo necesario para entrenar**: no viaja email,
  contraseña, ni ningún identificador que no sea el que ya va en el JWT (`sub`). El
  `CoachContext` no necesita el `userId` — el backend ya lo tiene del JWT verificado.
- **Ningún historial ilimitado**: `recentWorkouts` está acotado (ver arriba);
  `personalRecords` manda solo los récords vigentes por ejercicio, no el historial
  completo de progresión (para eso ya existe `StatsRepository.exerciseProgress` en la
  pantalla de Estadísticas, no hace falta duplicarlo acá).
- **Nada de retos/social**: fuera del alcance del Coach IA, no se mezcla con datos de
  otros usuarios.

## Tamaño estimado del payload

Con la ventana de 2 semanas/10 sesiones, un usuario típico genera un `CoachContext` de
pocos KB (equivalente al JSON de ejemplo de arriba, escalado). No se considera necesario
comprimir ni paginar para la v1 — si en el uso real resulta pesado, se puede acotar más la
ventana de `recentWorkouts` sin cambiar el resto del contrato.

## Versionado del contrato

Mientras el backend inteligente no exista todavía, este documento es la única fuente de
verdad y se edita libremente. Una vez implementado el primer `CoachRepository`/backend
real, cualquier cambio de forma (agregar/quitar/renombrar un campo) debe:
1. Actualizarse acá primero.
2. Reflejarse en `CoachRepository` (cliente) y en el modelo de request del backend en el
   mismo cambio — nunca desincronizados.
3. Documentarse en `docs/ARQUITECTURA_BACKEND.md` como parte del changelog de la Fase 4.

## Próximo paso

Revisar y aprobar este contrato con el usuario (paso 3 del orden acordado en
`docs/FASE_4_DISENO.md` sección 10) antes de implementar `CoachRepository` ni el backend.
