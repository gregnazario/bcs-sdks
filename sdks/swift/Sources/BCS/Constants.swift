// Copyright (c) BCS SDK Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// BCS constants
public enum BcsConstants {
    /// Maximum length for variable-length sequences (2^31 - 1)
    public static let maxSequenceLength: Int = (1 << 31) - 1

    /// Maximum container depth for nested structures
    public static let maxContainerDepth: Int = 500
}
