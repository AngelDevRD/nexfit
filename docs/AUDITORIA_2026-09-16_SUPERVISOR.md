# AUDITORÍA INICIAL — SUPERVISOR (Opus) — 2026-09-16

Rama local `master` @ `381e1ac` · versión `1.1.4+7` · Flutter/Dart (SDK ^3.12.1).
Esta auditoría **no confía** en `docs/AUDITORIA_2026-09-04.md` ni en
`docs/PROMPT_CONTINUACION_3.md`: cada hallazgo heredado se volvió a comprobar contra el
código actual. Lo que no se pudo comprobar está marcado **NO VERIFICADO** con el motivo.

Leyenda de evidencia: **[EJEC]** comprobado ejecutando · **[CÓDIGO]** comprobado leyendo el
código con archivo:línea · **[INFERIDO]** razonamiento sin reproducción (requiere test que lo
demuestre antes de corregir).

---

## 0. EVIDENCIA RECOGIDA

| Comprobación | Resultado real |
|---|---|
| `git pull --ff-only` | **FALLA: rama divergente.** Local 45 commits adelante, `origin/master` 5 adelante (`d44d340`, solo cambios de `.github/workflows/release.yml`). **45 commits sin subir** (RLS, borrado de cuenta, legal, A1–A26). [EJEC] |
| `flutter analyze` | **0 errores, 0 warnings, 11 infos** (3 en `app_updater.dart`, 6 `Radio` deprecado en `import_preview_screen.dart`, 2 estilo). [EJEC] |
| `flutter test --coverage` | **214 pasan, 1 skip, 0 fallan** (1 m 31 s). Drift avisa de múltiples instancias de `AppDatabase` en `data_transfer_roundtrip_test.dart:114`. [EJEC] |
| Cobertura de líneas | **36,2 %** (6.223 / 17.167, incluye `database.g.dart`). Detalle en §9. [EJEC] |
| Supabase — proyecto `appgym` (`btrdczpnuutrvgoprqze`) | **STATUS = INACTIVE (pausado).** No se pudo consultar esquema, filas, migraciones ni advisors. No se reactivó (requiere autorización). [EJEC] |
| Ejecutar la app | **NO VERIFICADO visualmente en vivo.** Sin emulador Android (`flutter emulators` vacío). `flutter run -d windows` falla: `PathExistsException ... windows\flutter\ephemeral\.plugin_symlinks\app_links`. Aun compilando, el login está bloqueado por Supabase pausado. Se auditó con las 22 capturas de `docs/auditoria/baseline/` (2026-09-04) cruzadas con el código actual. [EJEC] |
| TODO/FIXME en `lib/` | 1 real (`main.dart:51`, reporte de errores a Crashlytics). |
| Catch vacíos | 0 literales. 4 `catch (_)` que devuelven valor por defecto (aceptables y comentados). |
| `print` en `lib/` | 0. |
| Archivos con `Semantics`/`semanticLabel`/`tooltip` | 14 de 154. |
| Tests golden / integration / migración de esquema | **0 / 0 / 0.** |

---

## 1. RESUMEN DEL PROYECTO

**NexFit (`appgym`)** — app Flutter de entrenamiento de gimnasio: registro de series en vivo,
rutinas, historial, récords personales, estadísticas (5 secciones), objetivos, logros/XP,
retos sociales, nutrición, recuperación, medidas corporales, wearables (Health Connect),
calculadoras, importación/exportación (CSV/XLSX/JSON, Hevy), Coach IA opcional.

**Estado real:** base de código madura y con una disciplina de comentarios muy buena, lógica
de dominio bien probada (repositorios 79–100 %), pero **las capas que tocan el mundo exterior
—sync, auth, Supabase, social, actualizador— están en 0–7 % de cobertura**, y ahí es
exactamente donde están los defectos más graves de esta auditoría. Además el backend está
pausado y hay 45 commits sin subir: hoy **no hay una versión publicable verificada**.

---

## 2. ARQUITECTURA ACTUAL

```
main.dart (composition root: 14 repos + SyncEngine + providers)
  │
  ├─ UI: screens/*  (StatefulWidget + setState; provider para inyección)
  │     HomeShell ─ IndexedStack[Dashboard, EntrenarHub, ProgresoHub, CuerpoHub, Profile]
  │                 + _ActiveWorkoutBanner (Column, ya no Positioned)
  ├─ providers/  Auth, Theme, SyncSettings, WeightUnit, Coach (ChangeNotifier)
  ├─ repositories/  → Drift (SQLite, fuente de verdad, offline-first, ADR-002)
  ├─ core/sync/  SyncEngine → 7 SyncableEntity → Supabase PostgREST (solo push, ADR-005)
  ├─ core/auth/  SupabaseAuthRepository | UnavailableAuthRepository
  ├─ core/coach/ HttpCoachGateway → backend_ia (FastAPI + Groq), opcional por dart-define
  ├─ core/exercise_animation/  AnimationRepository → GymVisualProvider (16 GIF en assets)
  └─ features/import_export, measurements_import  (parsers por registro, bien aislados)
```

| Aspecto | Hallazgo |
|---|---|
| Estado | `setState` local por pantalla; `provider` solo como contenedor DI. Sin capa de ViewModel: la lógica de pantalla (debounce, flush, carga) vive en widgets de 1.000–1.570 líneas. |
| Persistencia | Drift `schemaVersion 12`, 14 tablas. **Ninguna tabla de negocio tiene `userId`** (solo `Profiles.id`). `PRAGMA foreign_keys` apagado (cascadas declaradas no se aplican; se compensa a mano). |
| Sync | Push-only, cola `PendingSetOps` para series, flag `dirty` para el resto. Sin idempotencia, sin transacción local↔remota, sin pull. |
| Auth | Supabase email/contraseña. La app **exige login** para mostrar `HomeShell` (`main.dart` `AuthStatus.authenticated`), pese a ser offline-first. |
| Config | `--dart-define-from-file=env.json` (ignorado por git, correcto). CI: `release.yml` solo en tags, sin `flutter analyze`, sin umbral de cobertura. |

---

## 3. INVENTARIO FUNCIONAL

Estado: ✅ funciona y probado · 🟡 funciona con defectos · 🔴 roto/bloqueado · ⚪ no verificable

