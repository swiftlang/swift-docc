/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

#if canImport(FoundationXML)
// TODO: Consider other HTML rendering options as a future improvement (rdar://165755530)
import FoundationXML
import FoundationEssentials
#else
import Foundation
#endif

import Testing
import DocCHTML
import Markdown

struct MarkdownRenderer_PageElementsTests {
    @Test(arguments: RenderGoal.allCases)
    func testRenderAvailability(goal: RenderGoal) {
        let availability = makeRenderer(goal: goal).availability([
            .init(name: "First",  introduced: "1.2", deprecated: "3.4", isBeta: false),
            .init(name: "Second", introduced: "1.2.3",                  isBeta: false),
            .init(name: "Third",  introduced: "4.5",                    isBeta: true),
        ])
        switch goal {
        case .richness:
            availability.assertMatches(prettyFormatted: true, expectedXMLString: """
            <ul id="availability">
              <li aria-label="First 1.2–3.4, Introduced in First 1.2 and deprecated in First 3.4" class="deprecated" role="text" title="Introduced in First 1.2 and deprecated in First 3.4">First 1.2–3.4</li>
              <li aria-label="Second 1.2.3+, Available on 1.2.3 and later" role="text" title="Available on 1.2.3 and later">Second 1.2.3+</li>
              <li aria-label="Third 4.5+, Available on 4.5 and later" class="beta" role="text" title="Available on 4.5 and later">Third 4.5+</li>
            </ul>
            """)
        case .conciseness:
            availability.assertMatches(prettyFormatted: true, expectedXMLString: """
            <ul id="availability">
              <li>First 1.2–3.4</li>
              <li>Second 1.2.3+</li>
              <li>Third 4.5+</li>
            </ul>
            """)
        }
    }
    
    // MARK: -
    
    private func makeRenderer(
        goal: RenderGoal,
        elementsToReturn: [LinkedElement] = [],
        pathsToReturn: [String: URL] = [:],
        assetsToReturn: [String: LinkedAsset] = [:],
        fallbackLinkTextsToReturn: [String: String] = [:]
    ) -> MarkdownRenderer<some LinkProvider> {
        let path = URL(string: "/documentation/ModuleName/Something/ThisPage/index.html")!
        
        var elementsByURL = [
            path: LinkedElement(
                path: path,
                names: .single( .symbol("ThisPage") ),
                subheadings: .single( .symbol([
                    .init(text: "class ", kind: .decorator),
                    .init(text: "ThisPage", kind: .identifier),
                ])),
                abstract: nil
            )
        ]
        for element in elementsToReturn {
            elementsByURL[element.path] = element
        }
        
        return MarkdownRenderer(path: path, goal: goal, linkProvider: MultiValueLinkProvider(
            elementsToReturn: elementsByURL,
            pathsToReturn: pathsToReturn,
            assetsToReturn: assetsToReturn,
            fallbackLinkTextsToReturn: fallbackLinkTextsToReturn
        ))
    }
    
    private func parseMarkup(string: String) -> [any Markup] {
        let document = Document(parsing: string, options: [.parseBlockDirectives, .parseSymbolLinks])
        return Array(document.children)
    }
}

struct MultiValueLinkProvider: LinkProvider {
    var elementsToReturn: [URL: LinkedElement]
    func element(for path: URL) -> LinkedElement? {
        elementsToReturn[path]
    }
    
    var pathsToReturn: [String: URL]
    func pathForSymbolID(_ usr: String) -> URL? {
        pathsToReturn[usr]
    }
    
    var assetsToReturn: [String: LinkedAsset]
    func assetNamed(_ assetName: String) -> LinkedAsset? {
        assetsToReturn[assetName]
    }
    
    var fallbackLinkTextsToReturn: [String: String]
    func fallbackLinkText(linkString: String) -> String {
        fallbackLinkTextsToReturn[linkString] ?? linkString
    }
}

extension RenderGoal: CaseIterable {
    package static var allCases: [RenderGoal] {
        [.richness, .conciseness]
    }
}
