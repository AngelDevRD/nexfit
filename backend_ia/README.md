# NexFit — Backend inteligente (Coach IA)

Backend standalone, **100% stateless**, para el Coach IA de NexFit. Implementa el
diseño de `../docs/FASE_4_DISENO.md` y los contratos congelados en
`../docs/COACH_CONTEXT.md`, `../docs/COACH_API.md` y `../docs/COACH_SYSTEM_PROMPT.md`.

No tiene base de datos propia, ni Alembic, ni SQLAlchemy, ni tool-calling contra ninguna
base — el cliente Flutter arma todo el contexto (`CoachContext`) y lo manda en cada
request. Este servicio solo valida el JWT de Supabase, aplica rate limiting, arma el
prompt y llama al proveedor de LLM configurado.

## Estructura

```
app/
  main.py            FastAPI app + manejo uniforme de errores
  config.py          Settings (variables de entorno, sin DB)
  auth.py            Validación del JWT de Supabase (GET /auth/v1/user)
  rate_limiter.py     Rate limiter en memoria de proceso, por usuario
  prompt.py           Carga prompts/coach_system_v1.txt como recurso versionado
  schemas.py          Modelos Pydantic de request/response
  errors.py           Excepciones -> códigos de docs/COACH_API.md
  llm/
    base.py           Interfaz LLMProvider (nunca importar un SDK fuera de acá)
    groq_provider.py  Única implementación que conoce la API de Groq
    factory.py        Selecciona el proveedor activo por LLM_PROVIDER
  routes/
    coach.py           POST /api/v1/coach/chat, GET /api/v1/coach/status
prompts/
  coach_system_v1.txt  Texto del system prompt (docs/COACH_SYSTEM_PROMPT.md)
tests/                 pytest — un archivo de test por componente
```

## Desarrollo local

```bash
python -m venv .venv
.venv/Scripts/activate  # o source .venv/bin/activate en Linux/Mac
pip install -r requirements.txt
cp .env.example .env  # completar SUPABASE_URL y LLM_API_KEY
uvicorn app.main:app --reload
```

## Tests y análisis estático

```bash
pytest -q
ruff check .
```

## Agregar un proveedor de LLM nuevo

1. Implementar `LLMProvider` en `app/llm/<nombre>_provider.py` (ver `groq_provider.py`
   como referencia — sin tool-calling, sin SDKs ajenos a esa clase).
2. Registrar la nueva opción en `app/llm/factory.py`.
3. Setear `LLM_PROVIDER=<nombre>` en el entorno.

Ningún endpoint ni el resto del backend cambia.