| # | Funcionalidad | Qué debería hacer | Estado real | Defectos (ver §4) |
|---|---|---|---|---|
| F1 | Registro / login / reset | Crear cuenta, entrar, recuperar clave | 🔴 bloqueado en producción (Supabase pausado) | C2, M16 |
| F2 | Cerrar sesión | Salir sin dejar datos accesibles a otro usuario | 🔴 | **C1** |
| F3 | Borrar cuenta | Borrar identidad + nube + dispositivo | ⚪ la RPC `nexfit_delete_own_account` tiene el comentario "NO aplicada todavía"; BD pausada, no verificable | C4 |
| F4 | Catálogo de ejercicios (40) + búsqueda/filtro | Listar, filtrar, detalle con animación | ✅ | U3 (FAB tapa último ítem), A4 heredado (licencia GIF, NO VERIFICADO) |
| F5 | Ejercicios propios (CRUD) | Crear/editar/borrar sin romper nada | 🟡 | **H2** |
| F6 | Rutinas (crear/editar/borrar) | Persistir y respaldar | 🟡 | **H1**, M8 |
| F7 | Iniciar entrenamiento (libre / rutina / día) | Crear sesión única, precargar objetivos | 🟡 | H7 |
| F8 | Entrenamiento activo | Series con steppers, completar, descanso, reordenar, reemplazar, notas | 🟡 | H3, H10, M3, U2 |
| F9 | Persistencia tras reinicio del entrenamiento | Reabrir app y seguir exactamente donde estaba | 🟡 (draft + `restEndsAt` absolutos, bien diseñado) | cambios de stepper de los últimos 500 ms se pierden si el SO mata el proceso; sin test de reinicio real con archivo |
| F10 | Finalizar + resumen + récords | Cerrar, recalcular PR, mostrar resumen | 🟡 | M3, M7 |
| F11 | Historial + detalle de sesión | Paginado, detalle | 🟡 (`session_detail_screen` 0 % cobertura) | M-latente `exerciseById[...]!` en `workout_repository.dart:80` |
| F12 | Estadísticas (5 secciones) | Volumen, fuerza, tonelaje, estándares | 🟡 | M7 |
| F13 | Objetivos / Logros-XP / Racha | Seguimiento | 🟡 | U1, M1 |
| F14 | Retos sociales (Supabase RPC) | Crear/unirse por código/leaderboard | ⚪ BD pausada; 0 % cobertura | S6 |
| F15 | Nutrición / Recuperación / Medidas | Registro diario | 🟡 | M4, M3 |
| F16 | Wearables (Health Connect) | Leer pasos/FC/sueño | ⚪ sin dispositivo; `health_service.dart` 0 % | — |
| F17 | Calculadoras (1RM, composición, macros, déficit) | Cálculo puro | ✅ lógica (`calculators.dart` 88 %); pantallas 2 % | — |
| F18 | Importar / exportar (CSV, XLSX, JSON, Hevy) | Round-trip sin pérdida | ✅ lógica probada | S4, M10 |
| F19 | Sync a Supabase | Respaldo fiel | 🔴 | C1, H1, H4, H5, M9 — y nunca se demostró una fila escrita |
| F20 | Coach IA | Chat con contexto | ⚪ oculto en release (sin `SMART_BACKEND_URL`) | — |
| F21 | Autoactualizador APK | Solo canal APK directo | 🟡 desactivado por defecto (correcto para Play) | S3 |
| F22 | Ajustes (tema, unidad, frecuencia de sync, legal) | Configuración | 🔴 enlaces legales | C4 |

---

## 4. ERRORES ENCONTRADOS (clasificados)

### CRÍTICO

**C1 — Los datos locales no están aislados por cuenta: cerrar sesión expone y sube los datos de otro usuario.** [CÓDIGO]
- `providers/auth_provider.dart:113` `logout()` solo llama `signOut()`; **no limpia la base**.
  `clearAllData()` solo se llama en borrar cuenta (`settings_screen.dart:161`).
- Ninguna tabla de negocio tiene `userId` (`core/local/database.dart`).
- Todas las `SyncableEntity` suben filas `dirty` usando `client.auth.currentUser?.id` del
  usuario **actual** (`workout_session_syncable.dart:31`, `routine_syncable.dart:24`...).
- **Escenario:** A entrena sin conexión → cierra sesión → B inicia sesión en el mismo
  teléfono → B ve historial, récords, medidas y nutrición de A, y el `SyncEngine` **sube las
  sesiones de A a la cuenta de B** (RLS lo permite: `user_id` = B). Fuga de datos de salud +
  corrupción del respaldo de B.

**C2 — El backend de producción está pausado.** [EJEC]
Supabase `appgym` = `INACTIVE`. La app exige `AuthStatus.authenticated` para pasar del login
(`main.dart`, `home: Consumer<AuthProvider>`), así que **ningún usuario nuevo puede usar la
app**, y los revisores de Google Play tampoco. Sync, retos y borrado de cuenta caen con él.

**C4 — Bloqueantes de publicación en Play.** [CÓDIGO]
- `core/legal_urls.dart:12-13`: `'<URL_PRIVACIDAD>'` y `'<URL_TERMINOS>'` siguen siendo
  placeholders (los botones de Ajustes muestran "No se pudo abrir el enlace").
- `supabase/migrations/20260907_0004_borrado_de_cuenta.sql:2`: "NO aplicada todavia". Si no está
  aplicada, "Eliminar mi cuenta" falla siempre. **NO VERIFICADO** (BD pausada).

### ALTO

**H1 — Editar una rutina ya sincronizada nunca llega a la nube, y rompe referencias de sesiones pasadas.** [CÓDIGO]
`routine_repository.dart:202` `update()` borra/recrea días y marca `dirty=true`, pero
`routine_syncable.dart:34-38` ve `serverId != null` y **limpia `dirty` sin subir nada** (el
comentario dice "la UI no edita rutinas", falso: `routine_list_screen.dart:62 _editRoutine`).
Además al recrear días cambian sus ids locales → `WorkoutSessions.routineDayId` de sesiones
anteriores queda apuntando a días inexistentes.

**H2 — Borrar un ejercicio propio usado en una rutina deja la rutina inutilizable.** [CÓDIGO]
`exercise_repository.dart:180` solo impide borrar si hay **series**; no mira
`RoutineExercises`. Tras el sync, `exercise_syncable.dart:56` borra la fila local, y
`routine_repository.dart:101` hace `.getSingle()` → `StateError` → no se puede abrir la rutina
ni empezar un entrenamiento desde ella.

**H4 — El sync no es idempotente: duplicados remotos ante cortes.** [CÓDIGO + INFERIDO]
`workout_session_syncable.dart:_pushStart` y `_drainPendingOps`: primero inserta en Supabase,
después escribe `serverId` / borra la op local, sin clave de idempotencia. Si la app muere o la
red cae entre ambos pasos, la próxima pasada **vuelve a insertar** la sesión/serie. Lo mismo en
rutinas (inserta rutina, luego días uno a uno: un fallo a mitad deja una rutina remota
incompleta y la reintenta entera).

**H6 — Migración de Drift desde versiones ≤ 3 probablemente rompe al abrir la base.** [CÓDIGO + INFERIDO]
`database.dart:333-360` (`from < 4`) usa `m.alterTable(TableMigration(workoutSessions ...))`
con la definición **actual** de la tabla, que incluye columnas añadidas en v6/v9/v10
(`title`, `routineDayId`, `exerciseNotes`...). En una base v3 esas columnas no existen y el
copy de `TableMigration` falla → crash al arrancar. **No hay `drift_schemas/` ni tests de
migración.** Requiere test que lo demuestre antes de corregir.

