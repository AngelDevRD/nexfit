# appgym (NexFit)

## Desarrollo local

Las credenciales (`SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SMART_BACKEND_URL` del
Coach IA) se pasan con `--dart-define-from-file`, no con `--dart-define` suelto
por línea de comandos. Pasarlas por CLI es frágil -- en Windows PowerShell una
key larga pegada en la consola puede llegar con caracteres de máscara
literales (`•••`) si se copia desde una salida ya enmascarada, y el fallo
resultante (`FormatException: Invalid HTTP header field value`) no es obvio
de diagnosticar.

1. Creá `env.json` en la raíz del proyecto (ya está en `.gitignore`, nunca se
   commitea):
   ```json
   {
     "SUPABASE_URL": "https://tu-proyecto.supabase.co",
     "SUPABASE_ANON_KEY": "tu-anon-key",
     "SMART_BACKEND_URL": "http://localhost:8000"
   }
   ```
   `SUPABASE_URL`/`SUPABASE_ANON_KEY` salen del panel de Supabase (Settings →
   API) -- pegalas ahí directo, no por terminal. `SMART_BACKEND_URL` solo hace
   falta para probar el Coach IA contra un backend local (ver
   `backend_ia/README.md`).

2. Corré la app apuntando a ese archivo:
   ```bash
   flutter run --dart-define-from-file=env.json
   ```

En CI (`.github/workflows/release.yml`) las mismas variables salen de GitHub
Secrets, no de `env.json`.

## Firma de release

El build `release` de Android (`android/app/build.gradle.kts`) exige
`android/key.properties` -- si falta, el build falla con un mensaje explícito
en vez de firmar con la clave de debug. Ese archivo nunca se commitea (está en
`.gitignore`).

1. Generar el keystore (una sola vez, guardalo fuera del repo):
   ```bash
   keytool -genkey -v -keystore nexfit-release.jks -keyalg RSA -keysize 2048 \
     -validity 10000 -alias nexfit
   ```
2. Crear `android/key.properties` en tu máquina:
   ```properties
   storePassword=<password del keystore>
   keyPassword=<password de la key>
   keyAlias=nexfit
   storeFile=/ruta/absoluta/a/nexfit-release.jks
   ```

### Cargarlo en CI (GitHub Actions)

El runner no tiene el keystore, hay que restaurarlo desde un secret antes de
compilar:

1. Codificar el `.jks` en base64 y guardarlo como secret (por ejemplo
   `ANDROID_KEYSTORE_BASE64`), junto con `ANDROID_KEYSTORE_PASSWORD`,
   `ANDROID_KEY_PASSWORD` y `ANDROID_KEY_ALIAS`:
   ```bash
   base64 -w0 nexfit-release.jks > keystore.b64
   ```
2. En el job, antes del build, decodificar el secret y generar
   `android/key.properties`:
   ```yaml
   - name: Restaurar keystore de release
     run: |
       echo "${{ secrets.ANDROID_KEYSTORE_BASE64 }}" | base64 -d > android/app/nexfit-release.jks
       cat > android/key.properties <<EOF
       storePassword=${{ secrets.ANDROID_KEYSTORE_PASSWORD }}
       keyPassword=${{ secrets.ANDROID_KEY_PASSWORD }}
       keyAlias=${{ secrets.ANDROID_KEY_ALIAS }}
       storeFile=nexfit-release.jks
       EOF
   ```

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
