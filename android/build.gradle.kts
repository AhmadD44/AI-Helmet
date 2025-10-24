// 🧹 No plugin versions here — this avoids the version conflict!
plugins {
    id("com.android.application") apply false
    id("org.jetbrains.kotlin.android") apply false
}

// Repositories for all subprojects
allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Optional: custom Flutter build directory
val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

// ✅ Add this block to *force* Gradle to use 4.3.15, matching what Flutter already brings.
buildscript {
    dependencies {
        classpath("com.google.gms:google-services:4.3.15")
    }
}