**H7 — "Descartar" un entrenamiento abandonado borra datos sin segunda confirmación y no ofrece guardarlo.** [CÓDIGO]
`start_workout_screen.dart:88-113`: el diálogo ofrece Cancelar / **Descartar y empezar uno
nuevo** / Continuar. Un toque borra sesión y series (`active_workout_repository.dart:discard`).
Falta la opción "Finalizar y guardar" — quien olvidó pulsar Finalizar solo puede perder el
entrenamiento o retomarlo.

**H8 — Las áreas de mayor riesgo no tienen tests y el test del flujo crítico está desactivado.** [EJEC]
Sync 7 % (las 7 entidades en **0 %**), auth 6 %, `social_repository` 0 %, `app_updater` 0 %,
`dashboard_screen` 0 %. `test/screens/home_shell_test.dart:189` `skip: true` es justamente el
test de A1/A2 (banner + FAB + diálogo).

**H10 — El descanso no avisa cuando termina.** [CÓDIGO]
`grep Haptic|SystemSound|vibrat|notification` en `lib/` = 0 resultados. Sin vibración, sonido
ni notificación local, y sin wakelock: con el teléfono en el bolso o la pantalla apagada, el
usuario no se entera de que terminó el descanso. Es la interacción central de una app de gimnasio.

### MEDIO

| ID | Problema | Evidencia |
|---|---|---|
| H3 | **Carrera debounce ↔ completar serie**: el timer de 500 ms llama `_repository.updateSet` **sin await** y borra el pendiente; si el usuario toca ✓ mientras esa escritura está en vuelo, `_flushPendingSetUpdate` no encuentra nada y `setCompleted` lee el peso viejo → récord/XP evaluado mal (se corrige recién al finalizar con `rebuildAll`). | `active_workout_screen.dart:192-198, 208-214` [CÓDIGO+INFERIDO] |
| H5 | Cambios de sesión posteriores al primer push no suben (solo `ended_at`); `title` y `routine_day_id` ni siquiera se envían en el insert. | `workout_session_syncable.dart:57-62, 78-86` [CÓDIGO] |
| M1 | `setState` tras `await` sin `mounted` en Dashboard, Objetivos, Nutrición, Rutinas, Recuperación, Medidas, Gamificación, Lista de ejercicios. En Dashboard es alcanzable: cada re-selección de pestaña cambia la `key` y desmonta el widget con la carga en curso. | `dashboard_screen.dart:58`, `goals_screen.dart:42`... [CÓDIGO] |
| M2 | Se muestran excepciones crudas al usuario (`_error = e.toString()` en ~15 pantallas, `SnackBar('Error al importar: $e')`, `SyncEngine.lastError` en Ajustes): filtra SQL, rutas y mensajes de PostgREST. | grep `e.toString()` [CÓDIGO] |
| M3 | Operaciones sin `try/catch` que dejan la UI colgada: `_finish()` (`active_workout_screen.dart:737`), `NutritionScreen._save` (`nutrition_screen.dart:61`). | [CÓDIGO] |
| M4 | Validación de entradas inexistente en nutrición: texto inválido → `0` silencioso; negativos aceptados (`double.tryParse('-500')`). Revisar mismo patrón en medidas/objetivos/recuperación. | `nutrition_screen.dart:65-69` [CÓDIGO] |
| M7 | Estadísticas cargan **todas** las sesiones y series a memoria y agregan en el isolate de UI; `finishSession` corre `rebuildAll()` O(series totales) en cada cierre. Riesgo de jank en Android de gama baja tras importar Hevy. **Sin medir** → primero benchmark. | `stats_repository.dart:59-70,131-151,259-266`; `workout_repository.dart:224` |
| M8 | `RoutineRepository.get` hace N+1 (una query por ejercicio de cada día). | `routine_repository.dart:96-102` |
| M9 | `addSet`/`updateSet`/`deleteSet` escriben serie + op de sync sin transacción: un crash entre ambas deja una serie que nunca se sincroniza. | `workout_repository.dart:234-275, 439-460` |
| M10 | Importación sin límite de tamaño (`readAsBytes` de todo el archivo). | `file_reader.dart:34` |
| M14 | CI: sin `flutter analyze`, sin umbral de cobertura, tests solo al taggear; 5 commits de CI en remoto no integrados. | `.github/workflows/release.yml` |
| M16 | El login valida longitud ≥ 8 — cuentas con clave previa más corta no pueden entrar desde la app. | `login_screen.dart:202` |

### BAJO
- `workout_repository.dart:80` y `stats_repository.dart:138` usan `exerciseById[...]!`: crash latente si una serie referencia un ejercicio inexistente (import corrupto).
- `start_workout_screen.dart:48`: `workoutRepository.get(staleId)` sin captura (sesión borrada entre dos lecturas).
- `markExerciseCompleted` no pasa por la cola de sync (documentado como intencional).
- 11 infos del analyzer (API `Radio` deprecada), 75 dependencias con versiones nuevas incompatibles, `flutter_launcher_icons.min_sdk_android: 21` vs `minSdk 26`.
- `.cursorrules` y `.windsurfrules` duplicados (35 KB c/u); `legacy/backend_fastapi` versionado; 16 `*.log` en la raíz (ignorados por git, basura local).

---

## 5. RIESGOS DE SEGURIDAD

| ID | Sev. | Riesgo | Evidencia | Test reproducible propuesto |
|---|---|---|---|---|
| S1 (=C1) | **CRÍTICO** | Fuga de datos de salud entre cuentas + subida a cuenta ajena | §4 C1 | Test de integración con `FakeRemote`: login A → sesión offline → logout → login B → `syncNow()` → **assert: el remoto de B tiene 0 sesiones de A** y la UI de B no lista la sesión de A. |
| S2 | ALTO | `android:allowBackup` por defecto (true): la base SQLite (datos de salud) y el token de refresco de Supabase (SharedPreferences) viajan a backups de Google/transferencia de dispositivo | `AndroidManifest.xml` sin `allowBackup`/`dataExtractionRules` | Test de configuración: parsear el manifest y exigir `allowBackup="false"` o reglas que excluyan `databases/` y `shared_prefs/`. Coherente con la declaración de Data safety. |
| S3 | MEDIO | `AppUpdater` abre `apk_url` remoto sin validar esquema ni host (si el endpoint del portafolio es comprometido → cualquier URL) | `app_updater.dart:152-157` | Unit test de `_fetchUpdateInfo` con `apk_url: "http://evil"`, `"intent://..."`, `"javascript:..."` → debe descartarse; solo `https` + host permitido. |
| S4 | MEDIO | Inyección de fórmulas en CSV/XLSX exportado (nombres/notas importados como `=HYPERLINK(...)`) | `export_writers.dart:22`, `excel_writer.dart:37` sin sanitizar | Test: exportar una serie con nota `=1+1` / `+cmd` / `@SUM` → la celda escrita debe empezar con `'`. |
| S5 | MEDIO | Mensajes de error internos visibles (M2) | §4 M2 | Widget test: repo que lanza `SqliteException('SELECT ... secret')` → la pantalla **no** contiene `SELECT` ni `Exception`. |
| S6 | MEDIO | `nexfit_join_challenge_by_code`: códigos de 6 caracteres (32^6 ≈ 1.07e9, `Random.secure`, correcto) pero **sin rate limit** en la RPC; la política `participants_insert_self` permite unirse a cualquier reto conociendo su UUID sin código | `20260904_0001_nexfit_schema.sql:260-261, 310-326` | Test SQL (pgTAP o script con dos JWT de prueba en staging): usuario C inserta directo en `nexfit_challenge_participants` con el UUID de un reto ajeno → debe fallar. **Requiere BD activa.** |
| S7 | BAJO | Importación sin límite de tamaño → denegación local (OOM) | M10 | Test: archivo > límite → `ImportTooLargeException` sin leer el contenido. |
| S8 | INFO | Secretos: `env.json` ignorado y nunca commiteado (verificado en auditoría previa, sin cambios); `SUPABASE_ANON_KEY` es pública por diseño; RLS habilitado en todas las tablas según migraciones. **Estado real de RLS/advisors: NO VERIFICADO (BD pausada).** | — | Al reactivar: `get_advisors security` debe dar 0 ERROR; `leaked_password_protection` sigue pendiente de confirmar. |

