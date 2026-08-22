plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.kukku.music.kukku"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.kukku.music.kukku"
        // audio_service / just_audio (Media3) both require API 21+; Flutter's
        // current floor is 24.
        minSdk = flutter.minSdkVersion
        // Was pinned to 34, which opted the app out of the Android 15+
        // edge-to-edge behaviour the UI now relies on. Track Flutter's default
        // (36) instead of hardcoding a version that goes stale.
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: replace with a real upload keystore before publishing.
            // Signing with the debug keys for now, so `flutter build --release`
            // and `flutter run --release` work out of the box.
            signingConfig = signingConfigs.getByName("debug")

            // R8 was never configured, so release builds shipped unshrunk and
            // unobfuscated. proguard-rules.pro keeps the media classes that the
            // platform instantiates reflectively.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
        debug {
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }

    packaging {
        resources {
            // Duplicate metadata from the Media3 / Kotlin artifacts.
            excludes += setOf(
                "META-INF/DEPENDENCIES",
                "META-INF/LICENSE*",
                "META-INF/NOTICE*",
                "META-INF/*.kotlin_module",
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
