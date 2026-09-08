# Política de privacidad de NexFit

Última actualización: 2026-09-08. Versión de la app: 1.1.4.

Esta política describe nuestras prácticas de manejo de datos en NexFit. No es una
declaración de cumplimiento legal (RGPD, CCPA u otra norma): es una descripción en
lenguaje simple de qué datos recoge la app, dónde viven y qué hacés vos con ellos.

## Resumen rápido

- Tus datos de entrenamiento viven primero en tu teléfono. Una copia se sube a
  nuestro servidor (Supabase) para que no la pierdas si cambiás de dispositivo.
- **No hay analíticas, no hay publicidad y no hay rastreadores de terceros en la
  app.** No vendemos ni compartimos tus datos con nadie con fines comerciales.
- Los datos que lee de Health Connect (pasos, ritmo cardíaco, calorías, sueño)
  **nunca salen de tu teléfono**.
- Podés exportar todos tus datos o borrar tu cuenta por completo desde la propia
  app, en cualquier momento.

## 1. Qué datos recogemos

### 1.1 Perfil

Si completás tu perfil: nombre, edad, sexo, altura, peso, porcentaje de grasa
corporal, objetivo (por ejemplo "ganar músculo" o "bajar de grasa") y nivel de
experiencia. Todos estos campos son opcionales salvo el nombre.

### 1.2 Datos de entrenamiento

- **Rutinas**: nombre, objetivo, días por semana, y los ejercicios prescritos en
  cada día (series y repeticiones objetivo, peso objetivo, tempo, RPE/RIR
  objetivo, notas).
- **Entrenamientos y series**: fecha y hora de cada sesión, su nombre y notas, y
  cada serie que registrás (peso, repeticiones, RPE, RIR, descanso, si fue
  calentamiento, técnicas usadas como dropset o superset, notas).
- **Récords personales**: qué ejercicio, qué tipo de récord (peso o
  repeticiones) y cuándo lo lograste.
- **Objetivos**: título, métrica, valor inicial y objetivo, fecha objetivo.
- **Ejercicios propios**: si creás un ejercicio que no está en el catálogo,
  guardamos su nombre, grupo muscular, dificultad y detalle. El catálogo base de
  ejercicios (el que viene con la app) es el mismo para todos los usuarios y no
  es un dato tuyo.

### 1.3 Nutrición y recuperación

- **Nutrición**: calorías, proteínas, carbohidratos, grasas y agua que registrás
  por día, más notas opcionales.
- **Check-ins de recuperación**: horas de sueño y nivel de fatiga percibida que
  registrás por día.
- **Medidas corporales**: peso, porcentaje de grasa y las circunferencias
  corporales que cargues (cuello, hombros, pecho, bíceps, antebrazo, abdomen,
  cintura, cadera, muslo, pantorrilla). Estas medidas hoy quedan solo en tu
  teléfono, no se suben a la nube.

### 1.4 Datos técnicos internos

La app guarda algunos datos operativos que no son de negocio pero hacen falta
para que funcione sin conexión: un borrador del entrenamiento en curso (para
poder cerrar la app a mitad de una serie sin perderla) y una cola interna de
cambios pendientes de subir. Ninguno de estos dos se sincroniza con la nube tal
cual: se usan y se descartan localmente.

### 1.5 Health Connect (Android) / datos de wearables

Si le das permiso, la app **lee** de Health Connect: pasos, ritmo cardíaco,
calorías activas quemadas y horas de sueño. Es una lectura de **solo lectura**:
la app nunca escribe en Health Connect. Estos datos se muestran en la pantalla
"Wearables" y **no se guardan en ninguna base de datos, ni local ni remota, ni
se envían a ningún servidor**: se leen, se muestran, y se descartan al cerrar la
pantalla.

### 1.6 Coach IA (opcional)

