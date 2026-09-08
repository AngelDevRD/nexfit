# Borrador para Play Console — Data safety y apps de salud

Este documento tiene las respuestas ya redactadas para copiar directo en Play
Console. Nada de esto se envió a Google -- lo aplica el usuario a mano en la
ficha de la app.

Fuente de este borrador: el inventario real de `docs/legal/PRIVACIDAD.md`,
verificado contra el código (`lib/core/local/database.dart`,
`lib/models/profile.dart`, `lib/models/coach_context.dart`,
`lib/services/health_service.dart`).

---

## 1. Formulario "Data safety" (App content → Data safety)

### 1.1 ¿La app recoge o comparte alguno de los tipos de datos requeridos?

**Sí.**

### 1.2 ¿Toda la información se transmite cifrada en tránsito?

**Sí.** Supabase (HTTPS/TLS) y la API de Groq (HTTPS/TLS) son los dos únicos
destinos de red que reciben datos del usuario, ambos por HTTPS.

### 1.3 ¿La app ofrece una forma de pedir el borrado de los datos?

**Sí.** In-app (Ajustes → Cuenta → Eliminar mi cuenta) y por la web
(<URL_BORRADO_DE_CUENTA>, ver `docs/legal/borrado-de-cuenta.html`).

### 1.4 Tabla de categorías de datos

| Categoría (Play) | Dato concreto | ¿Se recoge? | ¿Se comparte con terceros? | ¿Procesamiento efímero? | ¿Opcional? | Finalidad declarada |
|---|---|---|---|---|---|---|
| Personal info → Name | Nombre de perfil | Sí | No | No | Sí (el nombre es el único campo no opcional del perfil, pero completar el perfil en sí es opcional) | Funcionalidad de la app (personalización, Coach IA) |
| Personal info → Email address | Email de la cuenta (Supabase Auth) | Sí | No | No | No (requerido para crear cuenta) | Gestión de cuenta |
| Personal info → Other info | Edad, sexo, altura, peso, % grasa corporal, objetivo, nivel de experiencia | Sí | No | No | Sí | Funcionalidad de la app (cálculos, Coach IA) |
| Health and fitness → Fitness info | Rutinas, entrenamientos, series, récords personales, objetivos, nutrición, check-ins de recuperación, medidas corporales, ejercicios propios | Sí | No | No | Sí (usar la app sin cargar nada es posible, pero esa es la función principal) | Funcionalidad de la app |
| Health and fitness → Health info | Pasos, ritmo cardíaco, calorías activas y sueño leídos de Health Connect | Sí | No | **Sí** — se lee, se muestra y se descarta; no se guarda en ninguna base local ni remota | Sí (requiere permiso explícito de Health Connect) | Funcionalidad de la app (pantalla "Wearables") |
| Messages → In-app messages | Texto que el usuario escribe en el chat del Coach IA | No se persiste (vive solo en memoria mientras la pantalla está abierta) | Sí — se envía a Groq (proveedor de IA, EE. UU.) para generar la respuesta, solo cuando el usuario usa el Coach | No (el mensaje se procesa por el proveedor de IA para responder, no es puramente efímero de este lado) | Sí (el Coach IA es 100 % opcional) | Funcionalidad de la app (Coach IA) |
| App activity / App info and performance | — | **No se recoge** | — | — | — | No aplica: no hay SDK de analíticas ni de rendimiento integrado (verificado por grep en pubspec.yaml y en el código) |
| Financial info | — | No se recoge | — | — | — | No aplica |
| Location | — | No se recoge | — | — | — | No aplica |
| Photos and videos | — | No se recoge | — | — | — | No aplica |
| Device or other identifiers | — | No se recoge explícitamente por la app (ningún SDK de tracking) | — | — | — | No aplica |

**Nota sobre "compartir" en el sentido de Play**: Play considera "compartir"
el envío de datos a un tercero que no sea un mero procesador de la app. El
resumen que se manda al Coach IA (nombre, edad, sexo, altura, peso, %grasa,
objetivo, nivel, objetivos activos, recuperación, volumen semanal, racha,
entrenamientos y récords recientes, nivel y logros — ver el detalle completo
en `lib/models/coach_context.dart` y `docs/legal/PRIVACIDAD.md` §1.6) se envía
a **Groq** como proveedor de inferencia de IA. Si Play te pide declarar esto
como "compartido con terceros" en vez de "procesado por un proveedor de
servicio", marcalo así para la fila de Fitness info y Personal info que via­
jan en ese resumen -- Play es estricto con esta distinción y conviene
declarar de más antes que de menos. <PENDIENTE: decisión del usuario sobre
cómo clasificar exactamente esta fila, según la lectura que Play haga de los
términos de servicio de Groq>.

