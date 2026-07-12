"""Errores del backend inteligente -- codigos y sobre uniforme de
docs/COACH_API.md seccion "Errores". Cada excepcion sabe su status HTTP y su
`error.code`; `routes/coach.py` las traduce a JSONResponse con el mismo sobre
sin importar cual sea.
"""

from fastapi import status


class CoachApiError(Exception):
    http_status: int = status.HTTP_500_INTERNAL_SERVER_ERROR
    code: str = "internal_error"

    def __init__(self, message: str):
        self.message = message
        super().__init__(message)


class InvalidRequestError(CoachApiError):
    http_status = status.HTTP_400_BAD_REQUEST
    code = "invalid_request"


class ContextTooLargeError(CoachApiError):
    http_status = status.HTTP_400_BAD_REQUEST
    code = "context_too_large"


class UnauthorizedError(CoachApiError):
    http_status = status.HTTP_401_UNAUTHORIZED
    code = "unauthorized"


class ForbiddenError(CoachApiError):
    http_status = status.HTTP_403_FORBIDDEN
    code = "forbidden"


class RateLimitedError(CoachApiError):
    http_status = status.HTTP_429_TOO_MANY_REQUESTS
    code = "rate_limited"

    def __init__(self, message: str, retry_after_seconds: int):
        super().__init__(message)
        self.retry_after_seconds = retry_after_seconds


class InternalError(CoachApiError):
    http_status = status.HTTP_500_INTERNAL_SERVER_ERROR
    code = "internal_error"


class LlmUnavailableError(CoachApiError):
    http_status = status.HTTP_503_SERVICE_UNAVAILABLE
    code = "llm_unavailable"


class LlmTimeoutError(CoachApiError):
    http_status = status.HTTP_504_GATEWAY_TIMEOUT
    code = "timeout"
