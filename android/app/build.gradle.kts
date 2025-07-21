import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keyPropertiesFile = rootProject.file("key.properties")
val keyProperties = Properties()
if (keyPropertiesFile.exists()) {
    // 如果文件存在，则加载其中的内容。
    keyProperties.load(FileInputStream(keyPropertiesFile))
}

android {
    namespace = "cn.staredges.swiftcat"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    signingConfigs {
        // 创建一个名为 'release' 的签名配置。
        // 只有当 key.properties 文件存在时，这里的配置才会有实际值。
        create("release") {
            keyAlias = keyProperties["keyAlias"] as String?
            keyPassword = keyProperties["keyPassword"] as String?
            storeFile = if (keyProperties["storeFile"] != null) file(keyProperties["storeFile"] as String) else null
            storePassword = keyProperties["storePassword"] as String?
        }
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "cn.staredges.swiftcat"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 21
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            if (keyPropertiesFile.exists() && keyProperties.containsKey("storeFile")) {
                // 如果文件存在且包含必要信息，则使用上面定义的 'release' 签名配置。
                signingConfig = signingConfigs.getByName("release")
            } else {
                // 如果文件不存在（这是开发者本地的常见情况），则回退到使用默认的 'debug' 签名。
                // 这样做可以确保即使没有配置发布密钥，`flutter run --release` 也能成功运行。
                signingConfig = signingConfigs.getByName("debug")
            }
        }
    }
}

dependencies {
    // ...
    implementation("com.google.android.material:material:1.12.0")
    // ...
}

flutter {
    source = "../.."
}
