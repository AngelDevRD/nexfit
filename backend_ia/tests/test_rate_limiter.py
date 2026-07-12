import pytest

from app.rate_limiter import InMemoryRateLimiter, RateLimitExceeded


def test_permite_hasta_el_limite():
    limiter = InMemoryRateLimiter(max_requests_per_window=3, window_seconds=60)
    for _ in range(3):
        limiter.check_and_record("user-1")  # no debe levantar


def test_bloquea_al_superar_el_limite():
    limiter = InMemoryRateLimiter(max_requests_per_window=2, window_seconds=60)
    limiter.check_and_record("user-1")
    limiter.check_and_record("user-1")
    with pytest.raises(RateLimitExceeded):
        limiter.check_and_record("user-1")


def test_usuarios_distintos_no_se_pisan():
    limiter = InMemoryRateLimiter(max_requests_per_window=1, window_seconds=60)
    limiter.check_and_record("user-1")
    limiter.check_and_record("user-2")  # distinto usuario, no debe levantar


def test_limite_cero_bloquea_desde_el_primer_intento_sin_reventar():
    # Caso limite: max_requests_per_window=0 -- no hay ningun hit previo del
    # que calcular el retry-after, no debe levantar IndexError.
    limiter = InMemoryRateLimiter(max_requests_per_window=0, window_seconds=60)
    with pytest.raises(RateLimitExceeded) as exc_info:
        limiter.check_and_record("user-1")
    assert exc_info.value.retry_after_seconds > 0


def test_retry_after_es_positivo():
    limiter = InMemoryRateLimiter(max_requests_per_window=1, window_seconds=60)
    limiter.check_and_record("user-1")
    with pytest.raises(RateLimitExceeded) as exc_info:
        limiter.check_and_record("user-1")
    assert exc_info.value.retry_after_seconds > 0


def test_la_ventana_libera_espacio_con_el_tiempo(monkeypatch):
    limiter = InMemoryRateLimiter(max_requests_per_window=1, window_seconds=1)
    fake_now = [1000.0]
    monkeypatch.setattr("app.rate_limiter.time.monotonic", lambda: fake_now[0])

    limiter.check_and_record("user-1")
    with pytest.raises(RateLimitExceeded):
        limiter.check_and_record("user-1")

    fake_now[0] += 1.5  # pasa la ventana de 1s
    limiter.check_and_record("user-1")  # ya deberia estar libre de nuevo
