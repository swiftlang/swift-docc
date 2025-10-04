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
