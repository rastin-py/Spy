import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Signing details live outside the repository. `android/key.properties` is
// gitignored; see key.properties.example for the four lines it needs. When it
// is absent - a fresh clone, or CI that only builds debug - release falls back
// to the debug key so `flutter run --release` still works locally.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        load(FileInputStream(keystorePropertiesFile))
    }
}
val hasReleaseKey = keystorePropertiesFile.exists()

// Third-party keys, same treatment as the signing key: outside the repository,
// supplied at build time. `android/keys.properties` is gitignored; see
// keys.properties.example. Missing means the feature is simply off - a blank
// Tapsell key leaves the SDK inert, which is exactly what a build with no
// adverts should do.
val serviceKeysFile = rootProject.file("keys.properties")
val serviceKeys = Properties().apply {
    if (serviceKeysFile.exists()) {
        load(FileInputStream(serviceKeysFile))
    }
}

android {
    namespace = "ir.topazapps.spy"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Topaz Apps, reverse-DNS against topazapps.ir. Fixed forever: an
        // application id cannot be changed once a listing exists - it is the
        // app's identity on the store, in the update deep link, and on every
        // receipt Bazaar issues.
        applicationId = "ir.topazapps.spy"

        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Tapsell reads its key from the manifest and initialises itself; there
        // is no Dart-side init call. Blank is safe: the SDK stays inert.
        manifestPlaceholders["TapsellMediationAppKey"] =
            (serviceKeys["tapsellAppKey"] as String?) ?: ""
    }

    signingConfigs {
        create("release") {
            if (hasReleaseKey) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseKey) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }

    lint {
        // `lintVitalAnalyzeRelease` downloads `com.android.tools.lint:lint-gradle`
        // from Google's Maven, which is unreachable from this network - a release
        // build fails on the download rather than on anything about the code.
        // Correctness is covered by `flutter analyze` and 130 tests; this only
        // switches off the Gradle-side lint that cannot run here anyway.
        checkReleaseBuilds = false
        abortOnError = false
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
