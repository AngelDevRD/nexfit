import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Carga las credenciales de firma desde android/key.properties (fuera de git).
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.angeldevrd.nexfit"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.angeldevrd.nexfit"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // Health Connect (paquete `health`) requiere minSdk 26.
        minSdk = maxOf(26, flutter.minSdkVersion)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Solo arm64-v8a: es lo que usan los telefonos reales. Excluye las libs
    // nativas de x86_64/armeabi-v7a (flutter_3d_controller las trae para todas
    // las ABIs y --target-platform no las filtra), asi el APK baja de ~62MB a
    // ~46MB y entra en el limite de 50MB de Telegram.
    packaging {
        jniLibs {
            excludes += listOf(
                "lib/x86_64/**",
                "lib/x86/**",
                "lib/armeabi-v7a/**",
            )
        }
    }

    signingConfigs {
        create("release") {
            val hasKeystore = keystorePropertiesFile.exists()
            if (hasKeystore) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

// Sin key.properties no hay build de release: evita que un APK quede firmado
// con la clave de debug sin que nadie lo note. Chequeo en `doFirst` (fase de
// EJECUCION), no en el cuerpo de `buildTypes` (fase de CONFIGURACION, que
// Gradle evalua en toda invocacion, incluido `assembleDebug`) -- si no, un
// build de debug sin key.properties tambien fallaba.
tasks.matching { it.name.contains("Release") }.configureEach {
    doFirst {
        if (!keystorePropertiesFile.exists()) {
            throw GradleException(
                "Falta android/key.properties: no se puede firmar el build de " +
                    "release. Genera el keystore y crea key.properties " +
                    "(ver README.md, seccion 'Firma de release'), o en CI " +
                    "restaura el secret correspondiente antes de compilar."
            )
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