Si abrís el chat del Coach IA y le escribís, la app arma un resumen de tu
actividad y lo envía a **Groq** (proveedor de inferencia de IA con sede en
Estados Unidos) para generar la respuesta. Ese resumen incluye: tu nombre, edad,
sexo, altura, peso y porcentaje de grasa si los cargaste; tu objetivo y nivel de
experiencia; tus objetivos activos; tu índice de recuperación más reciente (si
tenés un check-in cargado); tu volumen de entrenamiento semanal y tus rachas;
tus entrenamientos y récords personales recientes; tu nivel y logros de
gamificación. El tratamiento que Groq haga de estos datos se rige por sus
propios términos de servicio; consultalos en groq.com.

El Coach IA es **opcional en el sentido más literal**: no se activa solo. Se
envía información únicamente cuando vos abrís esa pantalla y escribís un
mensaje. Si nunca usás el Coach, nunca se manda nada a Groq. Además, la tarjeta
del Coach ni siquiera aparece si el servidor que la sostiene no está configurado
en tu versión de la app.

### 1.7 Tipografía

La app descarga la tipografía "Inter" desde los servidores de Google
(`fonts.gstatic.com`) la primera vez que la usás en un dispositivo, a través del
paquete `google_fonts`. Es una descarga de un archivo de fuente, no un envío de
tus datos: Google puede ver que un dispositivo pidió esa fuente (como pasaría
con cualquier request HTTP), pero no le llega ningún dato tuyo de la app.

## 2. Dónde viven tus datos

- **En tu teléfono**: una base de datos SQLite local es la fuente de verdad de
  todo lo que registrás. La app funciona sin conexión; todo se guarda ahí
  primero.
- **En la nube**: una copia de tus rutinas, entrenamientos, series, objetivos,
  perfil, nutrición, check-ins de recuperación y ejercicios propios se sube a
  **Supabase**, alojado en la región **us-west-2 (Oregón, Estados Unidos)**.
  Esto significa que tus datos salen de tu país si no estás en Estados Unidos.
  Esa copia existe para que no pierdas tu historial si cambiás de teléfono o
  reinstalás la app (hoy la restauración automática todavía no está
  implementada: para recuperar tu historial en un dispositivo nuevo usá
  "Exportar datos" en el anterior e "Importar datos" en el nuevo).
- Cada usuario solo puede ver y modificar sus propios datos en Supabase: la base
  tiene seguridad a nivel de fila (RLS) activa en las 12 tablas, sin excepción.

## 3. Qué NO hacemos

Lo siguiente lo verificamos revisando el código de la app antes de escribirlo
acá, no es una promesa genérica:

- No hay ningún SDK de analíticas (Firebase Analytics, Amplitude, Mixpanel, ni
  ningún otro) integrado en la app.
- No hay ningún SDK de publicidad (AdMob u otro).
- No hay rastreadores de terceros de ningún tipo.
- No vendemos tus datos ni los compartimos con terceros con fines comerciales o
  publicitarios.
- No leemos tu ubicación.

## 4. Tus derechos

- **Acceso y exportación**: desde Ajustes → "Exportar datos" podés descargar
  todas tus rutinas, entrenamientos, nutrición, check-ins y metas en un archivo
  que podés guardar o llevarte a otra app.
- **Borrado**: desde Ajustes → Cuenta → "Eliminar mi cuenta" podés borrar tu
  cuenta y todos tus datos, tanto los del teléfono como los de la nube, de
  forma permanente e inmediata. También podés pedirlo sin abrir la app —
  ver <URL_BORRADO_DE_CUENTA> o escribir a angeldnielgs@gmail.com.
- **Corrección**: todos los datos de perfil, rutinas, entrenamientos, etc. se
  editan directamente desde la app en el momento que quieras.

## 5. Menores de edad

NexFit no está dirigida a menores de 13 años. Ver los Términos de uso
(`docs/legal/TERMINOS.md`) para la edad mínima aplicable.

## 6. Cambios a esta política

Si cambiamos qué datos recogemos o cómo los usamos, vamos a actualizar este
documento y la fecha de "Última actualización" de arriba.

## 7. Contacto

Para cualquier consulta sobre privacidad, borrado de datos, o esta política:
**angeldnielgs@gmail.com**.
