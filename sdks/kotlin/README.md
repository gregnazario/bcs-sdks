# BCS Kotlin SDK

Idiomatic Kotlin bindings for Binary Canonical Serialization (BCS), built on top of the Java SDK.

## Features

- **Kotlin-First API**: Extension functions, DSL, and null safety
- **Java Interop**: Seamlessly uses the Java BCS implementation
- **Type-Safe**: Generics and inline functions for type safety
- **Coroutine-Friendly**: Suspend functions for async serialization (coming soon)

## Installation

Add to your `build.gradle.kts`:

```kotlin
dependencies {
    implementation("com.bcs:bcs-kotlin:0.1.0")
}
```

## Quick Start

```kotlin
import com.bcs.*

// Serialize using DSL
val bytes = bcsSerialize {
    writeU64(12345)
    writeString("hello")
    writeBool(true)
}

// Deserialize using DSL
val (num, str, flag) = bcsDeserialize(bytes) {
    Triple(readU64(), readString(), readBool())
}
```

## Idiomatic Kotlin Features

### Null Safety for Options

```kotlin
// Serialize optional values using Kotlin's null type
val bytes = bcsSerialize {
    writeOption(42) { writeU32(it.toLong()) }    // Some
    writeOption<String>(null) { writeString(it) } // None
}

// Deserialize returns nullable type
val result = bcsDeserialize(bytes) {
    val maybeNum: Int? = readOption { readU32().toInt() }
    val maybeStr: String? = readOption { readString() }
    Pair(maybeNum, maybeStr)
}
```

### Lists and Collections

```kotlin
// Serialize lists
val bytes = bcsSerialize {
    writeList(listOf(1, 2, 3)) { writeU8(it) }
    writeStringList(listOf("foo", "bar"))
}

// Deserialize lists
val result = bcsDeserialize(bytes) {
    val numbers = readList { readU8() }
    val strings = readStringList()
    Pair(numbers, strings)
}
```

### Maps

```kotlin
// Serialize maps (sorted by key bytes)
val bytes = bcsSerialize {
    writeMap(
        mapOf("alice" to 100L, "bob" to 200L),
        keySerializer = { writeString(it) },
        valueSerializer = { writeU64(it) }
    )
}

// Deserialize maps
val result = bcsDeserialize(bytes) {
    readMap(
        keyDeserializer = { readString() },
        valueDeserializer = { readU64() }
    )
}
```

### Structs with DSL

```kotlin
// Serialize struct
val bytes = bcsSerialize {
    writeStruct {
        writeString("Alice")
        writeU32(30)
        writeOption("alice@example.com") { writeString(it) }
    }
}

// Deserialize struct
data class Person(val name: String, val age: Int, val email: String?)

val person = bcsDeserialize(bytes) {
    readStruct {
        Person(
            name = readString(),
            age = readU32().toInt(),
            email = readOption { readString() }
        )
    }
}
```

### Enums

```kotlin
// Serialize enum variant
val bytes = bcsSerialize {
    writeEnum(1) {  // variant index 1
        writeString("payload")
    }
}

// Deserialize enum
sealed class Message {
    data class Text(val content: String) : Message()
    data class Image(val data: ByteArray) : Message()
}

val message = bcsDeserialize(bytes) {
    readEnum { variant ->
        when (variant) {
            0 -> Message.Text(readString())
            1 -> Message.Image(readBytes())
            else -> error("Unknown variant: $variant")
        }
    }
}
```

### BcsSerializable Interface

```kotlin
data class Person(
    val name: String,
    val age: Int
) : BcsSerializable {
    override fun serialize(): ByteArray = bcsSerialize {
        writeString(name)
        writeU32(age.toLong())
    }

    override fun serialize(serializer: BcsSerializer) {
        serializer.writeString(name)
        serializer.writeU32(age.toLong())
    }

    companion object : BcsDeserializable<Person> {
        override fun deserialize(data: ByteArray): Person = bcsDeserialize(data) {
            Person(readString(), readU32().toInt())
        }

        override fun deserialize(deserializer: BcsDeserializer): Person {
            return Person(
                deserializer.readString(),
                deserializer.readU32().toInt()
            )
        }
    }
}

// Usage
val person = Person("Alice", 30)
val bytes = person.serialize()
val restored = Person.deserialize(bytes)
```

### Infix Syntax

```kotlin
val ser = BcsSerializer()
ser write true
ser write "hello"
ser write 42.toUByte()
```

## BigInteger Support

For u128/u256:

```kotlin
import java.math.BigInteger

val bytes = bcsSerialize {
    writeU128(BigInteger.valueOf(Long.MAX_VALUE).multiply(BigInteger.TEN))
    writeU256(BigInteger.TWO.pow(200))
}

val result = bcsDeserialize(bytes) {
    Pair(readU128AsBigInteger(), readU256AsBigInteger())
}
```

## Error Handling

```kotlin
import com.bcs.BcsError

try {
    bcsDeserialize(invalidData) { readU64() }
} catch (e: BcsError) {
    println("BCS error: ${e.message}")
    when (e.type) {
        BcsError.Type.UNEXPECTED_EOF -> // Handle EOF
        BcsError.Type.INVALID_UTF8 -> // Handle invalid UTF-8
        else -> throw e
    }
}
```

## Hex Utilities

```kotlin
// Extension functions
val hex = byteArrayOf(0x01, 0x02, 0xab.toByte()).toHex()  // "0102ab"
val bytes = "0102ab".hexToBytes()  // [1, 2, 171]
```

## Development

### Prerequisites

- JDK 17+
- Kotlin 1.9+
- Gradle 8+
- Java BCS SDK (built automatically)

### Building

```bash
make build    # Build library (and Java dependency)
make test     # Run tests
make lint     # Check code style
make format   # Format code
```

### Project Structure

```
src/
├── main/kotlin/com/bcs/
│   ├── Bcs.kt                  # Main entry point and utilities
│   ├── SerializerExtensions.kt # BcsSerializer extensions
│   ├── DeserializerExtensions.kt # BcsDeserializer extensions
│   └── Serializable.kt         # BcsSerializable interface
└── test/kotlin/com/bcs/
    └── BcsTest.kt              # Test suite
```

## License

Apache-2.0
