plugins {
    id("com.android.application")
    // Kotlin language support.
    id("org.jetbrains.kotlin.android")

    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.sitirnati.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.sitirnati.app"

        minSdk = flutter.minSdkVersion
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        multiDexEnabled = true
    }

    signingConfigs {
        // Same scheme as deliv_driver: keystore.jks at the project root,
        // credentials from environment variables. Registered only when the
        // variables are present so builds without them still succeed.
        if (System.getenv("KEYSTORE_PASSWORD") != null) {
            create("release") {
                storeFile = file("../../keystore.jks")?.takeIf { it.exists() }
                storePassword = System.getenv("KEYSTORE_PASSWORD") ?: ""
                keyAlias = System.getenv("KEY_ALIAS") ?: ""
                keyPassword = System.getenv("KEY_PASSWORD") ?: ""
            }
        }
    }

    buildTypes {
        release {
            // Signs with keystore.jks when KEYSTORE_PASSWORD / KEY_ALIAS /
            // KEY_PASSWORD are set; otherwise falls back to debug keys so
            // `flutter build apk` keeps working.
            signingConfig = if (System.getenv("KEYSTORE_PASSWORD") != null) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = false
            isShrinkResources = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
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