---

## 6. PROBLEMAS DE UX/UI

Base: capturas `docs/auditoria/baseline/*.png` (2026-09-04) verificadas contra el código actual.
Identidad a conservar: tema oscuro "Kinetic AI" (`core/theme.dart`), azul primario, acento
violeta solo para IA, tarjetas redondeadas, `PillTabBar`.

| ID | Sev. | Pantalla | Problema | Vigente |
|---|---|---|---|---|
| H10 | ALTO | Entrenamiento activo | Descanso sin aviso háptico/sonoro/notificación; sin wakelock | Sí [CÓDIGO] |
| H7 | ALTO | Iniciar entrenamiento | Descartar destructivo en 1 toque, sin "guardar" | Sí [CÓDIGO] |
| U1 | MEDIO | Dashboard | "Racha de **1 días**" (sin singular) | Sí, `dashboard_screen.dart:267` |
| U2 | MEDIO | Entrenamiento activo | RPE no registrado se muestra como **0.0** (RPE 0 no existe en la escala); ocupa ¼ del ancho de cada fila aunque casi nadie lo usa | Sí, `active_workout_screen.dart:1500` `set.rpe ?? 0` |
| U3 | MEDIO | Lista de ejercicios / rutinas / historial | FAB extendido tapa el último ítem (sin padding inferior) | Sí (captura 02 + sin padding inferior en `exercise_list_screen.dart`) |
| U4 | MEDIO | Entrenamiento activo | Título "Entrenamiento en curso" pegado al borde izquierdo, sin padding (captura 18) | NO VERIFICADO en vivo |
| U5 | MEDIO | Entrenamiento activo | No se ve "la vez anterior" por serie en la fila (el dato existe en `_previousSets`) | Revisar en vivo |
| U6 | MEDIO | Global | Errores técnicos crudos al usuario (M2) | Sí |
| U7 | MEDIO | Global | Accesibilidad: `Semantics` en 14/154 archivos; sin verificación de tamaño mínimo de toque (48 dp) ni de escala de fuente 200 % | Sí |
| U8 | BAJO | Global | Idioma mezclado: voseo ("Elegí", "Tenés", "Probá") en 5 archivos + "Añadir serie" vs "Agregar ejercicio" | Sí |
| U9 | BAJO | Listas | Miniaturas GIF con fondo blanco sobre tema oscuro (A16 "rehecho", pendiente de confirmación visual desde la auditoría anterior) | NO VERIFICADO |

---

## 7. PROBLEMAS DE RENDIMIENTO

| ID | Problema | Estado |
|---|---|---|
| M7 | Estadísticas: carga completa de sesiones+series y agregación en Dart por pestaña | **Sin medir.** Tarea de benchmark primero (20.000 series sembradas, presupuesto por consulta). |
| M7b | `finishSession` → `rebuildAll()` O(total) en cada cierre | Sin medir, mismo benchmark. |
| M8 | N+1 en `RoutineRepository.get` | Medible con contador de queries. |
| P1 | `SyncEngine.syncNow` se dispara por cada evento de conectividad (en Android llegan ráfagas); el lock descarta llamadas sin reprogramar → un cambio hecho durante una pasada espera hasta el siguiente evento/intervalo (3 h) | [CÓDIGO] `sync_engine.dart:44-50, 69-71` |
| P2 | GIFs 180×180 decodificados en listas: aceptable (1,5 MB total). A10/A11 (futuro en `build`, proveedor vacío) **corregidos y probados** (`exercise_thumb_test.dart`). | ✅ |

---

## 8. PROBLEMAS DE ARQUITECTURA

Solo se recomiendan cambios que aportan testabilidad, estabilidad o seguridad.

| ID | Problema | Por qué importa | Recomendación mínima |
|---|---|---|---|
| AR1 | Los `SyncableEntity` reciben `SupabaseClient` concreto | Imposible probar sync sin red → 0 % de cobertura en lo más riesgoso | Introducir un puerto fino `RemoteStore` (insert/update/delete/select por tabla) con implementación Supabase y **`FakeRemoteStore` en memoria** para tests que verifiquen el **estado remoto resultante**, no llamadas. |
| AR2 | Datos locales sin propietario | Causa raíz de C1 | Decidir (D4): limpiar la base al cambiar de cuenta **o** columna `ownerUserId`. La primera es mucho más barata. |
| AR3 | Lógica de estado en widgets gigantes (`active_workout_screen.dart` 1.570, `exercise_detail_screen.dart` 1.060) | H3 vive en el widget y no se puede probar sin montar la pantalla | Extraer **solo** el controlador de edición de series (debounce + flush + serialización de escrituras) a una clase pura testeable. No refactorizar el resto por estética. |
| AR4 | Sin migraciones versionadas de Drift (`drift_schemas/`) | H6 sin red de seguridad | `dart run drift_dev schema dump` por versión + `SchemaVerifier` en tests. Las versiones 1–11 históricas se reconstruyen desde git. |
| AR5 | Sin transacciones en escrituras compuestas (M9) | Estados intermedios persistidos | Envolver en `db.transaction`. |

---

## 9. TESTS EXISTENTES

214 tests (43 archivos, 6.978 líneas). Calidad general **buena**: usan base real en memoria
(`NativeDatabase.memory()`) y verifican resultados persistidos, no mocks (solo 12 usos de
mock/verify en todo `test/`).

