plugins {
    id("com.android.application")
    kotlin("android")
    id("org.jetbrains.kotlin.android") version "1.9.0"
}

android {
    namespace = "com.chronicle.android"
    compileSdk = 34

    defaultConfig {
        applicationId = "com.chronicle.android"
        minSdk = 26
        targetSdk = 34
    }
}
