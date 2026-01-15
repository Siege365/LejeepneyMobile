allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.layout.buildDirectory = rootProject.projectDir.parentFile.resolve("build")

subprojects {
    project.layout.buildDirectory = rootProject.projectDir.parentFile.resolve("build").resolve(project.name)
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
