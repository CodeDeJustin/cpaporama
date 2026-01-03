allprojects {
    repositories {
        google()
        mavenCentral()

        /* ============================================================================
           CPAPorama (TEMP) - Repo Maven Flutter (io.flutter:* debug/profile/release)
           - Fix: Could not find io.flutter:x86_64_debug / flutter_embedding_debug
           - Rollback: supprime juste ce bloc maven { ... }
           ============================================================================
        */
        maven { url = uri("https://storage.googleapis.com/download.flutter.io") }
    }
}

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
