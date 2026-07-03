# AppGym API — Backend

API REST para la app de entrenamiento (Fase 1): auth, biblioteca de ejercicios, rutinas, registro de entrenamientos e historial con detección automática de récords personales.

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
  models/     -- entidades SQLAlchemy (User, Exercise, Routine, WorkoutSession, WorkoutSet, PersonalRecord)
  schemas/    -- Pydantic request/response
  routes/v1/  -- endpoints (auth, users, exercises, routines, workouts, stats, calculators, health)
  services/   -- lógica de negocio (detección de récords, stats, calculadoras)
  seed/       -- datos iniciales de ejercicios
tests/        -- pytest (auth, exercises, routines, workouts, stats, calculators)
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

## Pendiente explícito (fuera de Fase 1-2 actual)

- Imágenes/GIFs/animación 3D de ejercicios — el modelo tiene `image_url`/`animation_url` pero no hay pipeline de assets todavía.
- Comparación histórica y con percentiles poblacionales → Fase 3.
- "Potencia" y "resistencia muscular" del perfil de fuerza → no implementados: requieren datos que no existen (velocidad de barra, definición validada de resistencia). `strength-profile` solo cubre fuerza máxima, volumen semanal y frecuencia por músculo.
- Fatiga/recuperación (necesita sueño/HR), calendario inteligente, módulo de nutrición (registro diario), IA conversacional/Gemelo Digital, predicción de récords, wearables, niveles/gamificación → Fases 3-5, ver `.ai/CONTEXT.md`.
- Generación de rutinas por IA y entrenador inteligente → Fase 4.
- Migraciones Alembic no generadas aún (requiere Postgres corriendo — ver comando arriba).
