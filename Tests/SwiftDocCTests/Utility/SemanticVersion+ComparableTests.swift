/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Testing
import SymbolKit

struct SemanticVersion_ComparableTests {
    typealias Version = SymbolGraph.SemanticVersion
    
    @Test(arguments: [
        (Version(major: 1, minor: 1, patch: 1), Version(major: 1, minor: 1, patch: 2)),
        (Version(major: 1, minor: 1, patch: 3), Version(major: 1, minor: 2, patch: 1)),
        (Version(major: 1, minor: 3, patch: 1), Version(major: 2, minor: 1, patch: 2)),
    ])
    func comparesByMajorThenMinorThenPatch(smaller: Version, larger: Version) {
        #expect(smaller < larger)
    }
}
