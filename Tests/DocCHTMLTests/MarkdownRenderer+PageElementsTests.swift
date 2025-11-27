/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Testing
import DocCHTML
@testable import SwiftDocC
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
        case .quality:
            #expect(breadcrumbs.rendered(prettyFormatted: true) == """
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
        case .conciseness:
            #expect(breadcrumbs.rendered(prettyFormatted: true) == """
            <ul>
            <li>
                <a href="../../../index.html">ModuleName</a>
            </li>
            <li>
                <a href="../../index.html">Something</a>
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
        case .quality:
            #expect(availability.rendered(prettyFormatted: true) == """
            <ul id="availability">
            <li aria-label="First 1.2–3.4, Introduced in First 1.2 and deprecated in First 3.4" class="deprecated" role="text" title="Introduced in First 1.2 and deprecated in First 3.4">First 1.2–3.4</li>
            <li aria-label="Second 1.2.3+, Available on 1.2.3 and later" role="text" title="Available on 1.2.3 and later">Second 1.2.3+</li>
            <li aria-label="Third 4.5+, Available on 4.5 and later" class="beta" role="text" title="Available on 4.5 and later">Third 4.5+</li>
            </ul>
            """)
        case .conciseness:
            #expect(availability.rendered(prettyFormatted: true) == """
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
        let expectedHTMLStart = switch goal {
        case .quality: """
            <section id="parameters">
            <h2>
                <a href="#parameters">Parameters</a>
            </h2>
            """
        case .conciseness: """
            <section>
            <h2>Parameters</h2>
            """
        }
        
        #expect(parameters.rendered(prettyFormatted: true) == """
        \(expectedHTMLStart)
        <dl>
            <dt>
                <code>First</code>
            </dt>
            <dd>
                <p>Some <i>formatted</i>
                     description with <code>code</code>
                </p>
            </dd>
            <dt>
                <code>Second</code>
            </dt>
            <dd>
                <p>Some <b>other</b>
                     <i>formatted</i>
                     description</p>
                <p>That spans two paragraphs</p>
            </dd>
        </dl>
        </section>
        """)
    }
    
    @Test
    func testRenderLanguageSpecificParameters() {
        let parameters = makeRenderer(goal: .quality).parameters([
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
        #expect(parameters.rendered(prettyFormatted: true) == """
        <section id="parameters">
        <h2>
            <a href="#parameters">Parameters</a>
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
        let parameters = makeRenderer(goal: .quality).parameters([
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
        #expect(parameters.rendered(prettyFormatted: true) == """
        <section id="parameters">
        <h2>
            <a href="#parameters">Parameters</a>
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
    func testRenderSwiftDeclaration(goal: RenderGoal) {
        let symbolPaths = [
            "first-parameter-symbol-id":  URL(string: "/documentation/ModuleName/FirstParameterValue/index.html")!,
            "second-parameter-symbol-id": URL(string: "/documentation/ModuleName/SecondParameterValue/index.html")!,
            "return-value-symbol-id":     URL(string: "/documentation/ModuleName/ReturnValue/index.html")!,
        ]
        
        let declaration = makeRenderer(goal: goal, pathsToReturn: symbolPaths).declaration([
            .swift:  [
                .init(kind: .keyword,           spelling: "func",        preciseIdentifier: nil),
                .init(kind: .text,              spelling: " ",           preciseIdentifier: nil),
                .init(kind: .identifier,        spelling: "doSomething", preciseIdentifier: nil),
                .init(kind: .text,              spelling: "(",           preciseIdentifier: nil),
                .init(kind: .externalParameter, spelling: "with",        preciseIdentifier: nil),
                .init(kind: .text,              spelling: " ",           preciseIdentifier: nil),
                .init(kind: .internalParameter, spelling: "first",       preciseIdentifier: nil),
                .init(kind: .text,              spelling: ": ",          preciseIdentifier: nil),
                .init(kind: .typeIdentifier,    spelling: "FirstParameterValue", preciseIdentifier: "first-parameter-symbol-id"),
                .init(kind: .text,              spelling: ", ",          preciseIdentifier: nil),
                .init(kind: .externalParameter, spelling: "and",         preciseIdentifier: nil),
                .init(kind: .text,              spelling: " ",           preciseIdentifier: nil),
                .init(kind: .internalParameter, spelling: "second",      preciseIdentifier: nil),
                .init(kind: .text,              spelling: ": ",          preciseIdentifier: nil),
                .init(kind: .typeIdentifier,    spelling: "SecondParameterValue", preciseIdentifier: "second-parameter-symbol-id"),
                .init(kind: .text,              spelling: ") ",          preciseIdentifier: nil),
                .init(kind: .keyword,           spelling: "throws",      preciseIdentifier: nil),
                .init(kind: .text,              spelling: "-> ",         preciseIdentifier: nil),
                .init(kind: .typeIdentifier,    spelling: "ReturnValue", preciseIdentifier: "return-value-symbol-id"),
            ]
        ])
        switch goal {
        case .quality:
            #expect(declaration.rendered(prettyFormatted: true) == """
            <pre id="declaration">
            <code>
                <span class="token-keyword">func</span>
                 <span class="token-identifier">doSomething</span>
                (<span class="token-externalParam">with</span>
                 <span class="token-internalParam">first</span>
                : <a class="token-typeIdentifier" href="../../../FirstParameterValue/index.html">FirstParameterValue</a>
                , <span class="token-externalParam">and</span>
                 <span class="token-internalParam">second</span>
                : <a class="token-typeIdentifier" href="../../../SecondParameterValue/index.html">SecondParameterValue</a>
                ) <span class="token-keyword">throws</span>
                -&gt; <a class="token-typeIdentifier" href="../../../ReturnValue/index.html">ReturnValue</a>
            </code>
            </pre>
            """)
        case .conciseness:
            #expect(declaration.rendered(prettyFormatted: true) == """
            <pre>
            <code>func doSomething(with first: FirstParameterValue, and second: SecondParameterValue) throws-&gt; ReturnValue</code>
            </pre>
            """)
        }
    }
    
    @Test(arguments: RenderGoal.allCases)
    func testRenderSingleLanguageReturnSections(goal: RenderGoal) {
        let parameters = makeRenderer(goal: goal).returns([
            .swift: parseMarkup(string: "First paragraph\n\nSecond paragraph")
        ])
        let expectedHTMLStart = switch goal {
        case .quality: """
            <section id="return-value">
            <h2>
                <a href="#return-value">Return Value</a>
            </h2>
            """
        case .conciseness: """
            <section>
            <h2>Return Value</h2>
            """
        }
        
        #expect(parameters.rendered(prettyFormatted: true) == """
        \(expectedHTMLStart)
        <p>First paragraph</p>
        <p>Second paragraph</p>
        </section>
        """)
    }
    
    @Test(arguments: RenderGoal.allCases)
    func testRenderLanguageSpecificReturnSections(goal: RenderGoal) {
        let parameters = makeRenderer(goal: goal).returns([
            .swift:      parseMarkup(string: "First paragraph\n\nSecond paragraph"),
            .objectiveC: parseMarkup(string: "Other language's paragraph"),
        ])
        let expectedHTMLStart = switch goal {
        case .quality: """
            <section id="return-value">
            <h2>
                <a href="#return-value">Return Value</a>
            </h2>
            """
        case .conciseness: """
            <section>
            <h2>Return Value</h2>
            """
        }
        
        #expect(parameters.rendered(prettyFormatted: true) == """
        \(expectedHTMLStart)
        <p class="swift-only">First paragraph</p>
        <p class="swift-only">Second paragraph</p>
        <p class="occ-only">Other language’s paragraph</p>
        </section>
        """)
    }
    
    @Test(arguments: RenderGoal.allCases)
    func testRenderLanguageSpecificDeclarations(goal: RenderGoal) {
        let symbolPaths = [
            "first-parameter-symbol-id":  URL(string: "/documentation/ModuleName/FirstParameterValue/index.html")!,
            "second-parameter-symbol-id": URL(string: "/documentation/ModuleName/SecondParameterValue/index.html")!,
            "return-value-symbol-id":     URL(string: "/documentation/ModuleName/ReturnValue/index.html")!,
            "error-parameter-symbol-id":  URL(string: "/documentation/Foundation/NSError/index.html")!,
        ]
        
        let declaration = makeRenderer(goal: goal, pathsToReturn: symbolPaths).declaration([
            .swift:  [
                .init(kind: .keyword,           spelling: "func",        preciseIdentifier: nil),
                .init(kind: .text,              spelling: " ",           preciseIdentifier: nil),
                .init(kind: .identifier,        spelling: "doSomething", preciseIdentifier: nil),
                .init(kind: .text,              spelling: "(",           preciseIdentifier: nil),
                .init(kind: .externalParameter, spelling: "with",        preciseIdentifier: nil),
                .init(kind: .text,              spelling: " ",           preciseIdentifier: nil),
                .init(kind: .internalParameter, spelling: "first",       preciseIdentifier: nil),
                .init(kind: .text,              spelling: ": ",          preciseIdentifier: nil),
                .init(kind: .typeIdentifier,    spelling: "FirstParameterValue", preciseIdentifier: "first-parameter-symbol-id"),
                .init(kind: .text,              spelling: ", ",          preciseIdentifier: nil),
                .init(kind: .externalParameter, spelling: "and",         preciseIdentifier: nil),
                .init(kind: .text,              spelling: " ",           preciseIdentifier: nil),
                .init(kind: .internalParameter, spelling: "second",      preciseIdentifier: nil),
                .init(kind: .text,              spelling: ": ",          preciseIdentifier: nil),
                .init(kind: .typeIdentifier,    spelling: "SecondParameterValue", preciseIdentifier: "second-parameter-symbol-id"),
                .init(kind: .text,              spelling: ") ",          preciseIdentifier: nil),
                .init(kind: .keyword,           spelling: "throws",      preciseIdentifier: nil),
                .init(kind: .text,              spelling: "-> ",         preciseIdentifier: nil),
                .init(kind: .typeIdentifier,    spelling: "ReturnValue", preciseIdentifier: "return-value-symbol-id"),
            ],
            
            .objectiveC:  [
                .init(kind: .text,              spelling: "- (",         preciseIdentifier: nil),
                .init(kind: .typeIdentifier,    spelling: "ReturnValue", preciseIdentifier: "return-value-symbol-id"),
                .init(kind: .text,              spelling: ") ",          preciseIdentifier: nil),
                .init(kind: .identifier,        spelling: "doSomethingWithFirst", preciseIdentifier: nil),
                .init(kind: .text,              spelling: ": (",         preciseIdentifier: nil),
                .init(kind: .typeIdentifier,    spelling: "FirstParameterValue", preciseIdentifier: "first-parameter-symbol-id"),
                .init(kind: .text,              spelling: ") ",          preciseIdentifier: nil),
                .init(kind: .internalParameter, spelling: "first",       preciseIdentifier: nil),
                .init(kind: .text,              spelling: " ",           preciseIdentifier: nil),
                .init(kind: .identifier,        spelling: "andSecond",   preciseIdentifier: nil),
                .init(kind: .text,              spelling: ": (",         preciseIdentifier: nil),
                .init(kind: .typeIdentifier,    spelling: "SecondParameterValue", preciseIdentifier: "second-parameter-symbol-id"),
                .init(kind: .text,              spelling: ") ",          preciseIdentifier: nil),
                .init(kind: .internalParameter, spelling: "second",      preciseIdentifier: nil),
                .init(kind: .text,              spelling: " ",           preciseIdentifier: nil),
                .init(kind: .identifier,        spelling: "error",       preciseIdentifier: nil),
                .init(kind: .text,              spelling: ": (",         preciseIdentifier: nil),
                .init(kind: .typeIdentifier,    spelling: "NSError",     preciseIdentifier: "error-parameter-symbol-id"),
                .init(kind: .text,              spelling: " **) ",       preciseIdentifier: nil),
                .init(kind: .internalParameter, spelling: "error",       preciseIdentifier: nil),
                .init(kind: .text,              spelling: ";",           preciseIdentifier: nil),
            ]
        ])
        switch goal {
        case .quality:
            #expect(declaration.rendered(prettyFormatted: true) == """
            <pre id="declaration">
            <code class="swift-only">
                <span class="token-keyword">func</span>
                 <span class="token-identifier">doSomething</span>
                (<span class="token-externalParam">with</span>
                 <span class="token-internalParam">first</span>
                : <a class="token-typeIdentifier" href="../../../FirstParameterValue/index.html">FirstParameterValue</a>
                , <span class="token-externalParam">and</span>
                 <span class="token-internalParam">second</span>
                : <a class="token-typeIdentifier" href="../../../SecondParameterValue/index.html">SecondParameterValue</a>
                ) <span class="token-keyword">throws</span>
                -&gt; <a class="token-typeIdentifier" href="../../../ReturnValue/index.html">ReturnValue</a>
            </code>
            <code class="occ-only">- (<a class="token-typeIdentifier" href="../../../ReturnValue/index.html">ReturnValue</a>
                ) <span class="token-identifier">doSomethingWithFirst</span>
                : (<a class="token-typeIdentifier" href="../../../FirstParameterValue/index.html">FirstParameterValue</a>
                ) <span class="token-internalParam">first</span>
                 <span class="token-identifier">andSecond</span>
                : (<a class="token-typeIdentifier" href="../../../SecondParameterValue/index.html">SecondParameterValue</a>
                ) <span class="token-internalParam">second</span>
                 <span class="token-identifier">error</span>
                : (<a class="token-typeIdentifier" href="../../../../Foundation/NSError/index.html">NSError</a>
                 **) <span class="token-internalParam">error</span>
                ;</code>
            </pre>
            """)
            
        case .conciseness:
            #expect(declaration.rendered(prettyFormatted: true) == """
            <pre>
            <code>func doSomething(with first: FirstParameterValue, and second: SecondParameterValue) throws-&gt; ReturnValue</code>
            </pre>
            """)
        }
    }
    
    @Test(arguments: RenderGoal.allCases, ["Topics", "See Also"])
    func testRenderSingleLanguageGroupedSectionsWithMultiLanguageLinks(goal: RenderGoal, expectedGroupTitle: String) {
        let elements = [
            LinkedElement(
                path: URL(string: "/documentation/ModuleName/SomeClass/index.html")!,
                names: .languageSpecificSymbol([
                    .swift:      "SomeClass",
                    .objectiveC: "TLASomeClass",
                ]),
                subheadings: .languageSpecificSymbol([
                    .swift: [
                        .init(text: "class ",    kind: .decorator),
                        .init(text: "SomeClass", kind: .identifier),
                    ],
                    .objectiveC: [
                        .init(text: "class ",       kind: .decorator),
                        .init(text: "TLASomeClass", kind: .identifier),
                    ],
                ]),
                abstract: parseMarkup(string: "Some _formatted_ description of this class").first as? Paragraph
            ),
            LinkedElement(
                path: URL(string: "/documentation/ModuleName/SomeArticle/index.html")!,
                names: .single(.conceptual("Some Article")),
                subheadings: .single(.conceptual("Some Article")),
                abstract: parseMarkup(string: "Some **formatted** description of this _article_.").first as? Paragraph
            ),
            LinkedElement(
                path: URL(string: "/documentation/ModuleName/SomeClass/someMethod(with:and:)/index.html")!,
                names: .languageSpecificSymbol([
                    .swift:      "someMethod(with:and:)",
                    .objectiveC: "someMethodWithFirst:andSecond:",
                ]),
                subheadings: .languageSpecificSymbol([
                    .swift: [
                        .init(text: "func ",      kind: .decorator),
                        .init(text: "someMethod", kind: .identifier),
                        .init(text: "(",          kind: .decorator),
                        .init(text: "with",       kind: .identifier),
                        .init(text: ": Int, ",    kind: .decorator),
                        .init(text: "and",        kind: .identifier),
                        .init(text: ": String)",  kind: .decorator),
                    ],
                    .objectiveC: [
                        .init(text: "- ", kind: .decorator),
                        .init(text: "someMethodWithFirst:andSecond:", kind: .identifier),
                    ],
                ]),
                abstract: nil
            ),
        ]
        
        let renderer = makeRenderer(goal: goal, elementsToReturn: elements)
        let expectedSectionID = expectedGroupTitle.lowercased().replacingOccurrences(of: " ", with: "-")
        let groupedSection = renderer.groupedSection(named: expectedGroupTitle, groups: [
            .swift: [
                .init(title: "Group title", content: parseMarkup(string: "Some description of this group"), references: [
                    URL(string: "/documentation/ModuleName/SomeClass/index.html")!,
                    URL(string: "/documentation/ModuleName/SomeArticle/index.html")!,
                    URL(string: "/documentation/ModuleName/SomeClass/someMethod(with:and:)/index.html")!,
                ])
            ]
        ])
        
        switch goal {
        case .quality:
            #expect(groupedSection.rendered(prettyFormatted: true) == """
            <section id="\(expectedSectionID)">
            <h2>
                <a href="#\(expectedSectionID)">\(expectedGroupTitle)</a>
            </h2>
            <h3 id="group-title">
                <a href="#group-title">Group title</a>
            </h3>
            <p>Some description of this group</p>
            <ul>
                <li>
                    <a href="../../../SomeClass/index.html">
                        <code class="swift-only">
                            <span class="decorator">class </span>
                            <span class="identifier">Some<wbr/>
                                Class</span>
                        </code>
                        <code class="occ-only">
                            <span class="decorator">class </span>
                            <span class="identifier">TLASome<wbr/>
                                Class</span>
                        </code>
                        <p>Some <i>formatted</i>
                             description of this class</p>
                    </a>
                </li>
                <li>
                    <a href="../../../SomeArticle/index.html">
                        <p>Some Article</p>
                        <p>Some <b>formatted</b>
                             description of this <i>article</i>
                            .</p>
                    </a>
                </li>
                <li>
                    <a href="../../../SomeClass/someMethod(with:and:)/index.html">
                        <code class="swift-only">
                            <span class="decorator">func </span>
                            <span class="identifier">some<wbr/>
                                Method</span>
                            <span class="decorator">(</span>
                            <span class="identifier">with</span>
                            <span class="decorator">:<wbr/>
                                 Int, </span>
                            <span class="identifier">and</span>
                            <span class="decorator">:<wbr/>
                                 String)</span>
                        </code>
                        <code class="occ-only">
                            <span class="decorator">- </span>
                            <span class="identifier">some<wbr/>
                                Method<wbr/>
                                With<wbr/>
                                First:<wbr/>
                                and<wbr/>
                                Second:</span>
                        </code>
                    </a>
                </li>
            </ul>
            </section>
            """)
        case .conciseness:
            #expect(groupedSection.rendered(prettyFormatted: true) == """
            <section>
            <h2>\(expectedGroupTitle)</h2>
            <h3>Group title</h3>
            <p>Some description of this group</p>
            <ul>
                <li>
                    <a href="../../../SomeClass/index.html">
                        <code>class SomeClass</code>
                        <p>Some <i>formatted</i>
                             description of this class</p>
                    </a>
                </li>
                <li>
                    <a href="../../../SomeArticle/index.html">
                        <p>Some Article</p>
                        <p>Some <b>formatted</b>
                             description of this <i>article</i>
                            .</p>
                    </a>
                </li>
                <li>
                    <a href="../../../SomeClass/someMethod(with:and:)/index.html">
                        <code>func someMethod(with: Int, and: String)</code>
                    </a>
                </li>
            </ul>
            </section>
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
        [.quality, .conciseness]
    }
}
