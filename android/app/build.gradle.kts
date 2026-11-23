import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    FileInputStream(keystorePropertiesFile).use { keystoreProperties.load(it) }
}

val envStoreFile = System.getenv("ANDROID_KEYSTORE_PATH")
val resolvedStoreFilePath =
    keystoreProperties.getProperty("storeFile")?.takeIf { it.isNotBlank() }
        ?: envStoreFile?.takeIf { it.isNotBlank() }
val resolvedStorePassword =
    keystoreProperties.getProperty("storePassword")?.takeIf { it.isNotBlank() }
        ?: System.getenv("ANDROID_KEYSTORE_PASSWORD")
val resolvedKeyAlias =
    keystoreProperties.getProperty("keyAlias")?.takeIf { it.isNotBlank() }
        ?: System.getenv("ANDROID_KEY_ALIAS")
val resolvedKeyPassword =
    keystoreProperties.getProperty("keyPassword")?.takeIf { it.isNotBlank() }
        ?: System.getenv("ANDROID_KEY_PASSWORD")

val hasReleaseSigning =
    !resolvedStoreFilePath.isNullOrBlank() &&
        !resolvedStorePassword.isNullOrBlank() &&
        !resolvedKeyAlias.isNullOrBlank() &&
        !resolvedKeyPassword.isNullOrBlank() &&
        rootProject.file(resolvedStoreFilePath).exists()

android {
    namespace = "ph.gov.gasan.gtrams.gtrams_mobile"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "ph.gov.gasan.gtrams.gtrams_mobile"
        minSdk = maxOf(flutter.minSdkVersion, 24)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = rootProject.file(resolvedStoreFilePath!!)
                storePassword = resolvedStorePassword
                keyAlias = resolvedKeyAlias
                keyPassword = resolvedKeyPassword
                enableV1Signing = true
                enableV2Signing = true
            }
        }
    }

    buildTypes {
        release {
            // Uses production upload keystore when android/key.properties or CI secrets are configured;
            // falls back to debug keystore for unsigned PR verification builds.
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

flutter {
    source = "../.."
}