| Módulo | Cobertura | Juicio |
|---|---|---|
| repositories (activo, PR, rutinas, stats, ejercicios, goals, gamificación, medidas) | 79–100 % | Fuertes. Ej.: `foreign_key_orphans_test.dart` mide huérfanos reales. |
| `nutrition_repository` / `profile_repository` / `social_repository` | 3 % / 3 % / 0 % | Sin tests. |
| `core/sync` (engine + 7 entidades) | 7 % (entidades 0 %) | Solo 3 tests del engine con entidades falsas; **no prueba `lastError`**, ni ningún payload real. |
| `core/auth` + `auth_provider` | 6 % / 15 % | Sin tests de logout/borrado. |
| screens workout / exercises / history / settings | 52–68 % | Aceptables. |
| screens home/routines/stats/social/nutrition/measurements/recovery/gamification/profile/progreso | 0–13 % | Sin tests. |
| `app_updater`, `health_service`, `export_flow_provider` | 0 % | Sin tests. |

**Tests débiles o engañosos detectados:**
1. `home_shell_test.dart:189` `skip: true` — el único test de integración del flujo A1/A2 no corre. El motivo (timer de `watchSingleOrNull` en `NativeDatabase.memory()`) tiene solución conocida (cerrar la base dentro del test + `pumpAndSettle` acotado, o `DriftIsolate` síncrono); **no es aceptable dejarlo en skip**.
2. `sync_engine_test.dart` "concurrente no duplica llamadas" prueba el lock, pero oculta P1 (la llamada descartada nunca se reprograma).
3. `widget_test.dart` solo verifica que arranca en login — no prueba nada de negocio.
4. No hay **ningún test de persistencia tras reinicio real** (cerrar `AppDatabase` sobre archivo y reabrir otra instancia). Los tests de "reinicio" reutilizan la misma base en memoria.

---

## 10. TESTS FALTANTES (priorizados)

1. **Aislamiento entre cuentas** (C1) — integración con `FakeRemoteStore`.
2. **Contrato de cada `SyncableEntity`** (AR1) — estado remoto tras create/update/delete, reintento tras fallo a mitad (H4), edición de rutina (H1), campos de sesión (H5).
3. **Migraciones Drift v1→v12** (H6) con `SchemaVerifier` y datos sembrados.
4. **Reinicio real**: base en archivo temporal → cerrar → reabrir → draft, `restEndsAt`, serie, PR intactos.
5. **Carrera debounce/completar** (H3) con `fakeAsync`.
6. **Integridad referencial de ejercicios propios** (H2).
7. **Flujo A1/A2 del shell** (des-skip).
8. **Seguridad**: S2–S7 según §5.
9. **Golden tests** de 8 pantallas clave × 2 tamaños (360×640 y 412×915) × escala de texto 1.0/1.3.
10. **Benchmarks** de estadísticas y `rebuildAll` (M7) con presupuesto.
11. Validación de formularios (nutrición, medidas, objetivos, recuperación): válido / vacío / negativo / no numérico / extremo.
12. Auth: logout limpia estado; borrar cuenta limpia base y prefs; error de red en borrado no limpia nada local.

---

## 11. REGRESIONES POTENCIALES (qué puede romperse al corregir)

| Corrección | Qué puede romper | Test de regresión obligatorio |
|---|---|---|
| Limpiar base al cambiar de cuenta (C1) | Borrar datos **no sincronizados** del propio usuario al re-loguear | Mismo usuario sale y vuelve a entrar → sus datos siguen ahí; usuario distinto → aviso si hay `dirty` pendientes antes de borrar |
| Sync idempotente (H4) | Esquema remoto (nueva columna `client_id` única) → migración Supabase | Push doble de la misma fila → 1 fila remota |
| Subir ediciones de rutina (H1) | Sesiones que referencian `routine_day_id` remoto | Editar rutina → sesiones previas conservan su día |
| Reescribir migración `from < 4` (H6) | Usuarios actuales en v12 (la migración no corre) | `SchemaVerifier` de v11→v12 y v3→v12 |
| Serializar escrituras del stepper (H3) | Latencia percibida al tocar +/- | Test de 32 toques → 1 escritura, valor final correcto |
| Aviso de descanso (H10) | Nuevo permiso de notificaciones (Android 13+) → Data safety | Sin permiso concedido la app no falla |
| Ocultar errores crudos (M2) | Perder diagnóstico | Error se registra con `developer.log` + mensaje amigable |

---

## 12. DEUDA TÉCNICA

- Cobertura 36 % global, 0 % en integración externa.
- Sin tests golden/E2E/migración.
- 2 archivos de pantalla > 1.000 líneas con lógica de estado mezclada.
- `PRAGMA foreign_keys` apagado con cascadas compensadas a mano en 3 lugares.
- Push-only sin pull (ADR-005): el respaldo no restaura nada (reinstalar = perder todo). Decisión consciente, pero el Data safety debe decirlo con honestidad.
- 45 commits locales sin subir; CI remoto y local divergentes.
- Carpeta `legacy/`, reglas de IDE duplicadas, logs sueltos.

---

## 13. PRIORIDADES

| Prioridad | IDs | Criterio |
|---|---|---|
| **P0 — decisiones humanas (bloquean todo)** | D1 Supabase pausado · D2 divergencia git · D3 URLs legales · D4 política de datos al cambiar de cuenta | No se pueden resolver con código |
| **P0 — sistema de calidad** | Q1–Q4 | NO TEST = NO FEATURE necesita la infraestructura primero |
| **P1 — integridad y seguridad** | C1, H2, H4, H1, H6, S2 | Pérdida/fuga de datos |
| **P2 — UX central y robustez** | H10, H7, H3, M3, M1, M2 | Experiencia durante el entrenamiento |
| **P3 — rendimiento medido, validación, seguridad media** | M7, M8, M9, M4, S3, S4, M10, H5 | |
| **P4 — pulido** | U1–U9, M14, M16, bajos | |

---

## 14. PLAN DE CORRECCIÓN

**Fase 0 (humano):** D1–D4.
**Fase 1 (calidad, sin tocar comportamiento):** Q1 test-lock + CI gates → Q2 puerto `RemoteStore` + fake → Q3 esquemas Drift → Q4 des-skip del shell + infraestructura golden.
**Fase 2 (datos):** T-C1 → T-H2 → T-H4 → T-H1 → T-H6 → T-S2.
**Fase 3 (entrenamiento):** T-H10 → T-H7 → T-H3 → T-M3 → T-M1/M2.
**Fase 4 (medir y optimizar):** T-M7 (benchmark → decidir) → T-M8/M9 → T-M4 → T-S3/S4/M10 → T-H5.
**Fase 5 (visual):** goldens base → U1–U8 con diff de golden aprobado por Opus.

Cada tarea sigue el flujo: Opus escribe tests → Opus demuestra ROJO → Sonnet implementa →
Sonnet reporta evidencia → Opus audita código + tests + diff + ejecución → Quality Gate.

---

## 15. SISTEMA DE TESTS PROPUESTO

