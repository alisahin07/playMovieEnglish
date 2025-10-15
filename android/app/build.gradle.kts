plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.alibayoglu.leitner_player"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    defaultConfig {
        applicationId = "com.alibayoglu.leitner_player"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Java 17 + core library desugaring
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    buildTypes {
        release {
            // Prod’da kendi imzanı kullan; şimdilik debug anahtarıyla imzalanıyor
            signingConfig = signingConfigs.getByName("debug")
            // İstersen shrinker/R8:
            // isMinifyEnabled = true
            // proguardFiles(
            //     getDefaultProguardFile("proguard-android-optimize.txt"),
            //     "proguard-rules.pro"
            // )
        }
        debug {
            // Gerekirse debug’a özel ayarlar
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Core library desugaring (Java 8+ API’leri için gerekli)
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    // Diğer bağımlılıklar (Flutter pluginleri) Flutter tarafından eklenir
}
