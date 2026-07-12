import json
from typing import Callable

import httpx

from app.core.config import get_settings


class LlmNotConfiguredError(Exception):
    pass


async def ask_llm(
    system_prompt: str,
    user_message: str,
    tools: list[dict] | None = None,
    tool_executor: Callable[[str, dict], str] | None = None,
) -> str:
    settings = get_settings()
    if not settings.llm_api_key:
        raise LlmNotConfiguredError(
            "Falta configurar LLM_API_KEY en el backend para habilitar el chat con el entrenador IA"
        )

    messages = [
        {"role": "system", "content": system_prompt},
        {"role": "user", "content": user_message},
    ]

    async with httpx.AsyncClient(timeout=30.0) as client:
        body: dict = {"model": settings.llm_model, "messages": messages}
        if tools:
            body["tools"] = tools
            body["tool_choice"] = "auto"

        response = await client.post(
            f"{settings.llm_base_url}/chat/completions",
            headers={"Authorization": f"Bearer {settings.llm_api_key}"},
            json=body,
        )
        response.raise_for_status()
        data = response.json()
        message = data["choices"][0]["message"]

        tool_calls = message.get("tool_calls")
        if not tool_calls or not tool_executor:
            return message["content"]

        messages.append(message)
        for tool_call in tool_calls:
            function = tool_call["function"]
            try:
                arguments = json.loads(function.get("arguments") or "{}")
            except json.JSONDecodeError:
                arguments = {}
            result = tool_executor(function["name"], arguments)
            messages.append(
                {
                    "role": "tool",
                    "tool_call_id": tool_call["id"],
                    "content": result,
                }
            )

        follow_up = await client.post(
            f"{settings.llm_base_url}/chat/completions",
            headers={"Authorization": f"Bearer {settings.llm_api_key}"},
            json={"model": settings.llm_model, "messages": messages},
        )
        follow_up.raise_for_status()
        follow_up_data = follow_up.json()
        return follow_up_data["choices"][0]["message"]["content"]
