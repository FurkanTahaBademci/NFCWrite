import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release imzalama anahtari. `android/key.properties` surum kontrolunde
// DEGILDIR (bkz. android/.gitignore) ve keystore depo disinda durur.
//
// Dosya yoksa release yapisi debug anahtarina duser: baska bir makinede
// ya da CI'da `flutter build` yine calisir, ama urettigi APK **dagitilamaz**
// - imzasi yayinlanan surumlerle uyusmaz ve guncelleme olarak kurulmaz.
// Dagitilacak APK yalnizca anahtarin bulundugu makinede uretilir.
val keystoreProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) {
        file.inputStream().use { load(it) }
    }
}
val hasReleaseKeystore = keystoreProperties.getProperty("storeFile") != null

android {
    namespace = "com.furkan.nfc_toolkit"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.furkan.nfc_toolkit"

        // NFC Reader Mode (enableReaderMode) API 19'da geldi, ancak
        // nfc_manager ve modern Flutter icin 23 taban aliniyor.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                // Anahtar yok - yerel `flutter run --release` calissin diye
                // debug anahtari. Bu APK dagitilamaz.
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
