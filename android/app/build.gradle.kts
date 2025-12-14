plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.reader_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.reader_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
// android/build.gradle.kts 的末尾添加：

subprojects {
    afterEvaluate {
        val android = extensions.findByName("android")
        if (android != null) {
            // 获取 android 扩展配置
            val namespace = (android as? com.android.build.gradle.BaseExtension)?.namespace

            // 如果库没有设置 namespace，我们手动给它赋予一个
            if (namespace == null) {
                val manifestFile = file("src/main/AndroidManifest.xml")
                if (manifestFile.exists()) {
                    // 读取 Manifest 文件中的 package 属性作为 namespace
                    val manifestContent = manifestFile.readText()
                    val packageNameRegex = "package=\"([^\"]+)\"".toRegex()
                    val matchResult = packageNameRegex.find(manifestContent)
                    val packageName = matchResult?.groups?.get(1)?.value

                    if (packageName != null) {
                        (android as com.android.build.gradle.BaseExtension).namespace = packageName
                    }
                }
            }
        }
    }
}