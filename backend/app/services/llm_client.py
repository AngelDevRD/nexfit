import httpx

from app.core.config import get_settings


class LlmNotConfiguredError(Exception):
    pass


async def ask_llm(system_prompt: str, user_message: str) -> str:
    settings = get_settings()
    if not settings.llm_api_key:
        raise LlmNotConfiguredError(
            "Falta configurar LLM_API_KEY en el backend para habilitar el chat con el entrenador IA"
        )

    async with httpx.AsyncClient(timeout=30.0) as client:
        response = await client.post(
            f"{settings.llm_base_url}/chat/completions",
            headers={"Authorization": f"Bearer {settings.llm_api_key}"},
            json={
                "model": settings.llm_model,
                "messages": [
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": user_message},
                ],
            },
        )
        response.raise_for_status()
        data = response.json()
        return data["choices"][0]["message"]["content"]
