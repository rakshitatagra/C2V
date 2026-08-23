buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        // Bridge for Android Gradle Plugin, Firebase, and Kotlin
        classpath("com.android.tools.build:gradle:8.2.1")
        classpath("com.google.gms:google-services:4.4.0")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:1.9.22")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// We have removed the 'val rootBuildDir' block to ensure the APK 
// goes to the default location where Flutter expects it.

subprojects {
    evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}