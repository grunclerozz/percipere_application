import java.net.URI
import java.util.Base64

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Plain HTTP is allowed only to the host of an http:// web app address
// (`--dart-define=API_BASE_URL=http://192.168.1.61/...`, a PC on the same
// Wi-Fi) plus any hosts listed in `--dart-define=API_CLEARTEXT_HOSTS=a,b`.
// Every other host, and a build with an https:// server or none, keeps
// Android's default: no cleartext traffic. The app checks the same rule for
// its own requests (lib/core/network/api_dio.dart, lib/config/env.dart).
fun dartDefine(name: String): String =
    (project.findProperty("dart-defines") as String?)
        ?.split(",")
        ?.map { String(Base64.getDecoder().decode(it)) }
        ?.firstOrNull { it.startsWith("$name=") }
        ?.substringAfter("=")
        ?: ""

val cleartextHosts: List<String> = buildList {
    val uri = runCatching { URI(dartDefine("API_BASE_URL")) }.getOrNull()
    if (uri?.scheme == "http" && !uri.host.isNullOrBlank()) add(uri.host)
    addAll(dartDefine("API_CLEARTEXT_HOSTS").split(",").map { it.trim() })
}.filter { Regex("[A-Za-z0-9.-]+").matches(it) }.distinct()

// res/xml/network_security_config.xml, written for this build only.
val generatedNetworkConfig = layout.buildDirectory.dir("generated/networkSecurity").get().asFile
generatedNetworkConfig.resolve("xml").apply {
    mkdirs()
    resolve("network_security_config.xml").writeText(
        buildString {
            appendLine("<?xml version=\"1.0\" encoding=\"utf-8\"?>")
            appendLine("<network-security-config>")
            appendLine("    <base-config cleartextTrafficPermitted=\"false\" />")
            if (cleartextHosts.isNotEmpty()) {
                appendLine("    <domain-config cleartextTrafficPermitted=\"true\">")
                cleartextHosts.forEach {
                    appendLine("        <domain includeSubdomains=\"false\">$it</domain>")
                }
                appendLine("    </domain-config>")
            }
            appendLine("</network-security-config>")
        },
    )
}

android {
    namespace = "ph.bataan.percipere"
    compileSdk {
        version = release(37) { minorApiLevel = 0 }
    }
    ndkVersion = flutter.ndkVersion

    sourceSets.getByName("main").res.srcDir(generatedNetworkConfig)

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "ph.bataan.percipere.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
            // R8 (release shrinking): ML Kit text recognition mentions script
            // packs we do not ship; these rules silence that.
            proguardFiles("proguard-rules.pro")
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

dependencies {
    // ElevenLabs voice agent ("Percy", the voice assistant). Online only;
    // the app's own voice commands keep working without it.
    implementation("io.elevenlabs:elevenlabs-android:0.12.2")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.8.1")
}
