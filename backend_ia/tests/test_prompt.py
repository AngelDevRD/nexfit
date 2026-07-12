from app.prompt import (
    SYSTEM_PROMPT_VERSION,
    load_system_prompt_template,
    render_system_prompt,
)


def test_version_es_1():
    assert SYSTEM_PROMPT_VERSION == 1


def test_template_tiene_los_placeholders():
    template = load_system_prompt_template()
    assert "{context}" in template
    assert "{message}" in template


def test_template_incluye_las_reglas_de_seguridad_clave():
    template = load_system_prompt_template()
    assert "consejos médicos" in template
    assert "Gemelo Digital" in template


def test_render_interpola_context_con_llaves_json_sin_romperse():
    # El CoachContext es JSON -- tiene sus propias llaves {}. render_system_prompt
    # no debe usar str.format (rompería con las llaves del JSON de contexto).
    context_json = '{"profile": {"name": "Angel"}, "goals": []}'
    rendered = render_system_prompt(context_json, "¿cómo voy?")

    assert context_json in rendered
    assert "¿cómo voy?" in rendered
    assert "{context}" not in rendered
    assert "{message}" not in rendered