### 1.5 Seguridad de los datos

- Cifrado en tránsito: sí (HTTPS/TLS con Supabase y con Groq).
- Cifrado en reposo: Supabase cifra en reposo por defecto (Postgres gestionado);
  la base local SQLite del teléfono no está cifrada por la app (usa el
  almacenamiento privado de la app en Android, protegido por el sandbox del
  sistema operativo, pero no hay cifrado adicional a nivel de archivo).
  <PENDIENTE: si Play pide una confirmación explícita de cifrado en reposo del
  lado del cliente, hoy la respuesta real es "no", no inventar que sí>.
- El usuario puede pedir el borrado de sus datos: sí (ver 1.3).
- Los datos siguen las Play Families Policy (si aplica): no aplica, la app no
  está dirigida a niños (ver edad mínima en `docs/legal/TERMINOS.md`).

---

## 2. Declaración de apps de salud (Health Connect permissions declaration)

Desde enero 2026, Play exige justificar **cada** permiso de Health Connect
individualmente, con una función real y verificable que lo use. Los 4 permisos
que quedan en `android/app/src/main/AndroidManifest.xml` después de la limpieza
de la Fase 0 (se sacó `READ_TOTAL_CALORIES_BURNED`, que no se usaba):

| Permiso | ¿Se usa hoy? | Función que lo justifica |
|---|---|---|
| `android.permission.health.READ_STEPS` | Sí | `HealthService.fetchToday()` lee el total de pasos del día y `WearablesScreen` los muestra en la tarjeta "Pasos". |
| `android.permission.health.READ_HEART_RATE` | Sí | `HealthService.fetchToday()` lee las mediciones de ritmo cardíaco del día y calcula el promedio; `WearablesScreen` lo muestra en "Pulso promedio". |
| `android.permission.health.READ_ACTIVE_CALORIES_BURNED` | Sí | `HealthService.fetchToday()` lee las calorías activas quemadas del día; `WearablesScreen` las muestra en "Calorías activas". |
| `android.permission.health.READ_SLEEP` | Sí | `HealthService.fetchToday()` lee las sesiones de sueño desde las 18:00 del día anterior y suma los minutos dormidos; `WearablesScreen` lo muestra en "Sueño". |

**Los 4 tienen una función real y verificable hoy** (los 4 se leen en
`HealthService.fetchToday()` y los 4 se muestran en la pantalla "Wearables",
confirmado leyendo `lib/services/health_service.dart` y
`lib/screens/wearables/wearables_screen.dart`). No hay ningún permiso de
Health Connect declarado en el manifest que no tenga una función que lo use --
si en el futuro se agrega o quita un tipo de dato leído, hay que actualizar
esta tabla y el manifest a la vez.

Texto sugerido para el campo de justificación de Play (uno por permiso, se
puede adaptar):

> "NexFit lee [pasos / ritmo cardíaco / calorías activas / horas de sueño] de
> Health Connect, solo lectura, para mostrárselos al usuario en la pantalla
> 'Wearables' de la app como parte de su seguimiento diario de actividad. Este
> dato no se almacena ni se transmite a ningún servidor: se lee, se muestra y
> se descarta."

---

## 3. Placeholders pendientes en este documento

- `<URL_BORRADO_DE_CUENTA>` — reemplazar una vez publicada
  `docs/legal/borrado-de-cuenta.html` (ver `docs/legal/README.md`).
- La nota de la sección 1.4 sobre cómo clasificar el envío al Coach IA
  ("compartido" vs "procesado por proveedor") — depende de cómo lea Play los
  términos de servicio de Groq vigentes al momento de publicar; no es una
  decisión técnica que se pueda resolver desde el código.
- La pregunta de cifrado en reposo del lado del cliente (sección 1.5) — hoy es
  "no", queda marcado así a propósito en vez de inventar que sí.
