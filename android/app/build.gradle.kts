import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Firma de release: lee android/key.properties (nunca commiteado, ver .gitignore).
// Generarlo con:
//   keytool -genkey -v -keystore <ruta>/gdm-release.jks -keyalg RSA -keysize 2048 \
//     -validity 10000 -alias gdm
// y crear android/key.properties con:
//   storePassword=...
//   keyPassword=...
//   keyAlias=gdm
//   storeFile=<ruta absoluta o relativa a android/ del .jks>
val keystorePropertiesFile = rootProject.file("key.properties")
val hasKeystoreProperties = keystorePropertiesFile.exists()
val keystoreProperties = Properties().apply {
    if (hasKeystoreProperties) load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.gdm.gdm_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Requerido por flutter_local_notifications (usa APIs de java.time via
        // desugaring en minSdk bajos) — spec 16.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.gdm.gdm_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasKeystoreProperties) {
            create("release") {
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Usa la firma de release si existe android/key.properties; si no
            // (dev sin keystore todavía), cae a las debug keys para que
            // `flutter run --release` / `flutter build apk --release` sigan
            // funcionando mientras se genera el keystore (ver comentario arriba).
            signingConfig = if (hasKeystoreProperties) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
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

dependencies {
    // Desugaring de java.time para flutter_local_notifications (spec 16).
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
