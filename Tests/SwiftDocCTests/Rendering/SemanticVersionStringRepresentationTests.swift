/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import XCTest
import SymbolKit
@testable import SwiftDocC

class SemanticVersionStringRepresentationTests: XCTestCase {
    func test() {
        let oneComponent = SymbolGraph.SemanticVersion(major: 1, minor: 0, patch: 0)
        
        XCTAssertEqual(oneComponent.stringRepresentation(precisionUpToNonsignificant: .minor), "1.0")
        XCTAssertEqual(oneComponent.stringRepresentation(precisionUpToNonsignificant: .patch), "1.0.0")
        XCTAssertEqual(oneComponent.stringRepresentation(precisionUpToNonsignificant: .all), "1.0.0")
        
        let twoComponents = SymbolGraph.SemanticVersion(major: 1, minor: 2, patch: 0)
        XCTAssertEqual(twoComponents.stringRepresentation(precisionUpToNonsignificant: .minor), "1.2")
        XCTAssertEqual(twoComponents.stringRepresentation(precisionUpToNonsignificant: .patch), "1.2.0")
        XCTAssertEqual(twoComponents.stringRepresentation(precisionUpToNonsignificant: .all), "1.2.0")
        
        let threeComponents = SymbolGraph.SemanticVersion(major: 1, minor: 2, patch: 3)
        XCTAssertEqual(threeComponents.stringRepresentation(precisionUpToNonsignificant: .minor), "1.2.3")
        XCTAssertEqual(threeComponents.stringRepresentation(precisionUpToNonsignificant: .patch), "1.2.3")
        XCTAssertEqual(threeComponents.stringRepresentation(precisionUpToNonsignificant: .all), "1.2.3")
        
        let zeroVersion = SymbolGraph.SemanticVersion(major: 0, minor: 0, patch: 0)
        XCTAssertEqual(zeroVersion.stringRepresentation(precisionUpToNonsignificant: .minor), "0.0")
        XCTAssertEqual(zeroVersion.stringRepresentation(precisionUpToNonsignificant: .patch), "0.0.0")
        XCTAssertEqual(zeroVersion.stringRepresentation(precisionUpToNonsignificant: .all), "0.0.0")
        
        let zeroMinorVersion = SymbolGraph.SemanticVersion(major: 1, minor: 0, patch: 1)
        XCTAssertEqual(zeroMinorVersion.stringRepresentation(precisionUpToNonsignificant: .minor), "1.0.1")
        XCTAssertEqual(zeroMinorVersion.stringRepresentation(precisionUpToNonsignificant: .patch), "1.0.1")
        XCTAssertEqual(zeroMinorVersion.stringRepresentation(precisionUpToNonsignificant: .all), "1.0.1")
    }
}

