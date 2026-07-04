from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.core.config import get_settings
from app.routes.v1 import (
    auth,
    calculators,
    calendar,
    coach,
    exercises,
    gamification,
    goals,
    health,
    nutrition,
    recovery,
    routines,
    social,
    stats,
    users,
    workouts,
)

settings = get_settings()

app = FastAPI(
    title="AppGym API",
    description="API para registro de entrenamientos, rutinas, historial y récords personales",
    version="0.1.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins_list,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(health.router)
app.include_router(auth.router)
app.include_router(users.router)
app.include_router(exercises.router)
app.include_router(routines.router)
app.include_router(workouts.router)
app.include_router(stats.router)
app.include_router(calculators.router)
app.include_router(nutrition.router)
app.include_router(recovery.router)
app.include_router(goals.router)
app.include_router(calendar.router)
app.include_router(coach.router)
app.include_router(gamification.router)
app.include_router(social.router)
