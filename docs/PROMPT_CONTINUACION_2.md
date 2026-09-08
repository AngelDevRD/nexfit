# NEXFIT — Corrección de A16 y cierre

> Continúa `docs/PROMPT_CONTINUACION.md` y `docs/PROMPT_FASES_2-6.md`, que siguen
> vigentes para todo lo no dicho acá.

---

## Verificado de tu reporte

Corrí las dos comprobaciones: `flutter analyze --no-pub` = 11 infos / 0 errores, y
`flutter test --no-pub` = **208 verdes + 1 skip**. Los números dan. A2, A25, A18, A23 y
la eliminación de `features/pose/` están bien hechos.

---

## A16 está mal — hay que rehacerlo · **prioridad alta**

`BlendMode.multiply` **solo puede oscurecer**. Con `AppColors.surfaceContainerHigh`
(#1C212C), en `lib/widgets/exercise_thumb.dart` y
`lib/core/exercise_animation/widgets/exercise_animation_viewer.dart:78`:

- Fondo blanco del GIF → #1C212C. Eso era lo buscado, correcto.
- **Trazo negro del dibujo → sigue negro.** `multiply` con 0 da 0, siempre.

Contraste entre #000000 y #1C212C: **1,29:1**. El mínimo legible es 3:1. La figura del
ejercicio queda prácticamente invisible.

Es peor que el problema original: pasamos de "un rectángulo blanco que perfora el tema
oscuro" a "un rectángulo oscuro sin dibujo adentro" — justo en el widget que el usuario
mira para reconocer el ejercicio de un vistazo.

### Qué hacer

1. **Verificalo primero.** Corré la app y mirá la lista de ejercicios y el entrenamiento
   activo. Confirmá con los ojos lo que dice la matemática antes de tocar nada.
2. Elegí una de estas dos, **no dejes el `multiply`**:

   - **Opción recomendada — aceptar la media clara.** Quitá el `ColorFiltered` y en su
     lugar atenuá levemente el fondo blanco y dale borde/inset con
     `AppColors.outlineVariant`, para que lea como *imagen* y no como agujero. Es lo que
     hace la mayoría de las apps fitness en tema oscuro, no altera un solo píxel del
     dibujo, y respeta la regla de no rediseñar.
   - **Alternativa — invertir.** `ColorFilter.matrix` con diagonal negativa: el trazo
     negro pasa a blanco sobre fondo oscuro y se integra de verdad. Costo: los detalles
     rojos del dataset se vuelven cian. Solo si al verlo queda claramente mejor que la
     opción 1.

3. **Aplicá el mismo tratamiento en los dos archivos** (`ExerciseThumb` y
   `ExerciseAnimationViewer`), como ya venías haciendo. No pueden quedar con aspectos
   distintos del mismo GIF.
4. Compará el resultado contra `docs/auditoria/baseline/18-entrenamiento-activo.png`.

---

## Dos apuntes menores

- **El conteo de tests bajó de 216 a 208** porque borraste `rep_counter_test.dart` junto
  con `features/pose/`. Es correcto, pero dejalo **explícito** en el resumen final:
  alguien que solo mire los números va a leer una regresión de 8 tests.
- **A20 sigue abierto.** Falta la corrida real de CI en `windows-latest`. No lo marques
  como cerrado hasta que haya un build en verde; si falla, el rollback es una línea.

---

## Orden para lo que queda

Después de A16, y en este orden exacto:

1. **Pedí backup y OK explícito** al usuario (panel → Database → Backups). Recordá que la
   autorización para *aplicar* las migraciones **todavía no existe** — el "ok" previo era
   para escribirlas.
2. Aplicá `20260905_0002_alinear_esquema.sql`, después `20260905_0003_endurecer_rls.sql`.
3. Verificá con los advisors de Supabase que desaparecieron `0003_auth_rls_initplan` y
   `0028_anon_security_definer_function_executable`.
4. Pedile al usuario que active *Prevent use of leaked passwords* (Authentication →
   Sign In / Providers → Password). **A8 no es SQL, no podés hacerlo vos.**
5. **Recién ahí, A15** (`ExerciseSyncable`): depende de que exista
   `nexfit_custom_exercises`, que la crea la migración 0002.
6. **No mandes `routine_day_id`** desde el sync: la columna existe pero no se puede
   poblar. El motivo está documentado dentro de la propia migración.
