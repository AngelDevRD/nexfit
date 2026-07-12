import httpx
import pytest
import respx

from app.auth import verify_supabase_jwt
from app.errors import UnauthorizedError

SUPABASE_URL = "https://xyzcompany.supabase.co"


@pytest.mark.asyncio
async def test_verify_sin_token_levanta_unauthorized():
    with pytest.raises(UnauthorizedError):
        await verify_supabase_jwt("", SUPABASE_URL)


@pytest.mark.asyncio
async def test_verify_sin_supabase_url_configurada_levanta_unauthorized():
    with pytest.raises(UnauthorizedError):
        await verify_supabase_jwt("un-token", "")


@pytest.mark.asyncio
@respx.mock
async def test_verify_token_valido_devuelve_uuid():
    respx.get(f"{SUPABASE_URL}/auth/v1/user").mock(
        return_value=httpx.Response(
            200, json={"id": "b3f1c2b0-uuid", "email": "a@b.com"}
        )
    )
    user_id = await verify_supabase_jwt("valid-token", SUPABASE_URL)
    assert user_id == "b3f1c2b0-uuid"


@pytest.mark.asyncio
@respx.mock
async def test_verify_token_invalido_levanta_unauthorized():
    respx.get(f"{SUPABASE_URL}/auth/v1/user").mock(
        return_value=httpx.Response(401, json={"msg": "invalid JWT"})
    )
    with pytest.raises(UnauthorizedError):
        await verify_supabase_jwt("expired-token", SUPABASE_URL)


@pytest.mark.asyncio
@respx.mock
async def test_verify_respuesta_sin_id_levanta_unauthorized():
    respx.get(f"{SUPABASE_URL}/auth/v1/user").mock(
        return_value=httpx.Response(200, json={"email": "a@b.com"})
    )
    with pytest.raises(UnauthorizedError):
        await verify_supabase_jwt("weird-token", SUPABASE_URL)


@pytest.mark.asyncio
@respx.mock
async def test_verify_error_de_red_levanta_unauthorized():
    respx.get(f"{SUPABASE_URL}/auth/v1/user").mock(
        side_effect=httpx.ConnectError("no network")
    )
    with pytest.raises(UnauthorizedError):
        await verify_supabase_jwt("un-token", SUPABASE_URL)
