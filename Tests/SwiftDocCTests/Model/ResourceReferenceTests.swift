/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import SwiftDocC

class ResourceReferenceTests: XCTestCase {
    func testPathWithSectionFragment() throws {
        let ref = ResolvedTopicReference(bundleIdentifier: "org.swift.docc.example", path: "/Test-Bundle/Tutorial1", sourceLanguage: .swift)
        XCTAssertEqual(ref.absoluteString, "doc://org.swift.docc.example/Test-Bundle/Tutorial1")
        
        let refAdvanced = ref.withFragment("fragment")
        XCTAssertEqual(refAdvanced.absoluteString, "doc://org.swift.docc.example/Test-Bundle/Tutorial1#fragment")
        
        let refSuperAdvanced = ref.withFragment(" FRä'g'mē\"nt ")
        XCTAssertEqual(refSuperAdvanced.absoluteString, "doc://org.swift.docc.example/Test-Bundle/Tutorial1#FR%C3%A4gm%C4%93nt")
    }
}