### 15.1 Capas

| Capa | Herramienta | Qué prueba | Dónde |
|---|---|---|---|
| Unidad | `flutter_test` | Lógica pura (calculadoras, parsers, validadores, controlador de series) | `test/unit/**` |
| Repositorio | Drift `NativeDatabase.memory()` | Estado persistido real | `test/repositories/**` |
| Persistencia/reinicio | Drift sobre **archivo temporal**, cerrar y reabrir otra `AppDatabase` | Lo que sobrevive a matar la app | `test/persistence/**` |
| Migración | `drift_dev schema dump` + `SchemaVerifier` | v1…v12 → actual con datos | `test/migrations/**`, `drift_schemas/` |
| Contrato de sync | `FakeRemoteStore` en memoria (tablas + RLS simulada por `user_id`) | **Estado remoto final**, idempotencia, fallos a mitad | `test/sync/**` |
| Widget | `testWidgets` | Estados: cargando / vacío / error / datos / overflow a 320 dp | `test/screens/**` |
| Golden (regresión visual) | `matchesGoldenFile`, fuentes empaquetadas (`GoogleFonts.config.allowRuntimeFetching = false`), 2 tamaños × 2 escalas de texto | Desplazamientos, overflow, componentes perdidos | `test/golden/**`, PNG en `test/golden/goldens/` |
| Seguridad | Unit/widget + tests de configuración (manifest) | S1–S7 | `test/security/**` |
| Rendimiento | Tests `@Tags(['perf'])` con datos sembrados y presupuesto (ms) | M7 | `test/perf/**` (fuera del run por defecto, obligatorio en CI nocturno/tag) |
| E2E | `integration_test` en Windows desktop (Drift funciona; auth inyectada) | Flujo completo empezar→series→finalizar→historial→reinicio | `integration_test/**` |
| Backend SQL | Script con 2 JWT de prueba contra **proyecto staging/branch**, nunca producción | RLS, RPC | `supabase/tests/**` |

### 15.2 Reglas de un test aceptable (Opus rechaza lo que no cumpla)
1. Verifica **resultado observable** (fila en base, estado remoto, texto en pantalla), no que una función fue llamada.
2. Tiene caso normal + límite + inválido; y seguridad cuando hay entrada externa.
3. Fue **visto en ROJO** antes de la implementación (evidencia: salida del run en el commit base).
4. No usa `skip:`, ni `expect(true, ...)`, ni `catch` que traga el fallo, ni `pumpAndSettle` sin límite.
5. Nombre = requisito en español ("no sube sesiones de otra cuenta tras cambiar de usuario").
6. Mutación manual: Opus rompe a propósito la línea clave de la implementación y el test **debe** fallar. Si sigue verde, el test se rechaza.

### 15.3 Mecanismos anti-trampa

| Riesgo | Mecanismo |
|---|---|
| Borrar/debilitar tests | `test/.test-lock.json` con SHA-256 de cada archivo de test escrito por Opus. `tools/check_test_lock.dart` en CI y en cada auditoría: si un archivo bloqueado cambia sin entrada en `docs/qa/TEST_CHANGES.md` firmada con `APPROVED-BY: OPUS TASK-ID`, **falla**. |
| `skip:` / `@Skip` / `// ignore:` nuevos | Check en CI: grep de diff; solo pasan con comentario `// SKIP-APPROVED: <TASK-ID>` registrado por Opus. |
| Cambiar criterios de aceptación | Los criterios viven en `docs/qa/tasks/<TASK-ID>.md` (bloqueados en el mismo lock). Sonnet solo puede proponer cambios en su REPORT con `REQUIREMENT_CHANGE_REQUEST`. |
| Tragar errores para pasar | Lints nuevos en `analysis_options.yaml`: `empty_catches`, `avoid_catches_without_on_clauses` (info→warning en código nuevo), `unawaited_futures`, `use_build_context_synchronously`; `flutter analyze --fatal-warnings` en CI. |
| Bajar cobertura | `tools/coverage_gate.dart`: los archivos tocados por la tarea no pueden bajar su % y deben quedar ≥ 80 % de líneas (excepto `*.g.dart`). |
| "Terminado" sin evidencia | El REPORT de Sonnet debe incluir salida literal de `flutter analyze`, `flutter test <archivos de la tarea>` y `flutter test` completo, y `git diff --stat`. Opus **re-ejecuta** los tests; nunca aprueba por el reporte. |
| Cambiar comportamiento solo para el test | Opus revisa el diff de `lib/` contra los criterios, y aplica la mutación manual de 15.2.6. |
| Goldens regenerados a escondidas | `--update-goldens` solo lo ejecuta Opus; un PNG de golden modificado sin entrada en `TEST_CHANGES.md` falla el lock (los PNG también llevan hash). |

---

## 16. QUALITY GATE PROPUESTO

Una tarea es **DONE** solo si todos los puntos obligatorios (●) están marcados. Cualquier ● sin
marcar → `REJECTED` (defecto del trabajo) o `BLOCKED` (depende de un tercero).

```
● requisito definido (docs/qa/tasks/<ID>.md)
● criterios de aceptación definidos y bloqueados
● tests creados por Opus y registrados en test-lock
● evidencia de ROJO previo a la implementación
● flutter analyze: 0 errores, 0 warnings (infos nuevos justificados)
● tests de la tarea en verde (salida literal)
● suite completa en verde (salida literal), sin skips nuevos
● test-lock íntegro (tools/check_test_lock.dart OK)
● cobertura de archivos tocados ≥ 80 % y sin descenso
● tests de seguridad en verde (si la tarea tiene superficie de entrada/datos)
● mutación manual por Opus: el test falla al romper la implementación
● diff revisado por Opus (sin archivos no declarados)
● no se modificaron requisitos ni tests sin aprobación registrada
○ golden diff aprobado por Opus (obligatorio si el cambio es visual)
○ benchmark dentro de presupuesto (obligatorio si la tarea es de rendimiento)
○ documentación/ADR actualizada (si cambia arquitectura o datos)
● OPUS: APPROVED
```

---

# BACKLOG DE TAREAS PARA SONNET

> Convención: **Opus** escribe los tests listados en "Tests antes de implementar" y demuestra
> el ROJO; recién entonces la tarea se envía a Sonnet. Máx. 3 archivos de producción por tarea
> salvo que se indique.

### DECISIONES HUMANAS (bloquean las tareas indicadas)
| ID | Decisión | Bloquea |
|---|---|---|
| D1 | Reactivar Supabase `appgym` (panel → Restore) o decidir otro backend. Opus solo hará consultas de lectura después. | T-C1 (verif. remota), T-S6, verificación de C4 |
| D2 | Integrar `origin/master` (5 commits de CI) con los 45 locales: merge o rebase, y push. | Q1 (CI) |
| D3 | Publicar Privacidad/Términos y dar las URL. | T-C4 |
| D4 | Política al cambiar de cuenta: **(a) recomendado** limpiar base local si el usuario nuevo ≠ último usuario (con aviso si hay datos sin sincronizar) · (b) columna de propietario en todas las tablas. | T-C1 |

