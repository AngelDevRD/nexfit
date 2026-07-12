"""Rate limiter en memoria de proceso -- docs/FASE_4_DISENO.md seccion 2/9.

Deliberadamente sin ningun store externo (Redis, etc.) para la v1: el backend
sigue siendo 100% stateless en el sentido de "no persiste datos de usuario".
Si en el futuro se escala a mas de una instancia y el limite compartido
importa, se puede reemplazar el diccionario interno por Redis sin cambiar la
interfaz publica de esta clase.
"""

import time


class InMemoryRateLimiter:
    def __init__(self, max_requests_per_window: int, window_seconds: float = 60.0):
        self._max_requests = max_requests_per_window
        self._window_seconds = window_seconds
        self._hits: dict[str, list[float]] = {}

    def check_and_record(self, key: str) -> None:
        """Levanta ValueError-like `RateLimitExceeded` si `key` ya alcanzo el
        limite en la ventana actual; si no, registra este intento y sigue."""
        now = time.monotonic()
        history = self._hits.setdefault(key, [])

        cutoff = now - self._window_seconds
        while history and history[0] < cutoff:
            history.pop(0)

        if len(history) >= self._max_requests:
            # Si el limite es 0 (o la ventana quedo vacia tras purgar), no hay
            # ningun hit del que calcular el retry-after -- se ofrece la
            # ventana completa.
            oldest = history[0] if history else now
            retry_after = self._window_seconds - (now - oldest)
            raise RateLimitExceeded(retry_after_seconds=max(1, round(retry_after)))

        history.append(now)


class RateLimitExceeded(Exception):
    def __init__(self, retry_after_seconds: int):
        self.retry_after_seconds = retry_after_seconds
        super().__init__(f"Rate limit excedido, reintentar en {retry_after_seconds}s")
