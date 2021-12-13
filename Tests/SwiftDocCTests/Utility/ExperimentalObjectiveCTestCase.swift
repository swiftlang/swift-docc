/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest

/// A test case that enables the experimental Objective-C support feature flag
/// before running.
class ExperimentalObjectiveCTestCase: XCTestCase {
    override func setUp() {
        super.setUp()
        enableFeatureFlag(\.isExperimentalObjectiveCSupportEnabled)
    }
}
