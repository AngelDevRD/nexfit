from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Configuracion del backend inteligente.

    Deliberadamente no tiene DATABASE_URL/SECRET_KEY propios: ver
    docs/FASE_4_DISENO.md seccion 1 -- este backend es stateless, sin
    persistencia propia.
    """

    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    # Para validar el JWT de Supabase contra GET {supabase_url}/auth/v1/user
    # (docs/FASE_4_DISENO.md seccion 4).
    supabase_url: str = ""

    # LLMProvider activo -- ver docs/FASE_4_DISENO.md seccion 7.
    llm_provider: str = "groq"
    llm_api_key: str | None = None
    llm_base_url: str = "https://api.groq.com/openai/v1"
    llm_model: str = "llama-3.3-70b-versatile"
    llm_timeout_seconds: float = 30.0

    rate_limit_per_minute: int = 10

    cors_origins: str = ""

    @property
    def cors_origins_list(self) -> list[str]:
        return [
            origin.strip() for origin in self.cors_origins.split(",") if origin.strip()
        ]


@lru_cache
def get_settings() -> Settings:
    return Settings()
