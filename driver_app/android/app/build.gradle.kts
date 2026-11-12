plugins {
    id("com.android.application")
    // Kotlin language support.
    id("org.jetbrains.kotlin.android")
    // Firebase: turns google-services.json into the generated resources.
    id("com.google.gms.google-services")

    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.sitirnati.driver"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.sitirnati.driver"

        minSdk = flutter.minSdkVersion
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        multiDexEnabled = true
    }

    signingConfigs {
        // The same key as the customer app, so the two APKs share one identity
        // and a driver can install an update over the previous build. Registered
        // only when the credentials are in the environment; without them the
        // build falls back to the debug key and still succeeds.
        if (System.getenv("KEYSTORE_PASSWORD") != null) {
            create("release") {
                storeFile = file("../../../keystore.jks")?.takeIf { it.exists() }
                storePassword = System.getenv("KEYSTORE_PASSWORD") ?: ""
                keyAlias = System.getenv("KEY_ALIAS") ?: ""
                keyPassword = System.getenv("KEY_PASSWORD") ?: ""
            }
        }
    }

    buildTypes {
        release {
            // Signed with the same keystore as the customer app when the
            // environment variables are present; debug keys otherwise so
            // `flutter build apk` keeps working on a bare machine.
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
