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
    func testRenderBreadcrumbs(goal: RenderGoal) {
        let elements = [
            LinkedElement(
                path: URL(string: "/documentation/ModuleName/index.html")!,
                names: .single(.symbol("ModuleName")),
                subheadings: .single(.symbol([.init(text: "ModuleName", kind: .identifier)])),
                abstract: nil
            ),
            LinkedElement(
                path: URL(string: "/documentation/ModuleName/Something/index.html")!,
                names: .languageSpecificSymbol([
                    .swift:      "Something",
                    .objectiveC: "TLASomething",
                ]),
                subheadings: .languageSpecificSymbol([
                    .swift: [
                        .init(text: "class ", kind: .decorator),
                        .init(text: "Something", kind: .identifier),
                    ],
                    .objectiveC: [
                        .init(text: "class ", kind: .decorator),
                        .init(text: "TLASomething", kind: .identifier),
                    ],
                ]),
                abstract: nil
            ),
        ]
        let breadcrumbs = makeRenderer(goal: goal, elementsToReturn: elements).breadcrumbs(references: elements.map { $0.path }, currentPageNames: .single(.conceptual("ThisPage")))
        switch goal {
        case .richness:
            breadcrumbs.assertMatches(prettyFormatted: true, expectedXMLString: """
            <nav id="breadcrumbs">
              <ul>
                <li>
                  <a href="../../index.html">ModuleName</a>
                </li>
                <li>
                  <a href="../index.html">
                    <span class="swift-only">Something</span>
                    <span class="occ-only">TLASomething</span>
                  </a>
                </li>
                <li>ThisPage</li>
              </ul>
            </nav>
            """)
        case .conciseness:
            breadcrumbs.assertMatches(prettyFormatted: true, expectedXMLString: """
            <ul>
              <li>
                <a href="../../index.html">ModuleName</a>
              </li>
              <li>
                <a href="../index.html">Something</a>
              </li>
              <li>ThisPage</li>
            </ul>
            """)
        }
    }
    
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
    
    @Test(arguments: RenderGoal.allCases)
    func testRenderSingleLanguageParameters(goal: RenderGoal) {
        let parameters = makeRenderer(goal: goal).parameters([
            .swift: [
                .init(name: "First", content: parseMarkup(string: "Some _formatted_ description with `code`")),
                .init(name: "Second", content: parseMarkup(string: """
                Some **other** _formatted_ description

                That spans two paragraphs
                """)),
            ]
        ])
        
        switch goal {
        case .richness:
            parameters.assertMatches(prettyFormatted: true, expectedXMLString: """
            <section id="Parameters">
              <h2>
                <a href="#Parameters">Parameters</a>
              </h2>
              <dl>
                <dt>
                  <code>First</code>
                </dt>
                <dd>
                  <p>
                    Some <i>formatted</i> description with <code>code</code>
                  </p>
                </dd>
                <dt>
                  <code>Second</code>
                </dt>
                <dd>
                  <p>
                    Some <b>other</b> <i>formatted</i> description</p>
                  <p>That spans two paragraphs</p>
                </dd>
              </dl>
            </section>
            """)
        case .conciseness:
            parameters.assertMatches(prettyFormatted: true, expectedXMLString: """
            <h2>Parameters</h2>
            <dl>
              <dt>
                <code>First</code>
              </dt>
              <dd>
                <p>Some <i>formatted</i>description with <code>code</code>
                </p>
              </dd>
              <dt>
                <code>Second</code>
              </dt>
              <dd>
                <p>
                  Some <b>other</b> <i>formatted</i> description</p>
                <p>That spans two paragraphs</p>
              </dd>
            </dl>
            """)
        }
    }
    
    @Test
    func testRenderLanguageSpecificParameters() {
        let parameters = makeRenderer(goal: .richness).parameters([
            .swift: [
                .init(name: "FirstCommon", content: parseMarkup(string: "Available in both languages")),
                .init(name: "SwiftOnly", content: parseMarkup(string: "Only available in Swift")),
                .init(name: "SecondCommon", content: parseMarkup(string: "Also available in both languages")),
            ],
            .objectiveC: [
                .init(name: "FirstCommon", content: parseMarkup(string: "Available in both languages")),
                .init(name: "SecondCommon", content: parseMarkup(string: "Also available in both languages")),
                .init(name: "ObjectiveCOnly", content: parseMarkup(string: "Only available in Objective-C")),
            ],
        ])
        parameters.assertMatches(prettyFormatted: true, expectedXMLString: """
        <section id="Parameters">
          <h2>
            <a href="#Parameters">Parameters</a>
          </h2>
          <dl>
            <dt>
              <code>FirstCommon</code>
            </dt>
            <dd>
              <p>Available in both languages</p>
            </dd>
            <dt class="swift-only">
              <code>SwiftOnly</code>
            </dt>
            <dd class="swift-only">
              <p>Only available in Swift</p>
            </dd>
            <dt>
              <code>SecondCommon</code>
            </dt>
            <dd>
              <p>Also available in both languages</p>
            </dd>
            <dt class="occ-only">
              <code>ObjectiveCOnly</code>
            </dt>
            <dd class="occ-only">
              <p>Only available in Objective-C</p>
            </dd>
          </dl>
        </section>
        """)
    }
    
    @Test
    func testRenderManyLanguageSpecificParameters() {
        let parameters = makeRenderer(goal: .richness).parameters([
            .swift: [
                .init(name: "First", content: parseMarkup(string: "Some description")),
            ],
            .objectiveC: [
                .init(name: "Second", content: parseMarkup(string: "Some description")),
            ],
            .data: [
                .init(name: "Third", content: parseMarkup(string: "Some description")),
            ],
        ])
        parameters.assertMatches(prettyFormatted: true, expectedXMLString: """
        <section id="Parameters">
          <h2>
            <a href="#Parameters">Parameters</a>
          </h2>
          <dl class="swift-only">
            <dt>
              <code>First</code>
            </dt>
            <dd>
              <p>Some description</p>
            </dd>
          </dl>
          <dl class="data-only">
            <dt>
              <code>Third</code>
            </dt>
            <dd>
              <p>Some description</p>
            </dd>
          </dl>
          <dl class="occ-only">
            <dt>
              <code>Second</code>
            </dt>
            <dd>
              <p>Some description</p>
            </dd>
          </dl>
        </section>
        """)
    }
    
    @Test(arguments: RenderGoal.allCases)
    func testRenderSingleLanguageReturnSections(goal: RenderGoal) {
        let returns = makeRenderer(goal: goal).returns([
            .swift: parseMarkup(string: "First paragraph\n\nSecond paragraph")
        ])
        
        let commonHTML = """
        <p>First paragraph</p>
        <p>Second paragraph</p>
        """
        
        switch goal {
        case .richness:
            returns.assertMatches(prettyFormatted: true, expectedXMLString: """
            <section id="Return-Value">
            <h2>
              <a href="#Return-Value">Return Value</a>
            </h2>
            \(commonHTML)
            </section>
            """)
        case .conciseness:
            returns.assertMatches(prettyFormatted: true, expectedXMLString: """
            <h2>Return Value</h2>
            \(commonHTML)
            """)
        }
    }
    
    @Test(arguments: RenderGoal.allCases)
    func testRenderLanguageSpecificReturnSections(goal: RenderGoal) {
        let returns = makeRenderer(goal: goal).returns([
            .swift:      parseMarkup(string: "First paragraph\n\nSecond paragraph"),
            .objectiveC: parseMarkup(string: "Other language's paragraph"),
        ])
        
        let commonHTML = """
        <p class="swift-only">First paragraph</p>
        <p class="swift-only">Second paragraph</p>
        <p class="occ-only">Other language’s paragraph</p>
        """
        
        switch goal {
        case .richness:
            returns.assertMatches(prettyFormatted: true, expectedXMLString: """
            <section id="Return-Value">
            <h2>
              <a href="#Return-Value">Return Value</a>
            </h2>
            \(commonHTML)
            </section>
            """)
        case .conciseness:
            returns.assertMatches(prettyFormatted: true, expectedXMLString: """
            <h2>Return Value</h2>
            \(commonHTML)
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
