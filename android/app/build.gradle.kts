import java.util.Properties
import java.util.Base64
import java.net.URI

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

if (file("google-services.json").isFile) {
    apply(plugin = "com.google.gms.google-services")
}

val signingProperties = Properties()
val signingFile = rootProject.file(
    providers.environmentVariable("INKURI_SIGNING_PROPERTIES").orElse("key.properties").get()
)
if (signingFile.exists()) signingFile.inputStream().use { signingProperties.load(it) }
val isRelease = gradle.startParameter.taskNames.any { it.contains("release", ignoreCase = true) }
val dartDefines = (findProperty("dart-defines") as? String)
    .orEmpty()
    .split(',')
    .filter { it.isNotEmpty() }
    .map { String(Base64.getDecoder().decode(it), Charsets.UTF_8).split('=', limit = 2) }
    .filter { it.size == 2 }
    .associate { it[0] to it[1] }
val productionMonetization = dartDefines["INKURI_MONETIZATION_PRODUCTION"] == "true"
val demoPublisher = "ca-app-pub-3940256099942544"
val demoAdsAppId = "$demoPublisher~3347511713"
val adsAppId = if (productionMonetization) {
    dartDefines["INKURI_ADMOB_APP_ID"].orEmpty()
} else {
    demoAdsAppId
}
if (productionMonetization) {
    require(isRelease && file("google-services.json").isFile) {
        "Production monetization requires a release build and the Android Firebase configuration."
    }
    val units = listOf("HOME_BANNER", "HISTORY_BANNER", "RESULT_BANNER", "REWARDED")
        .map { dartDefines["INKURI_ADMOB_$it"].orEmpty() }
    require(Regex("ca-app-pub-[0-9]+~[0-9]+").matches(adsAppId) &&
        !adsAppId.startsWith(demoPublisher) &&
        units.distinct().size == 4 &&
        units.all { Regex("ca-app-pub-[0-9]+/[0-9]+").matches(it) &&
            it.substringBefore('/') == adsAppId.substringBefore('~') }) {
        "Production monetization requires a real AdMob app ID and four distinct ad units from that publisher."
    }
    val endpoint = runCatching {
        URI(dartDefines["INKURI_PLAY_VERIFY_URL"].orEmpty())
    }.getOrNull()
    require(endpoint?.scheme == "https" && !endpoint.host.isNullOrBlank() &&
        endpoint.userInfo == null && endpoint.fragment == null) {
        "Set INKURI_PLAY_VERIFY_URL to the deployed HTTPS purchase verifier."
    }
}
if (isRelease) {
    require(listOf("storeFile", "storePassword", "keyAlias", "keyPassword").all {
        !signingProperties.getProperty(it).isNullOrBlank()
    }) { "Release signing is not configured. Set INKURI_SIGNING_PROPERTIES or supply android/key.properties." }
}

android {
    namespace = "biz.wisemap.encre"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Permanent application ID for the public Inkuri app.
        applicationId = "biz.wisemap.encre"
        manifestPlaceholders["inkuriAdsAppId"] = adsAppId
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = maxOf(24, flutter.minSdkVersion)
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (signingFile.exists()) {
            create("release") {
                storeFile = signingProperties.getProperty("storeFile")?.let { file(it) }
                storePassword = signingProperties.getProperty("storePassword")
                keyAlias = signingProperties.getProperty("keyAlias")
                keyPassword = signingProperties.getProperty("keyPassword")
            }
        }
    }
    buildTypes {
        release {
            signingConfig = signingConfigs.findByName("release")
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
    implementation("com.google.android.play:app-update:2.1.0")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
