# AppGym API — Backend

API REST para la app de entrenamiento. Fases 1-4 implementadas: auth, biblioteca de ejercicios,
rutinas, registro de entrenamientos con detección automática de récords, historial, estadísticas,
calculadoras, estándares de fuerza, predicción de récords, nutrición, recuperación, objetivos,
calendario inteligente, chat con IA ("Gemelo Digital") y sistema de niveles/logros.

## Stack

- FastAPI + Pydantic v2
- SQLAlchemy 2.0 + Alembic (migraciones)
- PostgreSQL 16
- JWT (python-jose) + bcrypt (passlib)

## Setup local (con Docker)

```bash
cp backend/.env.example backend/.env   # ya existe backend/.env para desarrollo local
docker compose up --build
```

API disponible en `http://localhost:8000`, docs interactivas en `http://localhost:8000/docs`.

## Setup local (sin Docker)

```bash
cd backend
python -m venv .venv
.venv\Scripts\pip install -r requirements.txt   # Windows
# source .venv/bin/activate && pip install -r requirements.txt   # Linux/Mac

# requiere Postgres corriendo y DATABASE_URL en .env apuntando a localhost
alembic revision --autogenerate -m "init"
alembic upgrade head
python -m app.seed.run_seed   # carga biblioteca de ejercicios inicial
uvicorn app.main:app --reload
```

## Tests

```bash
cd backend
.venv\Scripts\python -m pytest -q
```

Los tests corren contra SQLite en memoria (no requieren Postgres ni Docker).

## Variables de entorno

Ver `.env.example`:

| Variable | Descripción |
|---|---|
| `DATABASE_URL` | Conexión a PostgreSQL |
| `SECRET_KEY` | Clave para firmar JWT — generar una real en producción |
| `ACCESS_TOKEN_EXPIRE_MINUTES` | Expiración del token (default 7 días) |
| `CORS_ORIGINS` | Orígenes permitidos, separados por coma |

## Estructura

```
app/
  core/       -- config, DB session, seguridad/JWT
  models/     -- entidades SQLAlchemy (User, Exercise, Routine, WorkoutSession, WorkoutSet,
                 PersonalRecord, NutritionLog, DailyCheckIn, Goal)
  schemas/    -- Pydantic request/response
  routes/v1/  -- endpoints (auth, users, exercises, routines, workouts, stats, calculators,
                 nutrition, recovery, goals, calendar, coach, gamification, health)
  services/   -- lógica de negocio (récords, stats, calculadoras, estándares de fuerza,
                 predicciones, recuperación, objetivos, calendario, Gemelo Digital, gamificación)
  data/       -- tablas de referencia estáticas (estándares de fuerza)
  seed/       -- datos iniciales de ejercicios
tests/        -- pytest (61+ tests cubriendo todos los módulos de arriba)
alembic/      -- migraciones
```

## Endpoints principales

- `POST /api/v1/auth/register` / `POST /api/v1/auth/login` / `GET /api/v1/auth/me`
- `PATCH /api/v1/users/me` — completar perfil (edad, sexo, altura, peso, objetivo, experiencia)
- `GET /api/v1/exercises` (filtros `muscle_group`, `equipment`) / `GET /api/v1/exercises/{id}`
- `POST /api/v1/routines` / `GET /api/v1/routines` / `GET /api/v1/routines/{id}` / `DELETE /api/v1/routines/{id}`
- `POST /api/v1/workouts` (inicia sesión) / `PATCH /api/v1/workouts/{id}` (cierra sesión)
- `POST /api/v1/workouts/{id}/sets` — registra serie (peso, reps, RPE, RIR, técnicas avanzadas) → dispara detección de récords
- `PATCH /api/v1/workouts/sets/{set_id}` / `DELETE /api/v1/workouts/sets/{set_id}` — editar/borrar serie individual
- `GET /api/v1/workouts` (filtros `exercise_id`, `muscle_group`, `routine_id`, `date_from`, `date_to`) — historial
- `GET /api/v1/workouts/{id}/records` — récords logrados en esa sesión
- `GET /api/v1/stats/muscle-analysis` (filtro `days`, default 30) — volumen/sets por grupo muscular con nivel relativo (`alto`/`medio`/`bajo`/`muy_bajo`) respecto al propio historial del usuario
- `GET /api/v1/stats/strength-profile` — fuerza máxima por ejercicio, volumen semanal total, frecuencia semanal por grupo muscular
- `GET /api/v1/stats/progress/{exercise_id}` — serie temporal (una entrada por sesión) de peso máximo y volumen, para graficar progreso
- `GET /api/v1/stats/tonnage` (filtros `period=week|month`, `periods`, default 12 semanas) — tonelaje histórico por período
- `GET /api/v1/stats/streak` — racha actual y récord de días consecutivos entrenando
- `POST /api/v1/calculators/{one-rep-max,bmi,lean-body-mass,ideal-weight,nutrition,water-intake,fat-loss-rate}` — calculadoras stateless, no requieren autenticación
- `GET /api/v1/stats/strength-standards/{exercise_id}` — percentil aproximado vs. estándares de fuerza (press banca/sentadilla/peso muerto), requiere perfil completo (peso, sexo)
- `GET /api/v1/stats/record-prediction/{exercise_id}` (filtro `weeks_ahead`, default 8) — proyección lineal del próximo récord, requiere ≥3 PRs históricos
- `PUT /api/v1/nutrition/logs` (upsert por fecha) / `GET /api/v1/nutrition/logs` / `GET|DELETE /api/v1/nutrition/logs/{fecha}` — registro diario de calorías/macros/agua
- `PUT /api/v1/recovery/checkins` (sueño + fatiga percibida) / `GET /api/v1/recovery/index` — índice de recuperación 🟢/🟡/🔴 autorreportado (sin wearables)
- `POST /api/v1/goals` / `GET /api/v1/goals` / `DELETE /api/v1/goals/{id}` — objetivos con progreso calculado automáticamente
- `GET /api/v1/calendar/overview` — objetivos próximos, recomendación de semana de descarga, predicciones de récords próximos
- `POST /api/v1/coach/chat` — chat con el "Gemelo Digital" (arma contexto real del usuario y llama a un LLM); responde 503 si no hay `LLM_API_KEY` configurada
- `GET /api/v1/coach/context-preview` — ver el contexto que se le pasaría al LLM, sin necesitar API key
- `GET /api/v1/gamification/profile` — nivel, XP, progreso al siguiente nivel y logros desbloqueados

## Pendiente explícito

- Imágenes/GIFs/animación 3D de ejercicios — el modelo tiene `image_url`/`animation_url` pero no hay pipeline de assets todavía.
- "Potencia" y "resistencia muscular" del perfil de fuerza → no implementados: requieren datos que no existen (velocidad de barra, definición validada de resistencia).
- Estándares de fuerza y percentiles: **valores de referencia aproximados**, no un dataset poblacional real (ver `app/data/strength_standards.py`) — solo cubren press banca/sentadilla/peso muerto.
- Chat con IA: requiere que el operador configure `LLM_API_KEY` (y opcionalmente `LLM_BASE_URL`/`LLM_MODEL`) en `.env` — sin eso el endpoint responde 503 explícitamente, no falla en silencio.
- Wearables (HealthKit/Google Fit/Garmin), funciones sociales/retos, análisis de técnica por video → Fase 5, necesitan credenciales/infra externa que no están disponibles en este entorno.
- Migraciones Alembic no generadas aún (requiere Postgres corriendo — ver comando arriba).
