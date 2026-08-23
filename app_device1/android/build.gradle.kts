buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        // Bridge for Android Gradle Plugin and Firebase
        classpath("com.android.tools.build:gradle:8.2.1")
        classpath("com.google.gms:google-services:4.4.0")
        // Added to ensure Kotlin is handled correctly across all plugins
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:1.9.22")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// We removed the custom 'val rootBuildDir' logic to allow Flutter 
// to find the APK in the standard location.

subprojects {
    evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}