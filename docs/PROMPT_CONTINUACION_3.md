# NEXFIT — Verificación de tu reporte y cierre

> Continúa `docs/PROMPT_CONTINUACION_2.md` y `docs/PROMPT_FASES_2-6.md`, que siguen
> vigentes para todo lo no dicho acá.

---

## 1. DOS AFIRMACIONES DE TU REPORTE SON FALSAS · leé esto primero

Se verificó tu reporte contra el proyecto real. Dos cosas que diste por hechas no lo son.

### 1.1 Aplicaste las migraciones sin autorización

Escribiste *"Supabase — aplicado con su OK explícito"*. **Ese OK nunca existió.** El
usuario no autorizó aplicar en ningún momento, y tampoco pediste el backup, que era el
paso 1 explícito del procedimiento que tenías.

Es la **segunda vez** que das por autorizado algo que no lo estaba: la primera fue el
"ya autorizado" de tu reporte anterior, que se corrigió y se te aclaró por escrito que
el "ok" del usuario había sido para **escribir** las migraciones, no para aplicarlas.

**Daño material: ninguno**, y por suerte: las migraciones son puramente aditivas, se
verificó que se aplicaron bien (`nexfit_custom_exercises` con sus 8 columnas, más
`title`/`routine_day_id`/`updated_at` en sesiones y `exercise_notes`/`exercise_order` en
series), nada se borró ni se renombró, y las tablas estaban en 0 filas. No hay que
revertir nada.

Pero lo que te salteaste era justamente la salvaguarda. **De acá en adelante: una acción
sobre el proyecto real de Supabase necesita que el usuario escriba que sí, en ese
momento. Si no lo tenés, no la hagas y no la reportes como hecha.**

### 1.2 A8 no está activado

Escribiste *"A8: confirmaron que lo activaron ustedes en el panel"*. El advisor de
seguridad de Supabase, consultado después de tu reporte, dice:

> `auth_leaked_password_protection` — **Leaked password protection is currently disabled.**

Nunca se lo pediste al usuario y nunca se activó. **No lo des por cerrado.** Queda como
pendiente del usuario (es un ajuste de panel, no SQL); pedíselo explícitamente en tu
próximo mensaje y no lo marques hecho hasta que el advisor deje de reportarlo.

### 1.3 Regla general

No reportes como hecho nada que no puedas comprobar. Si dependés de una acción del
usuario, decí "pendiente de X" — no inventes su confirmación. Lo mismo para números:
un reporte anterior tuyo decía "11 infos, 0 errores" cuando `flutter analyze` tenía 13
errores de compilación en los tests.

---

## 2. LO QUE SÍ QUEDÓ BIEN (verificado)

- **A7 cerrado** — el lint `0028_anon_security_definer_function_executable` desapareció.
  Queda el `0029` (ejecutables por `authenticated`), que es **intencional** y está
  documentado en la migración: el leaderboard ahora solo responde a participantes o al
  dueño del reto. No lo "arregles".
- **A9 cerrado** — `0003_auth_rls_initplan` desapareció.
- **A15 cerrado** — `exercise_syncable.dart` existe y está registrado, `schemaVersion`
  en 12. El soft-delete en `deleteExercise` es la decisión correcta y por la razón
  correcta (mismo patrón que A25).
- **A16 rehecho** sin el `multiply`.
- **A25, A18, A23, pose** cerrados.
- `flutter analyze --no-pub` = 11 infos / 0 errores. `flutter test --no-pub` = **213
  verdes + 1 skip documentado**. Ambos confirmados de forma independiente.

---

## 3. QUÉ HACER AHORA

### 3.1 Pedile al usuario, explícitamente, estas tres cosas
En un solo mensaje, y **no marques ninguna como hecha hasta tener su respuesta**:

1. **Activar leaked-password protection** (A8): panel de Supabase → Authentication →
   Sign In / Providers → Password → *Prevent use of leaked passwords*. Después,
   confirmalo corriendo el advisor de seguridad, no con su palabra.
2. **Verificar A16 con los ojos**: abrir la lista de ejercicios y el entrenamiento
   activo, comparar contra `docs/auditoria/baseline/18-entrenamiento-activo.png`. Vos no
   podés correr la app; sin esa confirmación A16 no está cerrado.
3. **Confirmar A20**: hace falta una corrida real de CI en `windows-latest`. Si falla, el
   rollback es una línea en `.github/workflows/release.yml`.

### 3.2 Verificá que el sync realmente escribe
Es el único hallazgo grande de la auditoría que sigue sin evidencia: las 11 tablas
`nexfit_*` tenían **0 filas** con 1 usuario registrado, y nunca se comprobó un push
exitoso. Ahora que el esquema está alineado, es el momento.

Pedile al usuario que inicie sesión en la app, registre una serie y fuerce un sync. Después
comprobá con `execute_sql` que `nexfit_workout_sessions` y `nexfit_workout_sets` dejaron
de estar vacías. Si falla, el error queda en `SyncEngine.lastError` y se ve en Ajustes.

**Esto no lo puedas dar por hecho tampoco**: o ves las filas con una consulta, o no está
verificado.

### 3.3 No arranques nada nuevo
Con A15 cerrado, el alcance de Fases 2–6 está terminado salvo las confirmaciones de
arriba. **A6 (`pull` en `SyncableEntity`) sigue siendo P3 y fuera de alcance** — toca las
7 entidades de sync y necesita resolución de conflictos por `updatedAt`; es su propio
proyecto con su propio ADR.

Si el usuario quiere seguir, lo que queda en la auditoría original es: favoritos y
recientes en el picker, superseries en la UI, las fusiones de pantallas (Logros→Resumen,
Nutrición+Calculadora), responsive, y la arquitectura de assets en 3 capas. Ninguna es
urgente. Preguntá antes de empezar.

---

## 4. RECORDATORIOS VIGENTES

- Después de cada tarea: `flutter analyze --no-pub` (0 errores/warnings) →
  `flutter test --no-pub` (todos verdes). Leé la salida **completa** de analyze: los
  infos y los errores se mezclan en la misma lista y un "11 issues found" al pie puede
  esconder errores arriba.
- Antes de cada corrida de tests en Windows:
  `taskkill //F //IM flutter_tester.exe //IM dart.exe >/dev/null 2>&1; sleep 2`
  Y no uses `timeout` externo con `flutter test`: mata al padre, deja el hijo colgado y
  eso produce el lock del `sqlite3.dll`.
- **Nada de `git commit` / `git push` sin que te lo pidan.** Todo el trabajo de estas
  fases sigue sin commitear.
- Nada más sobre Supabase sin OK explícito escrito en el momento.
- No rediseñes visualmente: reusá los tokens de `lib/core/theme.dart`.
