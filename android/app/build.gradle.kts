plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    // --- KÍCH HOẠT PLUGIN FIREBASE ---
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.splendor_fake"
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
        applicationId = "com.example.splendor_fake"
        
        // --- SỬA MIN SDK LÊN 23 (Firebase yêu cầu tối thiểu 21 hoặc 23) ---
        minSdk = flutter.minSdkVersion 
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
