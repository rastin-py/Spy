allprojects {
    repositories {
        // Order matters. `dl.google.com` is unreachable from this network - it
        // answers 404 for every artifact - so the Aliyun mirror of Google's
        // Maven goes first and google() stays as the fallback for a machine
        // that can reach it. This is what unblocks third-party Android
        // plugins: they pin their own AGP versions, and those pins used to be
        // unresolvable here.
        maven("https://maven.aliyun.com/repository/google")
        maven("https://maven.aliyun.com/repository/public")
        google()
        mavenCentral()

        // Tapsell's own Maven, for `ir.tapsell:*`. Scoped by group so nothing
        // else is ever fetched from it.
        maven("https://maven.tapsell.ir/repository/maven2") {
            content { includeGroupByRegex("ir\\.tapsell.*") }
        }
        // Bazaar's billing library (Poolakey) publishes through JitPack.
        maven("https://jitpack.io") {
            content { includeGroupByRegex("com\\.github\\.cafebazaar.*") }
        }
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

// `tapsell_mediation` declares the namespace `ir.tapsell.mediation` for its
// Flutter module - the same namespace its own native library
// (`ir.tapsell:tapsell-flutter`) uses. AGP 8 and later refuse to merge two
// modules that share one, so the build dies in the manifest merger before it
// reaches anything of ours. Renaming the module is not enough on its own: the
// legacy `package` attribute in its manifest then disagrees with the new
// namespace, and AGP rejects that too.
//
// So the module gets both - a namespace out of the way, and our copy of its
// manifest with the `package` attribute removed. The module ships one Kotlin
// file and no resources, so there is no R class anybody references and this
// costs nothing. Present in 1.3.0 and still in 1.4.0-alpha03; when a release
// drops the attribute, delete this block and android/tapsell/.
//
// Reflection because the root build script does not have the Android Gradle
// Plugin on its own classpath.
subprojects {
    if (name == "tapsell_mediation") {
        afterEvaluate {
            val android = extensions.findByName("android") ?: return@afterEvaluate

            android.javaClass.methods
                .firstOrNull { it.name == "setNamespace" && it.parameterCount == 1 }
                ?.invoke(android, "ir.tapsell.mediation.flutter")

            val sourceSets = android.javaClass.methods
                .firstOrNull { it.name == "getSourceSets" && it.parameterCount == 0 }
                ?.invoke(android) as? org.gradle.api.NamedDomainObjectContainer<*>
            val main = sourceSets?.findByName("main")
            val manifest = main?.javaClass?.methods
                ?.firstOrNull { it.name == "getManifest" && it.parameterCount == 0 }
                ?.invoke(main)
            manifest?.javaClass?.methods
                ?.firstOrNull { it.name == "srcFile" && it.parameterCount == 1 }
                ?.invoke(manifest, rootProject.file("tapsell/AndroidManifest.xml"))
        }
    }
}

// Third-party plugins pin whatever `compileSdk` was current when they were
// published - Poolakey asks for 34, others for 33 - and this machine cannot
// download platform SDKs (sdkmanager reaches the same unreachable Google
// host). Compiling a plugin against a newer platform than it asked for is
// safe and is the usual Flutter workaround, so every Android module is raised
// to the one the app itself builds against.
//
// Reflection because the root build script does not have the Android Gradle
// Plugin on its own classpath.
subprojects {
    if (name != "app") {
        afterEvaluate {
            val android = extensions.findByName("android") ?: return@afterEvaluate
            android.javaClass.methods
                .firstOrNull { it.name == "compileSdkVersion" && it.parameterCount == 1 &&
                    it.parameterTypes[0] == Int::class.javaPrimitiveType }
                ?.invoke(android, 36)
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
