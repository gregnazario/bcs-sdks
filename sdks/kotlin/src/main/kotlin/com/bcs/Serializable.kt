/**
 * Interfaces for BCS serialization
 */
package com.bcs

/**
 * Interface for types that can be serialized to BCS
 */
interface BcsSerializable {
    /**
     * Serialize this object to BCS bytes
     */
    fun serialize(): ByteArray

    /**
     * Serialize this object using a serializer
     */
    fun serialize(serializer: BcsSerializer)
}

/**
 * Interface for types that can be deserialized from BCS
 */
interface BcsDeserializable<T> {
    /**
     * Deserialize from BCS bytes
     */
    fun deserialize(data: ByteArray): T

    /**
     * Deserialize using a deserializer
     */
    fun deserialize(deserializer: BcsDeserializer): T
}

/**
 * Companion object interface for implementing both serialization and deserialization
 *
 * Usage:
 * ```kotlin
 * data class Person(val name: String, val age: Int) : BcsSerializable {
 *     override fun serialize(): ByteArray = bcsSerialize {
 *         writeString(name)
 *         writeU32(age.toLong())
 *     }
 *
 *     override fun serialize(serializer: BcsSerializer) {
 *         serializer.writeString(name)
 *         serializer.writeU32(age.toLong())
 *     }
 *
 *     companion object : BcsDeserializable<Person> {
 *         override fun deserialize(data: ByteArray): Person = bcsDeserialize(data) {
 *             Person(readString(), readU32().toInt())
 *         }
 *
 *         override fun deserialize(deserializer: BcsDeserializer): Person {
 *             return Person(
 *                 deserializer.readString(),
 *                 deserializer.readU32().toInt()
 *             )
 *         }
 *     }
 * }
 * ```
 */

/**
 * Extension function to serialize any BcsSerializable
 */
fun BcsSerializer.write(value: BcsSerializable) {
    value.serialize(this)
}

/**
 * Extension function to read a BcsDeserializable
 */
fun <T> BcsDeserializer.read(companion: BcsDeserializable<T>): T {
    return companion.deserialize(this)
}

/**
 * Serialize multiple BcsSerializable values to a single byte array
 */
fun serializeAll(vararg values: BcsSerializable): ByteArray = bcsSerialize {
    values.forEach { it.serialize(this) }
}
