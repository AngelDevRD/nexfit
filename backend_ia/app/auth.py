"""Validacion del JWT de Supabase -- docs/FASE_4_DISENO.md seccion 4.

Variante "simple" elegida para la v1: se llama a
GET {SUPABASE_URL}/auth/v1/user con el token tal cual. Supabase responde con
el usuario si es valido, error si no -- cero secretos propios que guardar en
este backend, solo la URL publica del proyecto (la misma que ya usa el
cliente).
"""

import httpx
from fastapi import Depends
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from app.config import Settings, get_settings
from app.errors import UnauthorizedError

_bearer_scheme = HTTPBearer(auto_error=False)


async def verify_supabase_jwt(
    token: str, supabase_url: str, timeout_seconds: float = 10.0
) -> str:
    """Devuelve el uuid del usuario (Supabase auth.users.id) si el JWT es
    valido. Levanta UnauthorizedError en cualquier otro caso -- token vacio,
    invalido/expirado, o si no se pudo hablar con Supabase."""
    if not token:
        raise UnauthorizedError("Falta el token de autenticacion")
    if not supabase_url:
        raise UnauthorizedError("El backend no tiene configurado SUPABASE_URL")

    async with httpx.AsyncClient(timeout=timeout_seconds) as client:
        try:
            response = await client.get(
                f"{supabase_url.rstrip('/')}/auth/v1/user",
                headers={"Authorization": f"Bearer {token}"},
            )
        except httpx.HTTPError as exc:
            raise UnauthorizedError(
                f"No se pudo validar el token contra Supabase: {exc}"
            ) from exc

    if response.status_code != 200:
        raise UnauthorizedError("Token invalido o expirado")

    data = response.json()
    user_id = data.get("id")
    if not user_id:
        raise UnauthorizedError("Supabase no devolvio un id de usuario valido")
    return user_id


async def get_current_user_id(
    credentials: HTTPAuthorizationCredentials | None = Depends(_bearer_scheme),
    settings: Settings = Depends(get_settings),
) -> str:
    """Dependency de FastAPI -- usarla en cada endpoint que requiera sesion."""
    if credentials is None or not credentials.credentials:
        raise UnauthorizedError("Falta el header Authorization: Bearer <token>")
    return await verify_supabase_jwt(credentials.credentials, settings.supabase_url)
