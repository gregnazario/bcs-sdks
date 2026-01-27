plugins {
    kotlin("jvm") version "2.0.0"
    application
}

application {
    mainClass.set("KotlinRunnerKt")
}

repositories {
    mavenCentral()
}

dependencies {
    implementation(files("../../../sdks/kotlin/build/libs/bcs-kotlin-0.1.0.jar"))
}

kotlin {
    jvmToolchain(21)
}

tasks.jar {
    manifest {
        attributes["Main-Class"] = "KotlinRunnerKt"
    }
    from(configurations.runtimeClasspath.get().map { if (it.isDirectory) it else zipTree(it) })
    duplicatesStrategy = DuplicatesStrategy.EXCLUDE
}