---

### Q1 — Test-lock y gates de CI
- **Problema:** nada impide borrar/saltar tests ni bajar cobertura; CI sin analyze.
- **Causa:** no existe infraestructura de calidad.
- **Objetivo:** hacer técnicamente imposible "pasar" sin tests íntegros.
- **Archivos:** `tools/check_test_lock.dart` (nuevo), `tools/coverage_gate.dart` (nuevo), `.github/workflows/ci.yml` (nuevo), `analysis_options.yaml`.
- **Riesgo:** bajo (no toca `lib/`). **Dependencias:** D2.
- **Criterios:** (1) modificar un byte de un test bloqueado sin entrada aprobada → exit≠0; (2) con entrada aprobada → exit 0; (3) `skip:` nuevo sin `SKIP-APPROVED` → falla; (4) cobertura de archivo tocado < 80 % o en descenso → falla; (5) CI corre analyze+test+lock+coverage en cada push/PR.
- **Tests antes:** `test/tools/check_test_lock_test.dart` (lock íntegro, byte alterado, archivo borrado, archivo nuevo no registrado, entrada aprobada), `test/tools/coverage_gate_test.dart` (lcov sintético: sube, baja, <80, `*.g.dart` excluido).
- **Seguridad:** el lock no acepta rutas fuera de `test/`/`integration_test/` (path traversal en el JSON).
- **Regresión:** suite actual sigue verde.
- **Visual:** —
- **Resultado esperado:** CI rojo ante cualquier trampa listada en §15.3.

### Q2 — Puerto `RemoteStore` + `FakeRemoteStore`
- **Problema:** sync 0 % probado (AR1).
- **Causa:** entidades acopladas a `SupabaseClient`.
- **Objetivo:** probar sync por estado remoto resultante sin red. **Sin cambiar comportamiento.**
- **Archivos:** `lib/core/sync/remote_store.dart` (nuevo), `lib/core/sync/supabase_remote_store.dart` (nuevo), las 7 entidades (cambio mecánico de tipo) — excepción autorizada al límite de 3 archivos, solo sustitución de dependencia.
- **Riesgo:** medio. **Dependencias:** Q1.
- **Criterios:** payloads idénticos a los actuales (golden de JSON por entidad); `FakeRemoteStore` aplica `user_id` como RLS.
- **Tests antes:** `test/sync/<entidad>_contract_test.dart` × 7 caracterizando el comportamiento **actual** (incluidos los defectos H1/H4/H5 marcados como `// CARACTERIZA DEFECTO H1`, que se invertirán en sus tareas).
- **Seguridad:** fake rechaza escrituras con `user_id` ≠ usuario actual.
- **Regresión:** suite completa.
- **Resultado esperado:** cobertura `core/sync` ≥ 80 %, sin cambios funcionales.

### Q3 — Esquemas Drift versionados + tests de migración
- **Problema:** H6 sin red de seguridad.
- **Archivos:** `drift_schemas/drift_schema_v1..v12.json` (reconstruidos desde git con `drift_dev schema dump`), `test/migrations/migration_test.dart`.
- **Riesgo:** bajo (no toca `lib/`). **Dependencias:** Q1.
- **Criterios:** migración verificada de cada vN→v12 con datos; el test de v3→v12 **demuestra o descarta** H6 con evidencia.
- **Resultado esperado:** si H6 se confirma → abre T-H6; si no → H6 cerrado con evidencia.

### Q4 — Des-skip del test del shell + infraestructura golden
- **Problema:** H8 (test crítico en skip), 0 goldens.
- **Archivos:** `test/screens/home_shell_test.dart`, `test/golden/golden_config.dart` (nuevo), `test/flutter_test_config.dart` (nuevo, fuentes empaquetadas).
- **Criterios:** test A1/A2 corre y pasa sin `skip`; 8 pantallas × 2 tamaños × 2 escalas con goldens aprobados por Opus; overflow detectado como fallo (`FlutterError.onError` → fail).
- **Resultado esperado:** base de regresión visual para la Fase 5.

### T-C1 — Aislamiento de datos entre cuentas
- **Problema:** C1/S1.
- **Causa:** logout no limpia; tablas sin propietario; sync usa usuario actual.
- **Objetivo:** ningún dato de A visible ni subido para B.
- **Archivos:** `lib/providers/auth_provider.dart`, `lib/core/local/database.dart` (solo método de limpieza/marca de último usuario), `lib/screens/profile/profile_screen.dart` (aviso de datos sin sincronizar).
- **Riesgo:** ALTO (borrado de datos). **Dependencias:** D4, Q2.
- **Criterios:** (1) A→logout→B: B ve 0 sesiones/rutinas/medidas/nutrición de A; (2) remoto de B no recibe filas de A; (3) A→logout→A: datos de A intactos; (4) logout con filas `dirty` muestra aviso con opción de cancelar; (5) `SyncEngine` no corre pasada entre logout y limpieza (sin carrera).
- **Tests antes:** `test/security/account_isolation_test.dart` (casos 1–5), `test/persistence/account_switch_restart_test.dart` (cambio de cuenta + reinicio con base en archivo).
- **Seguridad:** S1 completo; SharedPreferences sensibles también limpiados.
- **Regresión:** borrar cuenta sigue limpiando todo; suite completa.
- **Visual:** golden del diálogo de aviso.
- **Resultado esperado:** C1 cerrado con prueba reproducible.

### T-H2 — Integridad de ejercicios propios usados en rutinas
- **Archivos:** `lib/repositories/exercise_repository.dart`, `lib/repositories/routine_repository.dart`, `lib/screens/exercises/exercise_detail_screen.dart` (mensaje).
- **Riesgo:** medio. **Dependencias:** Q1.
- **Criterios:** no se puede borrar un ejercicio referenciado por una rutina (mensaje claro) **o** se quita de la rutina con confirmación; `RoutineRepository.get` nunca lanza por un ejercicio faltante (lo omite y lo informa).
- **Tests antes:** repo: borrar referenciado → `StateError` específico; rutina con ejercicio faltante (fila borrada a mano) → `get` devuelve la rutina sin ese ejercicio; tras sync simulado con `FakeRemoteStore` la rutina sigue abriendo.
- **Regresión:** borrar ejercicio sin referencias sigue funcionando; A15 soft-delete intacto.

### T-H4 — Sync idempotente
- **Archivos:** nueva migración Supabase `client_id uuid unique` en sesiones/series/rutinas (**se escribe, no se aplica sin OK humano**), `workout_session_syncable.dart`, `routine_syncable.dart`.
- **Riesgo:** ALTO. **Dependencias:** Q2, D1.
- **Criterios:** fallo inyectado después del insert remoto y antes de la escritura local → la siguiente pasada deja **exactamente 1** fila remota; rutina con fallo a mitad de días → estado remoto final completo y sin duplicados.
- **Tests antes:** `test/sync/idempotency_test.dart` con `FakeRemoteStore` que lanza en punto configurable.
- **Seguridad:** `client_id` no permite pisar filas de otro usuario (fake con RLS).
- **Regresión:** contratos de Q2.

