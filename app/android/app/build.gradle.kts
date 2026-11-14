import java.util.Base64
import java.util.Properties

// Assinatura de release: lida de android/key.properties (NUNCA versionado; ver
// docs/PLAY_STORE.md). Sem o arquivo, o build release cai na chave de debug para
// que `flutter run --release` continue funcionando em desenvolvimento.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}
plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Detecção determinística Dual-APK (Público vs. Founder Sovereign Cockpit CEO):
// Ativada tanto por `-PfounderApp=true` quanto pelo fallback Base64 de `dart-defines`
// (`--dart-define=FOUNDER_APP=true`), garantindo isolamento side-by-side sem colisão.
val isFounderBuild: Boolean = (
    project.hasProperty("founderApp") &&
        project.property("founderApp").toString().toBoolean()
) || (
    project.hasProperty("dart-defines") &&
        project.property("dart-defines")
            .toString()
            .split(",")
            .filter { it.isNotBlank() }
            .any { encoded ->
                val decoded = runCatching {
                    String(Base64.getDecoder().decode(encoded.trim()), Charsets.UTF_8)
                }.getOrElse {
                    runCatching {
                        String(Base64.getUrlDecoder().decode(encoded.trim()), Charsets.UTF_8)
                    }.getOrDefault("")
                }
                decoded.equals("FOUNDER_APP=true", ignoreCase = true)
            }
)

android {
    namespace = "br.com.desperrengue.app"
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "br.com.desperrengue.app"
        if (isFounderBuild) {
            applicationIdSuffix = ".founder"
            manifestPlaceholders["appLabel"] = "Desperrengue CEO"
            manifestPlaceholders["authScheme"] = "br.com.desperrengue.app.founder"
            manifestPlaceholders["onboardingScheme"] = "desperrengue-founder"
        } else {
            manifestPlaceholders["appLabel"] = "Desperrengue"
            manifestPlaceholders["authScheme"] = "br.com.desperrengue.app"
            manifestPlaceholders["onboardingScheme"] = "desperrengue"
        }
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
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