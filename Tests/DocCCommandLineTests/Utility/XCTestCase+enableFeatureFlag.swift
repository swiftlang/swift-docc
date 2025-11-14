/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import SwiftDocC
import XCTest

extension XCTestCase {
    /// Enables the feature flag at the given key path until the end of current the test case.
    func enableFeatureFlag(_ featureFlagPath: WritableKeyPath<FeatureFlags, Bool>) {
        let defaultValues = FeatureFlags.current
        FeatureFlags.current[keyPath: featureFlagPath] = true
        
        addTeardownBlock {
            FeatureFlags.current = defaultValues
        }
    }
}

