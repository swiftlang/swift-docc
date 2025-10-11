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
                names: .single(.symbol("ModuleName")),
                subheadings: .single(.symbol([.init(text: "ModuleName", kind: .identifier)])),
                abstract: nil
            ),
            LinkedElement(
                path: URL(string: "/documentation/ModuleName/Something/index.html")!,
                names: .languageSpecificSymbol([
                    "swift": "Something",
                    "occ": "TLASomething",
                ]),
                subheadings: .languageSpecificSymbol([
                    "swift": [
                        .init(text: "class ", kind: .decorator),
                        .init(text: "Something", kind: .identifier),
                    ],
                    "occ": [
                        .init(text: "class ", kind: .decorator),
                        .init(text: "TLASomething", kind: .identifier),
                    ],
                ]),
                abstract: nil
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
    
    func testRenderSingleLanguageParameters() throws {
        let parameters = makeRenderer().parameters([
            "swift": [
                .init(name: "First", content: parseMarkup(string: "Some _formatted_ description with `code`")),
                .init(name: "Second", content: parseMarkup(string: """
                Some **other** _formatted_ description

                That spans two paragraphs
                """)),
            ]
        ])
        XCTAssertEqual(parameters.rendered(prettyFormatted: true), """
        <section id="parameters">
        <h2>
            <a href="#parameters">Parameters</a>
        </h2>
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
    
    func testRenderLanguageSpecificParameters() throws {
        let parameters = makeRenderer().parameters([
            "swift": [
                .init(name: "FirstCommon", content: parseMarkup(string: "Available in both languages")),
                .init(name: "SwiftOnly", content: parseMarkup(string: "Only available in Swift")),
                .init(name: "SecondCommon", content: parseMarkup(string: "Also available in both languages")),
            ],
            "occ": [
                .init(name: "FirstCommon", content: parseMarkup(string: "Available in both languages")),
                .init(name: "SecondCommon", content: parseMarkup(string: "Also available in both languages")),
                .init(name: "ObjectiveCOnly", content: parseMarkup(string: "Only available in Objective-C")),
            ],
        ])
        XCTAssertEqual(parameters.rendered(prettyFormatted: true), """
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
    
    func testRenderManyLanguageSpecificParameters() throws {
        let parameters = makeRenderer().parameters([
            "swift": [
                .init(name: "First", content: parseMarkup(string: "Some description")),
            ],
            "occ": [
                .init(name: "Second", content: parseMarkup(string: "Some description")),
            ],
            "data": [
                .init(name: "Third", content: parseMarkup(string: "Some description")),
            ],
        ])
        XCTAssertEqual(parameters.rendered(prettyFormatted: true), """
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
    
    func testRenderSwiftDeclaration() throws {
        let symbolPaths = [
            "first-parameter-symbol-id":  URL(string: "/documentation/ModuleName/FirstParameterValue/index.html")!,
            "second-parameter-symbol-id": URL(string: "/documentation/ModuleName/SecondParameterValue/index.html")!,
            "return-value-symbol-id":     URL(string: "/documentation/ModuleName/ReturnValue/index.html")!,
        ]
        
        let declaration = makeRenderer(pathsToReturn: symbolPaths).declaration([
            "swift":  [
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
        XCTAssertEqual(declaration.rendered(prettyFormatted: true), """
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
    }
    
    func testRenderLanguageSpecificDeclarations() throws {
        let symbolPaths = [
            "first-parameter-symbol-id":  URL(string: "/documentation/ModuleName/FirstParameterValue/index.html")!,
            "second-parameter-symbol-id": URL(string: "/documentation/ModuleName/SecondParameterValue/index.html")!,
            "return-value-symbol-id":     URL(string: "/documentation/ModuleName/ReturnValue/index.html")!,
            "error-parameter-symbol-id":  URL(string: "/documentation/Foundation/NSError/index.html")!,
        ]
        
        let declaration = makeRenderer(pathsToReturn: symbolPaths).declaration([
            "swift":  [
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
            
            "occ":  [
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
        XCTAssertEqual(declaration.rendered(prettyFormatted: true), """
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
    }
    
    // MARK: -
    
    private func makeRenderer(
        elementsToReturn: [LinkedElement] = [],
        pathsToReturn: [String: URL] = [:],
        assetsToReturn: [String: LinkedAsset] = [:],
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> MarkupRenderer<some LinkProvider> {
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
        
        return MarkupRenderer(
            path: path,
            linkProvider: MultiValueLinkProvider(
                elementsToReturn: elementsByURL,
                pathsToReturn: pathsToReturn,
                assetsToReturn: assetsToReturn
            )
        )
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
}
