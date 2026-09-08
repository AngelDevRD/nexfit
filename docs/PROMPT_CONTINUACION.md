# NEXFIT — Continuación (respuesta a "¿migraciones o A25?")

> Pegar en la sesión que viene trabajando las Fases 2–6. Continúa
> `docs/PROMPT_FASES_2-6.md`, que sigue vigente para todo lo no dicho acá.

---

## RESPUESTA A TU PREGUNTA

**Seguí con A25 y el resto del código. Las migraciones de Supabase al final, en una
sola sesión dedicada.** Tres razones:

1. **No están autorizadas todavía.** Tu reporte dice "ya autorizado" — no lo está. El
   usuario respondió "ok" a un mensaje que ofrecía *escribir* las migraciones, y se le
   contestó explícitamente que eso se tomaba como luz verde para escribir, **no** para
   aplicar. Nunca dijo "aplicá". El backup y el OK explícito siguen pendientes. No lo
   des por hecho.
2. **Secuencia.** A15 (`ExerciseSyncable`) depende de que exista
   `nexfit_custom_exercises`, que la crea `20260905_0002`. Aplicar ahora y escribir A15
   más tarde parte el trabajo sobre el proyecto real en dos momentos sin ganar nada.
3. **A25 puede cambiar qué migrás.** Si medir los huérfanos revela caminos de borrado
   rotos, eso afecta qué conviene sincronizar y cómo. Medir primero es barato.

---

## 1. ANTES DE SEGUIR: reabrí A2 · **prioridad alta**

Aislaste bien que no era `WearablesScreen`. Pero la conclusión *"es un problema de
entorno de test, no de la UI"* es prematura. Mirá `lib/screens/home/home_shell.dart`,
dentro de `_ActiveWorkoutBanner.build`:

```dart
final activeRepository = context.watch<ActiveWorkoutRepository>();
return StreamBuilder<int?>(
  stream: activeRepository.watchCurrentSessionId(),
```

`watchCurrentSessionId()` se llama **dentro de `build()`** y devuelve un `Stream` nuevo
en cada invocación. `StreamBuilder` ve otra identidad de stream, cancela la suscripción
anterior y abre una nueva. Cada `setState` de `HomeShell` — cada cambio de pestaña, cada
bump de `_dashboardEpoch` / `_progresoEpoch` — tira y recrea una query reactiva de Drift.

Es **exactamente el mismo defecto** que ya arreglaste en A10 con `ExerciseThumb` (future
creado en `build`), y **corre igual en producción**: no es un artefacto del
`NativeDatabase.memory()`. Es la causa más probable del `Timer` pendiente que te cuelga
el test.

**Qué hacer:**
1. Convertí `_ActiveWorkoutBanner` a `StatefulWidget` y cacheá el stream en un campo del
   `State`, resuelto una sola vez en `initState` (mismo patrón que usaste en
   `ExerciseThumb`). `context.watch` ahí tampoco aporta nada: `ActiveWorkoutRepository`
   se provee con `Provider.value` y no es un `Listenable`; un `context.read` en
   `initState` alcanza.
2. Volvé a correr el test de `HomeShell` que habías descartado.
3. **Si el cuelgue desaparece:** ganaste el test de regresión de A2 *y* un bug real de
   producción. Documentá ambos.
4. **Si sigue colgando:** ahí sí cerralo como limitación del entorno de test, dejá A2 con
   verificación manual, y dejá igual el fix del stream cacheado — es una mejora válida
   por sí sola.

---

## 2. ORDEN DE TRABAJO A PARTIR DE ACÁ

### Paso 1 — A2 reabierto (arriba).

### Paso 2 — A25: medir el daño de las claves foráneas
Tal como está en `docs/PROMPT_FASES_2-6.md`, bloque B. Recordá el orden:
1. Test que **mida** los huérfanos reales (crear rutina con días y ejercicios, borrarla,
   contar filas huérfanas). Lo mismo para sesiones.
2. Auditar cada camino de borrado: `RoutineRepository`, `WorkoutRepository`,
   `WorkoutSessionSyncable._pushDelete`, `DataImportService`.
3. **Presentar las dos opciones al usuario con los números del paso 1** — pragma global
   vs. borrado explícito por repositorio. No elijas sola: activar
   `PRAGMA foreign_keys = ON` puede hacer estallar bases ya instaladas con huérfanos
   previos.

### Paso 3 — Código puro restante
- **A16** — fondo blanco de los GIFs sobre el tema oscuro (`ExerciseThumb` +
  `ExerciseAnimationViewer`, mismo tratamiento en ambos).
- **A18** — accesibilidad: `tooltip` en los `IconButton` de `lib/screens/workout/` y
  `lib/screens/exercises/`, el check por serie anunciando estado, `Semantics(button:)` en
  las tarjetas clicables. Modelo: `lib/widgets/stepper_field.dart`. No persigas los 154
  archivos.
- **A23** — borrar `lib/main_audit.dart` (confirmá antes).
- **`lib/features/pose/`** — decisión del usuario: activar o eliminar con `camera` y
  `google_mlkit_pose_detection`.

### Paso 4 — Supabase, todo junto y al final
En este orden, sin saltear:
1. Pedí **backup explícito** (panel → Database → Backups) y **OK explícito** para aplicar.
2. Aplicá `20260905_0002_alinear_esquema.sql`, después `20260905_0003_endurecer_rls.sql`.
3. Verificá con los advisors que desaparecieron los lints `0003_auth_rls_initplan` y
   `0028_anon_security_definer_function_executable`.
4. Pedile al usuario que active *Prevent use of leaked passwords* (Authentication →
   Sign In / Providers → Password). **A8 no es SQL, no podés hacerlo vos.**
5. Recién ahí: **A15** (`ExerciseSyncable` contra `nexfit_custom_exercises`) y mandar
   desde el sync los campos nuevos (`title`, `exercise_notes`, `exercise_order`, y las 5
   columnas de `nexfit_routine_exercises`).
6. **No mandes `routine_day_id`**: la columna existe pero no se puede poblar. El motivo
   está documentado dentro de la propia migración (la tabla local `RoutineDays` no tiene
   `serverId`, no hay forma de traducir el int local al uuid remoto).

---

## 3. SOBRE LO QUE YA HICISTE

Sólido en general. Dos observaciones:

- **A14** — condicionar la tarjeta "Gemelo Digital" a `SmartBackendAvailability.isConfigured`
  en vez de borrarla es mejor decisión que la que estaba escrita en el prompt original.
  De acuerdo, dejalo así.
- **A20** — **no lo marques como cerrado.** Volver el CI a `windows-latest` está sin
  verificar: hace falta una corrida real de CI en verde. Si falla, el rollback es una
  línea. Dejalo explícito en el resumen final como "pendiente de confirmar en CI".

---

## 4. RECORDATORIOS QUE SIGUEN VIGENTES

- Después de cada tarea: `flutter analyze --no-pub` (0 errores/warnings, los 11 infos
  preexistentes son tolerables) → `flutter test --no-pub` (todos verdes).
- Antes de cada corrida de tests en Windows:
  `taskkill //F //IM flutter_tester.exe //IM dart.exe >/dev/null 2>&1; sleep 2`
  Y no uses `timeout` externo con `flutter test`: mata al padre y deja el hijo colgado,
  que es justo lo que produce el lock del `sqlite3.dll`.
- Nada de `git commit` / `git push` sin pedirlo.
- Nada aplicado a Supabase sin OK explícito.
- No rediseñes visualmente: reusá los tokens de `lib/core/theme.dart`.
