import org.gradle.api.initialization.resolve.RepositoriesMode

pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

/* ============================================================================
   CPAPorama (OPTIONNEL) - Repos pour DÉPENDANCES (implementation, etc.)
   - IMPORTANT: pluginManagement.repositories = plugins Gradle seulement
   - dependencyResolutionManagement.repositories = dépendances AndroidX / Maven
   - Si tu veux revenir en arrière: supprime ce bloc complet.
   ============================================================================
*/
//dependencyResolutionManagement {
//    /* ============================================================================
//       CPAPorama - Repos centralisés ici.
//       IMPORTANT: PREFER_SETTINGS = ignore les repos déclarés dans les build.gradle.
//       Pour revenir en arrière: remets FAIL_ON_PROJECT_REPOS (ou supprime la ligne).
//       ============================================================================ */
//    repositoriesMode.set(RepositoriesMode.PREFER_SETTINGS)
//
//    repositories {
//        google()
//        mavenCentral()
//    }
//}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.11.1" apply false
    id("org.jetbrains.kotlin.android") version "2.2.20" apply false
}

include(":app")



//pluginManagement {
//    val flutterSdkPath =
//        run {
//            val properties = java.util.Properties()
//            file("local.properties").inputStream().use { properties.load(it) }
//            val flutterSdkPath = properties.getProperty("flutter.sdk")
//            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
//            flutterSdkPath
//        }
//
//    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")
//
//    repositories {
//        google()
//        mavenCentral()
//        gradlePluginPortal()
//    }
//}
//
//plugins {
//    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
//    id("com.android.application") version "8.11.1" apply false
//    id("org.jetbrains.kotlin.android") version "2.2.20" apply false
//}
//
//include(":app")
