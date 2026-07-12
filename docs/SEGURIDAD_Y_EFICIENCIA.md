# AppGym — Checklist de seguridad y eficiencia (hacia producción)

Estado a 2026-07-04. Prioridad: 🔴 crítico · 🟡 recomendado · 🟢 opcional/mejora.
Lo que ya está hecho se marca con ✅.

---

## 🔴 Crítico (hacer antes de exponer a usuarios reales)

- [ ] **Rotar la contraseña de Supabase.** Se pegó en el chat durante el setup → quedó
  expuesta. Supabase → Settings → Database → Reset database password. Actualizar el
  `DATABASE_URL` del deploy después.
- [ ] **Rotar la API key de Groq (`LLM_API_KEY`).** También se pegó en el chat. Generar
  una nueva en console.groq.com y reemplazar en `legacy/backend_fastapi/.env` (ya gitignored).
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
  placeholder si `ENV=production` (`legacy/backend_fastapi/app/core/config.py`), pero hay que setear una
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

## Auditoría de rendimiento (Fase 3, 2026-07-12)

Solicitada por el usuario al cerrar la Fase 3, antes de la Fase 4. Es un informe de
diagnóstico — **nada de esto se optimizó todavía**, son oportunidades detectadas.

### Llamadas de red innecesarias
- **Ninguna en los dominios migrados.** `StatsRepository`, `GamificationRepository`,
  `ExerciseRepository` y `lib/core/calculators.dart` no hacen ninguna llamada de red — se
  verificó por grep en la Fase 3c que no importan `ApiClient` ni `SupabaseClient`.
- **Las únicas llamadas de red que sí sobran hoy** son las 3 pantallas rotas descritas en
  `ARQUITECTURA_BACKEND.md` sección 7.1 (calendario, coach, exportar/importar) — no porque
  sean ineficientes, sino porque fallan con 401 en cada intento.

### Consultas repetidas / duplicadas
- **`DashboardScreen._load()` consulta `workoutSessions` dos veces en la misma carga**:
  una vez directo vía `_statsRepository.streak()`, y otra indirectamente porque
  `_gamificationRepository.profile()` internamente vuelve a llamar
  `StatsRepository(db).streak()` (`lib/repositories/gamification_repository.dart`, para
  reusar `longestStreakDays` en el cálculo de XP). Ambas llamadas corren en paralelo dentro
  del mismo `Future.wait`, así que no afecta la latencia percibida, pero sí duplica el
  trabajo de la base local. Oportunidad: que `DashboardScreen` reciba el `streak` ya
  calculado por `GamificationRepository.profile()` en vez de pedirlo aparte, o que
  `StatsRepository`/`GamificationRepository` compartan un resultado memoizado por request.
- **Cada pestaña de `StatsHubScreen`** (`MuscleAnalysisTab`, `StrengthProfileTab`,
  `ProgressTab`, `TonnageTab`, `StrengthStandardsTab`) vuelve a leer `workoutSessions`/
  `workoutSets`/`exercises` completas de forma independiente al construirse o al hacer
  pull-to-refresh, aunque varias piden datos solapados (p. ej. `muscleAnalysis()` y
  `strengthProfile()` ambas recorren todos los `workoutSets` no-calentamiento). No hay
  ningún caché compartido entre pestañas dentro de la misma sesión de pantalla.

### Sincronizaciones duplicadas
- **No se encontró ninguna.** `SyncEngine.syncNow()` tiene un lock simple (`_syncing`) que
  descarta llamadas concurrentes, y se dispara desde 3 fuentes (listener de conectividad,
  timer de respaldo cada 3h, arranque de la app) sin solaparse nunca gracias a ese lock.
- **Sí hay una oportunidad de paralelismo, no un bug**: `SyncEngine.syncNow()` recorre las
  6 `SyncableEntity` (`Profile`, `Routine`, `WorkoutSession`, `Goal`, `Nutrition`,
  `Recovery`) secuencialmente. El orden `Routine → WorkoutSession` importa (una sesión
  necesita el `serverId` de su rutina), pero `Goal`/`Nutrition`/`Recovery`/`Profile` son
  independientes entre sí y hoy corren una atrás de la otra en vez de en paralelo.
- **`WorkoutSessionSyncable._drainPendingOps`** manda un request HTTP por cada operación
  pendiente (`insert`/`update`/`delete` de un set), secuencialmente, en vez de agrupar
  varias operaciones de la misma sesión en un solo round-trip. A los volúmenes típicos de
  una sesión (10-30 sets) no es un problema real, pero es una oportunidad si en el futuro
  se permiten sesiones con muchas más series.

### Cálculos que podrían optimizarse
- **Ningún resultado de `StatsRepository`/`GamificationRepository` se cachea.** Cada
  llamada (`muscleAnalysis`, `strengthProfile`, `tonnage`, `streak`, `profile` de
  gamificación) vuelve a traer las tablas completas (`workoutSessions`, `workoutSets`,
  `exercises`, `personalRecords`) a memoria y las recorre con Dart puro — no hay
  agregación en SQL (`SUM`/`GROUP BY` vía Drift) ni ningún acumulador incremental
  mantenido al agregar un set. Con el volumen de datos típico de un usuario (meses de
  entrenamiento) esto es imperceptible; con años de historial podría empezar a notarse en
  dispositivos de gama baja. Oportunidad futura: mover las agregaciones a consultas SQL
  (Drift soporta `sum`/`count`/`groupBy`) o mantener contadores incrementales al escribir
  cada set, igual que ya se hace con `PersonalRecords`.
- **`ExerciseRepository.get(id)`** decodifica el `detailJson` completo (instrucciones,
  tips, variantes, etc.) en cada apertura de `ExerciseDetailScreen` — correcto y ya barato
  (un solo row), sin necesidad de cambios.

### Batería / memoria
- **`SyncEngine`**: un solo listener de conectividad de por vida de la app + un
  `Timer.periodic` de 3 horas — huella mínima, no se encontró ninguna fuga ni polling
  agresivo.
- **`HealthService`** (wearables): solo lee bajo pedido explícito del usuario (no hay
  polling en background) — sin impacto de batería fuera de la sesión activa de esa
  pantalla.
- **Costo operativo, no de código**: el backend FastAPI sigue desplegado (hosting activo)
  pese a que, según la sección 7.1 de `ARQUITECTURA_BACKEND.md`, ningún flujo real de la
  app lo alcanza hoy salvo 3 pantallas rotas. No es una oportunidad de "optimizar código"
  sino de decidir en la Fase 4/5 si se apaga, se reduce a solo lo que sostiene Coach IA, o
  se reemplaza por una Supabase Edge Function.

---

## Verificado en este proyecto (para no re-hacer)
- ✅ Inputs validados con Pydantic; ORM SQLAlchemy (sin SQL crudo → sin inyección).
- ✅ Passwords con bcrypt (passlib). ✅ Auth JWT. ✅ Secretos en `.env` gitignored.
- ✅ 71/71 tests backend, flutter analyze/test en verde, APK release compila y firma OK.
- ✅ Migraciones Alembic aplicadas y verificadas contra Postgres real.
