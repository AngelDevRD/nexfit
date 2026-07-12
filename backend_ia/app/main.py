from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from app.config import get_settings
from app.errors import CoachApiError
from app.routes.coach import router as coach_router

app = FastAPI(title="NexFit Coach IA", version="1.0.0")
app.include_router(coach_router)

settings = get_settings()
if settings.cors_origins_list:
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_origins_list,
        allow_methods=["GET", "POST"],
        allow_headers=["Authorization", "Content-Type"],
    )


@app.exception_handler(CoachApiError)
def coach_api_error_handler(_request: Request, exc: CoachApiError) -> JSONResponse:
    headers = {}
    if hasattr(exc, "retry_after_seconds"):
        headers["Retry-After"] = str(exc.retry_after_seconds)
    return JSONResponse(
        status_code=exc.http_status,
        content={"error": {"code": exc.code, "message": exc.message}},
        headers=headers,
    )
