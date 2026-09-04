import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseSigning = keystorePropertiesFile.exists()
val isReleaseBuild = gradle.startParameter.taskNames.any {
    it.contains("Release", ignoreCase = true)
}

if (isReleaseBuild && !hasReleaseSigning) {
    error("Missing android/key.properties. Release signing is required for release builds.")
}

if (hasReleaseSigning) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.prothon.rizzguru"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
            storeFile = file(
                keystoreProperties.getProperty("storeFile")
                    ?: error("storeFile is missing")
            )

            storePassword = keystoreProperties.getProperty("storePassword")
                ?: error("storePassword is missing")

            keyAlias = keystoreProperties.getProperty("keyAlias")
                ?: error("keyAlias is missing")

            keyPassword = keystoreProperties.getProperty("keyPassword")
                ?: error("keyPassword is missing")
            }
        }
    }

    defaultConfig {
        applicationId = "com.prothon.rizzguru"
        minSdk = 21
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            if (hasReleaseSigning) {
                signingConfig = signingConfigs.getByName("release")
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
