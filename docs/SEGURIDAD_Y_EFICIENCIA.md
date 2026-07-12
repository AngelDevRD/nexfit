# AppGym — Checklist de seguridad y eficiencia (hacia producción)

Estado a 2026-07-04. Prioridad: 🔴 crítico · 🟡 recomendado · 🟢 opcional/mejora.
Lo que ya está hecho se marca con ✅.

---

## 🔴 Crítico (hacer antes de exponer a usuarios reales)

- [ ] **Rotar la contraseña de Supabase.** Se pegó en el chat durante el setup → quedó
  expuesta. Supabase → Settings → Database → Reset database password. Actualizar el
  `DATABASE_URL` del deploy después.
- [ ] **Rotar la API key de Groq (`LLM_API_KEY`).** También se pegó en el chat. Generar
  una nueva en console.groq.com y reemplazar en `backend/.env` (ya gitignored).
- [x] **Activar RLS en Supabase** — ✅ verificado 2026-07-11 (ya estaba activo en las 13
  tablas de entonces) y reconfirmado 2026-07-12 tras la Fase 2 de
  `ARQUITECTURA_BACKEND.md`: las 11 tablas recreadas con esquema uuid (`profiles`,
  `routines`, `routine_days`, `routine_exercises`, `workout_sessions`, `workout_sets`,
  `personal_records`, `goals`, `nutrition_logs`, `daily_checkins`, `challenges`,
  `challenge_participants`) nacieron con RLS + policies desde la migración, no como paso
  aparte. `get_advisors(security)` post-migración: 0 hallazgos nuevos de RLS. Pendiente
  solo `public.exercises`/`public.users` (tablas propias de FastAPI, RLS activo sin
  policies = deniega todo, no expuestas) y `public.alembic_version` (sin RLS, advisory
  `critical` por exposición vía `anon key` — sigue sin aplicarse, a decisión del usuario).
- [ ] **`SECRET_KEY` real en producción.** El código ya bloquea el arranque con la key
  placeholder si `ENV=production` (`backend/app/core/config.py`), pero hay que setear una
  aleatoria de 64+ chars en el entorno del deploy. ✅ gate ya implementado.
- [ ] **Cambiar el `applicationId`** de `com.example.appgym` a un dominio real
  (`android/app/build.gradle.kts`). `com.example.*` no se puede publicar en Play Store.
- [ ] **Guardar la keystore de release en lugar seguro.** `android/app/appgym-release.jks`
  + `android/key.properties` (contraseña `dkzR0Fuz3AxIHxx3ozmxqjya`). Si la perdés, no
  podés volver a actualizar la app firmada con la misma identidad. Hacé un backup offline.

## 🟡 Recomendado (antes de escalar)

### Backend / API
- [ ] **Rate limiting** en `/auth/login` y `/auth/register` (fuerza bruta). `slowapi` para
  FastAPI, p. ej. 5 intentos/min por IP.
- [ ] **CORS restringido.** Hoy `CORS_ORIGINS` permite `localhost` (dev). En prod, dejar
  solo el dominio real del front/app.
- [ ] **HTTPS/TLS obligatorio** en el deploy (Nginx/Caddy con Let's Encrypt). Quitar
  `usesCleartextTraffic="true"` del `AndroidManifest.xml` cuando el backend sea https.
- [ ] **Refresh tokens + expiración corta del access token.** Hoy el token dura 7 días
  (`ACCESS_TOKEN_EXPIRE_MINUTES=10080`). Access corto (ej. 60 min) + refresh token es más seguro.
- [ ] **Rol de DB dedicado** en vez de `postgres` para el backend (principio de mínimo
  privilegio): un rol `appgym_app` con permisos solo sobre `public`, con `BYPASSRLS` si se
  quiere mantener el patrón actual, o con RLS y políticas propias.
- [ ] **Scan de dependencias.** `pip-audit` (backend) y `flutter pub outdated`/`osv-scanner`
  (Flutter) en CI. Recordar: `bcrypt` fijado a 4.0.1 por compat con passlib.
- [ ] **Sin `print()`/logs de secretos.** Ya es política AG-CORE-006; verificar que ningún
  log imprima tokens ni el `DATABASE_URL`.

### Eficiencia / rendimiento
- [ ] **Paginación** en los endpoints de listado (ejercicios, historial, etc.) para no
  traer todo de una cuando crezcan los datos.
- [ ] **Evitar N+1 queries.** Revisar el leaderboard de retos y el dashboard: usar joins/
  agregados en vez de un query por participante/rutina cuando escale.
- [ ] **Índices de DB** en columnas de filtro frecuente (ya hay FKs indexadas; agregar en
  `workout_sessions.started_at`, `personal_records.exercise_id` si el historial crece).
- [ ] **Pooler de Supabase en modo Transaction (6543)** si el backend corre serverless;
  Session pooler (5432) si es un servidor persistente. ✅ ya usás el pooler IPv4.
- [ ] **Caché** (Redis) para respuestas pesadas y repetidas (estadísticas, estándares de
  fuerza). El stack ya contempla Redis.

### Mobile / APK
- [ ] **Incrementar `versionCode`/`versionName`** antes de cada build (ya es regla global).
- [ ] ✅ **APK arm64-only, 44.9MB, firmado** — libs x86/armv7 sobrantes ya excluidas.
- [ ] **Obfuscación de Dart** en release: `flutter build apk --release --obfuscate
  --split-debug-info=build/symbols` (dificulta ingeniería inversa; guardá los símbolos).
- [ ] ✅ **Sin secretos en el cliente** — la key del LLM vive en el backend, no en el APK.

## 🟢 Opcional / mejoras a futuro

- [ ] **CI/CD** (GitHub Actions): lint + tests + build en cada push; secrets como GitHub
  Secrets, nunca en el repo.
- [ ] **Monitoreo de errores** (Sentry) en backend y app.
- [ ] **Health checks + alertas** (el endpoint `/health` ya existe).
- [ ] **Backups verificados** de la DB (Supabase hace automáticos; probar una restauración).
- [ ] **Certificate pinning** en la app para el backend (defensa contra MITM).
- [ ] **Tests E2E** del flujo de entrenamiento en dispositivo real (los de wearables/cámara
  solo se validan en hardware).

---

## Verificado en este proyecto (para no re-hacer)
- ✅ Inputs validados con Pydantic; ORM SQLAlchemy (sin SQL crudo → sin inyección).
- ✅ Passwords con bcrypt (passlib). ✅ Auth JWT. ✅ Secretos en `.env` gitignored.
- ✅ 71/71 tests backend, flutter analyze/test en verde, APK release compila y firma OK.
- ✅ Migraciones Alembic aplicadas y verificadas contra Postgres real.
