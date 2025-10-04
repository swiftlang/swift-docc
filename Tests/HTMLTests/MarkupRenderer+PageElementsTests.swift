/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import XCTest
import HTML
@testable import SwiftDocC
import Markdown

final class MarkupRenderer_PageElementsTests: XCTestCase {
    
    func testRenderBreadcrumbs() throws {
        let elements = [
            LinkedElement(
                path: URL(string: "/documentation/ModuleName/index.html")!,
                names: .single(.symbol("ModuleName"))
            ),
            LinkedElement(
                path: URL(string: "/documentation/ModuleName/Something/index.html")!,
                names: .languageSpecificSymbol([
                    "swift": "Something",
                    "occ": "TLASomething",
                ])
            ),
        ]
        let breadcrumbs = makeRenderer(elementsToReturn: elements).breadcrumbs(references: elements.map { $0.path })
        
        XCTAssertEqual(breadcrumbs.rendered(prettyFormatted: true), """
        <nav id="breadcrumbs">
        <ul>
            <li>
                <a href="../../../index.html">ModuleName</a>
            </li>
            <li>
                <a href="../../index.html">
                    <span class="swift-only">Something</span>
                    <span class="occ-only">TLASomething</span>
                </a>
            </li>
            <li>ThisPage</li>
        </ul>
        </nav>
        """)
    }
    
    func testRenderAvailability() throws {
        let availability = makeRenderer().availability([
            .init(name: "First", introduced: "1.2", deprecated: "3.4", isBeta: false),
            .init(name: "Second", introduced: "1.2.3", isBeta: false),
            .init(name: "Third", introduced: "4.5", isBeta: true),
        ])
        
        XCTAssertEqual(availability.rendered(prettyFormatted: true), """
        <ul id="availability">
        <li aria-label="First 1.2–3.4, Introduced in First 1.2 and deprecated in First 3.4" class="deprecated" role="text" title="Introduced in First 1.2 and deprecated in First 3.4">First 1.2–3.4</li>
        <li aria-label="Second 1.2.3+, Available on 1.2.3 and later" role="text" title="Available on 1.2.3 and later">Second 1.2.3+</li>
        <li aria-label="Third 4.5+, Available on 4.5 and later" class="beta" role="text" title="Available on 4.5 and later">Third 4.5+</li>
        </ul>
        """)
    }
    
    // MARK: -
    
    private func makeRenderer(
        elementsToReturn: [LinkedElement] = [],
        assetsToReturn: [String: LinkedAsset] = [:],
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> MarkupRenderer<some LinkProvider> {
        let path = URL(string: "/documentation/ModuleName/Something/ThisPage/index.html")!
        
        var elementsByURL = [
            path: LinkedElement(path: path, names: .single( .symbol("ThisPage") ))
        ]
        for element in elementsToReturn {
            elementsByURL[element.path] = element
        }
        
        return MarkupRenderer(
            path: path,
            linkProvider: MultiValueLinkProvider(
                elementsToReturn: elementsByURL,
                assetsToReturn: assetsToReturn
            )
        )
    }
}

struct MultiValueLinkProvider: LinkProvider {
    var elementsToReturn: [URL: LinkedElement]
    func element(for path: URL) -> LinkedElement? {
        elementsToReturn[path]
    }
    
    var assetsToReturn: [String: LinkedAsset]
    func assetNamed(_ assetName: String) -> LinkedAsset? {
        assetsToReturn[assetName]
    }
}
