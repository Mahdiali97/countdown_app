plugins {
    id("com.android.application")
    id("kotlin-android")
    id("com.google.gms.google-services") // for Firebase
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.countdown_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    defaultConfig {
        applicationId = "com.example.countdown_app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Use this only if needed, and update MainActivity.kt accordingly
        // manifestPlaceholders["applicationName"] = "io.flutter.app.FlutterApplication"
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation(platform("com.google.firebase:firebase-bom:33.16.0"))
    implementation("com.google.firebase:firebase-firestore-ktx")

    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}
