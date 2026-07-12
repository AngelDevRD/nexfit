# ADR-001 — Migrar Auth de FastAPI/JWT propio a Supabase Auth

**Estado**: Aceptada e implementada (Fase 1, 2026-07-11).

## Contexto

El backend FastAPI original emitía sus propios JWT (HS256, `secret_key` del servidor) y
validaba credenciales contra una tabla `users` propia. Esto significaba mantener a mano
hashing de contraseñas, rotación de tokens, recuperación de contraseña y todo el
almacenamiento de sesión — sin ganar nada a cambio, porque el proyecto Supabase de la app
ya existía y se usaba únicamente como Postgres gestionado detrás de SQLAlchemy: Auth y el
cliente PostgREST estaban pagados y corriendo, pero sin usarse.

## Decisión

Reemplazar el JWT propio por Supabase Auth (`SupabaseAuthRepository`), y dejar
`UnavailableAuthRepository` como fallback cuando Supabase no está configurado en el build.

## Consecuencias

- Se elimina toda la superficie de seguridad de manejar contraseñas/tokens a mano
  (hashing, expiración, recuperación) — la resuelve Supabase.
- El resto de los dominios de datos (rutinas, entrenamientos, objetivos, etc.) heredan RLS
  por `auth.uid()` en vez de `WHERE user_id = ...` escrito a mano en cada endpoint.
- `lib/services/auth_service.dart` y `lib/core/api_client.dart` quedaron sin ningún
  importador real desde este momento — confirmado por grep en cada fase posterior hasta su
  eliminación en la Fase 5, Bloque 2 (ver ADR-004).