### T-H1 — Ediciones de rutina sincronizadas y referencias de días estables
- **Archivos:** `routine_repository.dart` (actualizar días en sitio en vez de recrear), `routine_syncable.dart`.
- **Riesgo:** medio-alto. **Dependencias:** Q2, T-H4.
- **Criterios:** editar nombre/días/ejercicios de rutina sincronizada → estado remoto igual al local; sesiones previas mantienen `routineDayId` válido.
- **Tests antes:** invertir la caracterización `DEFECTO H1` de Q2; test de repo: editar rutina → ids de días conservados.

### T-H6 — Corregir migración `from < 4` (solo si Q3 lo confirma)
- **Archivos:** `lib/core/local/database.dart`.
- **Criterios:** v1/v2/v3 → v12 abre con datos intactos; v11→v12 sin cambios.
- **Tests antes:** los de Q3 que fallan.

### T-S2 — Backups de Android
- **Archivos:** `android/app/src/main/AndroidManifest.xml`, `android/app/src/main/res/xml/data_extraction_rules.xml` (nuevo), `docs/legal/PLAY_DATA_SAFETY.md`.
- **Criterios:** base y prefs excluidas de backup en la nube y transferencia; declaración de Data safety coherente.
- **Tests antes:** `test/security/android_manifest_test.dart` (parsea XML).

### T-H10 — Aviso de fin de descanso
- **Archivos:** `lib/screens/workout/rest_timer_banner.dart`, `pubspec.yaml` (wakelock y notificaciones locales, decisión de dependencia a confirmar por Opus), `AndroidManifest.xml`.
- **Riesgo:** medio (permiso nuevo). **Dependencias:** Q1, Q4.
- **Criterios:** al llegar a 0 con la app en primer plano → vibración + sonido corto una sola vez; en segundo plano → notificación programada a `restEndsAt`; extender/descartar descanso reprograma/cancela; permiso denegado → sin crash; pantalla no se apaga durante entrenamiento activo (configurable).
- **Tests antes:** con `fakeAsync` y un `RestAlertPort` falso: 1 alerta exacta al vencer, 0 tras descartar, reprogramación al extender, reinicio con `restEndsAt` pasado no dispara alerta retroactiva.
- **Visual:** golden del banner a 0 s.

### T-H7 — Diálogo de entrenamiento abandonado seguro
- **Archivos:** `lib/screens/workout/start_workout_screen.dart`.
- **Criterios:** opciones Continuar / **Finalizar y guardar** / Descartar (con segunda confirmación que indica cuántas series se borran) / Cancelar.
- **Tests antes:** widget: Descartar sin confirmar no borra; Finalizar y guardar deja la sesión en historial con `endedAt`; sesión borrada entre lecturas no cuelga la pantalla.
- **Visual:** golden del diálogo a 360 dp (4 botones sin overflow).

### T-H3 — Serializar escrituras del stepper antes de completar serie
- **Archivos:** `lib/screens/workout/set_edit_controller.dart` (nuevo, extraído), `active_workout_screen.dart`.
- **Criterios:** tocar +10 veces y ✓ inmediatamente → el récord se evalúa con el valor final; 32 toques → 1 escritura; cerrar pantalla con escritura en vuelo → valor final persistido.
- **Tests antes:** `test/unit/set_edit_controller_test.dart` con `fakeAsync` y repo en memoria con latencia artificial.

### T-M3 — Errores en finalizar / guardar no dejan la UI colgada
- **Archivos:** `active_workout_screen.dart`, `nutrition_screen.dart`.
- **Tests antes:** repo que lanza en `finish` → botón vuelve a habilitarse, mensaje amigable, draft intacto, reintento funciona.

### T-M1/M2 — `mounted` y mensajes de error seguros
- Dividir en 3 tareas de ≤3 pantallas cada una (Dashboard/Objetivos/Nutrición · Rutinas/Recuperación/Medidas · Gamificación/Ejercicios/Ajustes).
- **Tests antes:** por pantalla: desmontar con carga en curso → 0 excepciones de framework; repo que lanza `Exception('SELECT secret')` → la UI no muestra `SELECT`/`Exception`, sí un mensaje y botón Reintentar; el error queda en `developer.log`.

### T-M7 — Benchmark de estadísticas (medir antes de optimizar)
- **Archivos:** `test/perf/stats_perf_test.dart` (lo escribe Opus). Sonnet no implementa nada hasta tener números.
- **Criterios:** sembrar 1 año (4.200 series) y 5 años de Hevy (20.000); registrar ms de cada método de `StatsRepository` y de `rebuildAll`. Presupuesto propuesto: < 150 ms por consulta a 20.000 series en desktop CI (equivale aprox. a < 600 ms en gama baja). Solo si se excede se crea la tarea de optimización.

### T-M8 / T-M9 — N+1 de rutinas · transacciones en series
- **Tests antes:** contador de queries (`QueryInterceptor` de Drift) ≤ 4 para una rutina de 5 días × 6 ejercicios; crash simulado entre inserción de serie y op → ambas o ninguna.

### T-M4 — Validación de formularios
- Una tarea por pantalla (nutrición, medidas, objetivos, recuperación).
- **Tests antes:** válido / vacío / no numérico / negativo / cero / extremo (p. ej. 100.000 kcal) / coma decimal `72,5` / espacios / 1.000 caracteres → no persiste nada inválido y muestra error en el campo.

### T-S3 / T-S4 / T-M10 — Actualizador, exportación, tamaño de importación
- **Tests antes:** según §5 (S3, S4, S7).

### T-H5 — Campos de sesión en sync
- **Dependencias:** Q2, T-H4. **Tests antes:** cambiar título/notas/día tras primer push → remoto actualizado.

### T-C4 — URLs legales
- **Dependencias:** D3. **Tests antes:** `LegalUrls` no contiene `<`/`>` y son `https` (test que hoy falla).

### Fase 5 — UX (cada una con golden diff aprobado)
U1 plural de racha · U2 RPE vacío como "—" · U3 padding inferior bajo FAB en listas · U4 padding del encabezado del entrenamiento · U5 valor anterior en la fila · U7 Semantics + 48 dp en controles del entrenamiento · U8 unificar voseo/tuteo (decisión D5 del dueño: ¿español neutro?).

---

**AUDITORÍA INICIAL: COMPLETADA** — con 3 limitaciones declaradas: Supabase pausado (no se
verificó el estado remoto), sin ejecución visual en vivo (sin emulador; build de Windows con
symlinks rotos y login bloqueado por C2), y hallazgos heredados sobre licencia de GIFs (A4) no
re-verificados.
