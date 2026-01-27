// Copyright (c) BCS SDK Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// ULEB128 encoding/decoding utilities
public enum Uleb128 {
    /// Maximum value that can be encoded as ULEB128 in BCS (UInt32.max)
    public static let maxValue: UInt32 = UInt32.max

    /// Maximum number of bytes in a ULEB128-encoded UInt32
    public static let maxBytes: Int = 5

    /// Encode a UInt32 value as ULEB128
    /// - Parameter value: The value to encode
    /// - Returns: Array of bytes containing the ULEB128 encoding
    public static func encode(_ value: UInt32) -> [UInt8] {
        var result: [UInt8] = []
        var remaining = value

        repeat {
            var byte = UInt8(remaining & 0x7F)
            remaining >>= 7
            if remaining != 0 {
                byte |= 0x80  // Set continuation bit
            }
            result.append(byte)
        } while remaining != 0

        return result
    }

    /// Decode a ULEB128-encoded value from bytes
    /// - Parameters:
    ///   - data: The data to decode from
    ///   - offset: Starting offset in the data
    /// - Returns: Tuple of (decoded value, number of bytes consumed)
    /// - Throws: BcsError on invalid encoding or overflow
    public static func decode(_ data: [UInt8], offset: Int = 0) throws -> (value: UInt32, bytesRead: Int) {
        var value: UInt64 = 0
        var shift: UInt64 = 0
        var bytesRead = 0

        for i in 0..<maxBytes {
            guard offset + i < data.count else {
                throw BcsError.unexpectedEof()
            }

            let byte = data[offset + i]
            let digit = byte & 0x7F

            value |= UInt64(digit) << shift
            bytesRead = i + 1

            // Check if this is the last byte (high bit not set)
            if (byte & 0x80) == 0 {
                // Check for non-canonical encoding (trailing zeros)
                if shift > 0 && digit == 0 {
                    throw BcsError.nonCanonicalUleb128()
                }

                // Check for overflow
                if value > UInt64(maxValue) {
                    throw BcsError.uleb128Overflow()
                }

                return (UInt32(value), bytesRead)
            }

            shift += 7
        }

        // If we've read maxBytes and still have continuation bit, overflow
        throw BcsError.uleb128Overflow()
    }

    /// Calculate the encoded size of a value
    /// - Parameter value: The value to calculate size for
    /// - Returns: Number of bytes required to encode the value
    public static func encodedSize(_ value: UInt32) -> Int {
        var size = 1
        var remaining = value
        while remaining >= 0x80 {
            remaining >>= 7
            size += 1
        }
        return size
    }
}
