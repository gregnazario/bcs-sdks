// Copyright (c) BCS SDK Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// Error types for BCS serialization/deserialization
public enum BcsErrorType: Equatable, Sendable {
    case unexpectedEof
    case invalidBoolean(UInt8)
    case nonCanonicalUleb128
    case uleb128Overflow
    case exceededMaxLength(Int)
    case exceededContainerDepth(Int)
    case invalidUtf8
    case nonCanonicalMap
    case duplicateMapKey
    case integerOutOfRange(String)
    case remainingInput(Int)
    case invalidOption(UInt8)
}

/// BCS error with type and message
public struct BcsError: Error, Equatable, CustomStringConvertible {
    public let type: BcsErrorType
    public let message: String

    public init(_ type: BcsErrorType, _ message: String) {
        self.type = type
        self.message = message
    }

    public var description: String {
        message
    }

    // MARK: - Factory Methods

    public static func unexpectedEof() -> BcsError {
        BcsError(.unexpectedEof, "Unexpected end of input")
    }

    public static func invalidBoolean(_ value: UInt8) -> BcsError {
        BcsError(.invalidBoolean(value), "Invalid boolean value: \(value) (expected 0 or 1)")
    }

    public static func nonCanonicalUleb128() -> BcsError {
        BcsError(.nonCanonicalUleb128, "ULEB128 encoding is not canonical (has trailing zeros)")
    }

    public static func uleb128Overflow() -> BcsError {
        BcsError(.uleb128Overflow, "ULEB128 value overflows UInt32")
    }

    public static func exceededMaxLength(_ length: Int) -> BcsError {
        BcsError(
            .exceededMaxLength(length), "Sequence length \(length) exceeds maximum \(BcsConstants.maxSequenceLength)")
    }

    public static func exceededContainerDepth(_ depth: Int) -> BcsError {
        BcsError(
            .exceededContainerDepth(depth), "Container depth \(depth) exceeds maximum \(BcsConstants.maxContainerDepth)"
        )
    }

    public static func invalidUtf8() -> BcsError {
        BcsError(.invalidUtf8, "Invalid UTF-8 encoding")
    }

    public static func nonCanonicalMap() -> BcsError {
        BcsError(.nonCanonicalMap, "Map keys are not in sorted order")
    }

    public static func duplicateMapKey() -> BcsError {
        BcsError(.duplicateMapKey, "Duplicate key in map")
    }

    public static func integerOutOfRange(_ typeName: String) -> BcsError {
        BcsError(.integerOutOfRange(typeName), "Integer value out of range for \(typeName)")
    }

    public static func remainingInput(_ remaining: Int) -> BcsError {
        BcsError(.remainingInput(remaining), "Input has \(remaining) remaining bytes after deserialization")
    }

    public static func invalidOption(_ value: UInt8) -> BcsError {
        BcsError(.invalidOption(value), "Invalid option tag: \(value) (expected 0 or 1)")
    }
}
