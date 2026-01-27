plugins {
    kotlin("jvm") version "2.3.0"
    `maven-publish`
}

group = "com.bcs"
version = "0.1.0"

repositories {
    mavenCentral()
}

dependencies {
    // Testing
    testImplementation(kotlin("test"))
    testImplementation("org.junit.jupiter:junit-jupiter:5.11.0")
}

tasks.test {
    useJUnitPlatform()
}

kotlin {
    jvmToolchain(21)
}

java {
    withSourcesJar()
    withJavadocJar()
}

publishing {
    publications {
        create<MavenPublication>("maven") {
            from(components["java"])
            
            pom {
                name.set("BCS Kotlin SDK")
                description.set("Binary Canonical Serialization (BCS) for Kotlin")
                url.set("https://github.com/bcs-sdks/bcs-sdks")
                
                licenses {
                    license {
                        name.set("Apache-2.0")
                        url.set("https://www.apache.org/licenses/LICENSE-2.0")
                    }
                }
            }
        }
    }
}
