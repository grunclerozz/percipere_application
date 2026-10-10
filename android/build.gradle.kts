allprojects {
    repositories {
        google()
        mavenCentral()
        // LiveKit (WebRTC under the ElevenLabs voice assistant) needs
        // com.github.davidliu:audioswitch, published only on JitPack. Limited
        // to that group so nothing else is fetched from there.
        maven {
            url = uri("https://jitpack.io")
            content { includeGroup("com.github.davidliu") }
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
// permission_handler_android 14.x declares `compileSdk = 37`, but the SDK only
// ships API 37 as the minor release "android-37.0", which a bare 37 does not
// resolve to. Point it at 37.0 explicitly.
subprojects {
    if (name == "permission_handler_android") {
        afterEvaluate {
            extensions.configure<com.android.build.api.dsl.LibraryExtension>("android") {
                compileSdk {
                    version = release(37) { minorApiLevel = 0 }
                }
            }
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
