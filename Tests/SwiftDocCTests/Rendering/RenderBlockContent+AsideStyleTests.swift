/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Markdown
import XCTest
@testable import SwiftDocC

class RenderBlockContent_AsideStyleTests: XCTestCase {
    private typealias Aside = RenderBlockContent.Aside

    func testDisplayNameForSpecialRawValue() {
        XCTAssertEqual(
            Aside(asideKind: .nonMutatingVariant, content: []).name,
            "Non-Mutating Variant"
        )
        XCTAssertEqual(
            Aside(asideKind: .init(rawValue: "nonmutatingvariant")!, content: []).name,
            "Non-Mutating Variant"
        )

        XCTAssertEqual(
            Aside(asideKind: .mutatingVariant, content: []).name,
            "Mutating Variant"
        )
        XCTAssertEqual(
            Aside(asideKind: .init(rawValue: "mutatingvariant")!, content: []).name,
            "Mutating Variant"
        )

        XCTAssertEqual(
            Aside(asideKind: .todo, content: []).name,
            "To Do"
        )
        XCTAssertEqual(
            Aside(asideKind: .init(rawValue: "todo")!, content: []).name,
            "To Do"
        )
    }

    func testDisplayNameForAsideWithExistingUppercasedContent() {
        XCTAssertEqual(
            Aside(asideKind: .init(rawValue: "Random title")!, content: []).name,
            "Random title"
        )
    }

    func testDisplayNameForAsideWithLowercasedContent() {
        XCTAssertEqual(
            Aside(asideKind: .init(rawValue: "random title")!, content: []).name,
            "Random Title"
        )
    }
}
