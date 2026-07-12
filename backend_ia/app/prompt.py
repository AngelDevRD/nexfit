"""Carga el system prompt como recurso versionado -- docs/COACH_SYSTEM_PROMPT.md.
El contenido vive en prompts/coach_system_v1.txt, no incrustado como string
literal en el codigo: este modulo solo lo lee e interpola `{context}`/
`{message}`, nunca redefine el texto.
"""

from pathlib import Path

SYSTEM_PROMPT_VERSION = 1

_PROMPT_PATH = (
    Path(__file__).resolve().parent.parent / "prompts" / "coach_system_v1.txt"
)


def load_system_prompt_template() -> str:
    return _PROMPT_PATH.read_text(encoding="utf-8")


def render_system_prompt(context_json: str, message: str) -> str:
    """Interpola el CoachContext (ya serializado a JSON) y la pregunta del
    usuario dentro del template cargado desde el recurso versionado."""
    template = load_system_prompt_template()
    return template.replace("{context}", context_json).replace("{message}", message)
