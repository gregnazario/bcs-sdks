// Copyright (c) BCS SDK Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// BCS constants
public enum BcsConstants {
    /// Maximum length for variable-length sequences (2^31 - 1)
    @inlinable
    public static var maxSequenceLength: Int { (1 << 31) - 1 }

    /// Maximum container depth for nested structures
    @inlinable
    public static var maxContainerDepth: Int { 500 }
}
