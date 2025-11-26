/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/


import Foundation
@testable import SwiftDocCUtilities
import SwiftDocC
import SymbolKit
import XCTest
import SwiftDocCTestUtilities

final class FileWritingHTMLContentConsumerTests: XCTestCase {
    
    func testWritesContentInsideHTMLTemplate() async throws {
        let catalog = Folder(name: "ModuleName.docc", content: [
            TextFile(name: "SomeArticle.md", utf8Content: """
            # Some article
            
            This is an article.
            
            It explains how a developer can perform some task using this module.
            """),
            
            JSONFile(name: "ModuleName.symbols.json", content: makeSymbolGraph(moduleName: "ModuleName", symbols: [
                makeSymbol(id: "some-class-id", kind: .class, pathComponents: ["SomeClass"], docComment: """
                Some in-source description of this class.
                """, otherMixins: [
                    SymbolGraph.Symbol.DeclarationFragments(declarationFragments: [
                        .init(kind: .keyword,    spelling: "class",     preciseIdentifier: nil),
                        .init(kind: .text,       spelling: " ",         preciseIdentifier: nil),
                        .init(kind: .identifier, spelling: "SomeClass", preciseIdentifier: nil),
                    ])
                ]),
                makeSymbol(id: "some-method-id", kind: .method, pathComponents: ["SomeClass", "someMethod(with:and:)"], docComment: """
                Some in-source description of this method.
                
                Further description of this method and how to use it.
                
                - Parameters: 
                  - first:  Description of the `first` parameter.
                  - second: Description of the `second` parameter.
                - Returns:  Description of the return value.
                """, otherMixins: [
                    SymbolGraph.Symbol.DeclarationFragments(declarationFragments: [
                        .init(kind: .keyword,           spelling: "func",       preciseIdentifier: nil),
                        .init(kind: .text,              spelling: " ",          preciseIdentifier: nil),
                        .init(kind: .identifier,        spelling: "someMethod", preciseIdentifier: nil),
                        .init(kind: .text,              spelling: "(",          preciseIdentifier: nil),
                        .init(kind: .externalParameter, spelling: "with",       preciseIdentifier: nil),
                        .init(kind: .text,              spelling: " ",          preciseIdentifier: nil),
                        .init(kind: .internalParameter, spelling: "first",      preciseIdentifier: nil),
                        .init(kind: .text,              spelling: ": ",         preciseIdentifier: nil),
                        .init(kind: .typeIdentifier,    spelling: "Int",        preciseIdentifier: "s:Si"),
                        .init(kind: .text,              spelling: ", ",         preciseIdentifier: nil),
                        .init(kind: .externalParameter, spelling: "and",        preciseIdentifier: nil),
                        .init(kind: .text,              spelling: " ",          preciseIdentifier: nil),
                        .init(kind: .internalParameter, spelling: "second",     preciseIdentifier: nil),
                        .init(kind: .text,              spelling: ": ",         preciseIdentifier: nil),
                        .init(kind: .typeIdentifier,    spelling: "String",     preciseIdentifier: "s:SS"),
                        .init(kind: .text,              spelling: ") -> ",      preciseIdentifier: nil),
                        .init(kind: .typeIdentifier,    spelling: "Bool",       preciseIdentifier: "s:Sb"),
                    ]),
                    SymbolGraph.Symbol.FunctionSignature(
                        parameters: [
                            .init(name: "first", externalName: "with", declarationFragments: [
                                .init(kind: .identifier,     spelling: "first",  preciseIdentifier: nil),
                                .init(kind: .text,           spelling: ": ",     preciseIdentifier: nil),
                                .init(kind: .typeIdentifier, spelling: "Int",    preciseIdentifier: "s:Si"),
                            ], children: []),
                            .init(name: "second", externalName: "and", declarationFragments: [
                                .init(kind: .identifier,     spelling: "first",  preciseIdentifier: nil),
                                .init(kind: .text,           spelling: ": ",     preciseIdentifier: nil),
                                .init(kind: .typeIdentifier, spelling: "String", preciseIdentifier: "s:Ss"),
                            ], children: [])
                        ],
                        returns: [
                            .init(kind: .typeIdentifier,     spelling: "Bool",    preciseIdentifier: "s:Sb"),
                        ]
                    )
                ])
            ], relationships: [
                .init(source: "some-method-id", target: "some-class-id", kind: .memberOf, targetFallback: nil)
            ])),
            
            TextFile(name: "ModuleName.md", utf8Content: """
            # ``ModuleName``
            
            Some description of this module
            """)
        ])
        
        let htmlTemplate = TextFile(name: "index.html", utf8Content: """
        <html>
          <head>
            <meta charset="utf-8" />
            <link rel="icon" href="/favicon.ico" />
            <title>Documentation</title>
            <script>var baseUrl = "/"</script>
          </head>
          <body>
            <noscript>
              <p>Some existing information inside the no script tag</p>
            </noscript>
            <div id="app"></div>
          </body>
        </html>
        """)
        
        let fileSystem = try TestFileSystem(folders: [
            Folder(name: "path", content: [
                Folder(name: "to", content: [
                    catalog
                ])
            ]),
            Folder(name: "template", content: [
                htmlTemplate
            ]),
            Folder(name: "output-dir", content: [])
        ])
        
        let (bundle, dataProvider) = try DocumentationContext.InputsProvider(fileManager: fileSystem)
            .inputsAndDataProvider(startingPoint: URL(fileURLWithPath: "/path/to/\(catalog.name)"), options: .init())
        
        let context = try await DocumentationContext(bundle: bundle, dataProvider: dataProvider, configuration: .init())
        
        let htmlConsumer = try FileWritingHTMLContentConsumer(
            targetFolder: URL(fileURLWithPath: "/output-dir"),
            fileManager: fileSystem,
            htmlTemplate: URL(fileURLWithPath: "/template/index.html"),
            prettyPrintOutput: true
        )
        
        _ = try ConvertActionConverter.convert(
            context: context,
            outputConsumer: TestOutputConsumer(),
            htmlContentConsumer: htmlConsumer,
            sourceRepository: nil,
            emitDigest: false,
            documentationCoverageOptions: .noCoverage
        )
        
        // Because the TestOutputConsumer below, doesn't create any files, we only expect the HTML files in the output directory
        XCTAssertEqual(fileSystem.dump(subHierarchyFrom: "/output-dir"), """
        output-dir/
        ╰─ documentation/
           ╰─ ModuleName/
              ├─ SomeArticle/
              │  ╰─ index.html
              ├─ SomeClass/
              │  ├─ index.html
              │  ╰─ someMethod(with:and:)/
              │     ╰─ index.html
              ╰─ index.html
        """)
        
        
        XCTAssertEqual(try XCTUnwrap(String(data: fileSystem.contents(of: URL(fileURLWithPath: "/output-dir/documentation/ModuleName/index.html")), encoding: .utf8)), """
        <html>
          <head>
            <meta charset="utf-8" />
            <link rel="icon" href="/favicon.ico" />
            <title>ModuleName</title>
            <script>var baseUrl = "/"</script>
          </head>
          <body>
            <noscript><main>
        <article>
            <div id="hero-module">
                <section>
                    <header>
                        <nav id="breadcrumbs">
                            <ul>
                                <li>ModuleName</li>
                            </ul>
                        </nav>
                        <span class="eyebrow">Framework</span>
                    </header>
                    <h1>Module<wbr/>
                        Name</h1>
                    <p id="abstract">Some description of this module</p>
                    <pre id="declaration"/>
                </section>
            </div>
            <section>
                <h2 id="Topics">
                    <a href="#Topics">Topics</a>
                </h2>
                <h3 id="Classes">
                    <a href="#Classes">Classes</a>
                </h3>
                <div class="link-block">
                    <a href="SomeClass/index.html">
                        <code class="swift-only">
                            <span class="identifier">Some<wbr/>
                                Class</span>
                        </code>
                    </a>
                    <p>Some in-source description of this class.</p>
                </div>
            </section>
        </article>
        </main></noscript>
            <div id="app"></div>
          </body>
        </html>
        """)
        
        XCTAssertEqual(try XCTUnwrap(String(data: fileSystem.contents(of: URL(fileURLWithPath: "/output-dir/documentation/ModuleName/SomeClass/index.html")), encoding: .utf8)), """
        <html>
          <head>
            <meta charset="utf-8" />
            <link rel="icon" href="/favicon.ico" />
            <title>SomeClass</title>
            <script>var baseUrl = "/"</script>
          </head>
          <body>
            <noscript><main>
        <article>
            <section class="separated">
                <header>
                    <nav id="breadcrumbs">
                        <ul>
                            <li>SomeClass</li>
                        </ul>
                    </nav>
                    <span class="eyebrow">Class</span>
                </header>
                <h1>Some<wbr/>
                    Class</h1>
                <p id="abstract">Some in-source description of this class.</p>
                <pre id="declaration">
                    <code>
                        <span class="token-keyword">class</span>
                         <span class="token-identifier">SomeClass</span>
                    </code>
                </pre>
            </section>
            <section>
                <h2 id="Topics">
                    <a href="#Topics">Topics</a>
                </h2>
                <h3 id="Instance-Methods">
                    <a href="#Instance-Methods">Instance Methods</a>
                </h3>
                <div class="link-block">
                    <a href="someMethod(with:and:)/index.html">
                        <code class="swift-only">
                            <span class="identifier">some<wbr/>
                                Method(<wbr/>
                                with:<wbr/>
                                and:)</span>
                        </code>
                    </a>
                    <p>Some in-source description of this method.</p>
                </div>
            </section>
        </article>
        </main></noscript>
            <div id="app"></div>
          </body>
        </html>
        """)
        
        XCTAssertEqual(try XCTUnwrap(String(data: fileSystem.contents(of: URL(fileURLWithPath: "/output-dir/documentation/ModuleName/SomeClass/someMethod(with:and:)/index.html")), encoding: .utf8)), """
        <html>
          <head>
            <meta charset="utf-8" />
            <link rel="icon" href="/favicon.ico" />
            <title>someMethod(with:and:)</title>
            <script>var baseUrl = "/"</script>
          </head>
          <body>
            <noscript><main>
        <article>
            <section class="separated">
                <header>
                    <nav id="breadcrumbs">
                        <ul>
                            <li>someMethod(with:and:)</li>
                        </ul>
                    </nav>
                    <span class="eyebrow">Instance Method</span>
                </header>
                <h1>some<wbr/>
                    Method(<wbr/>
                    with:<wbr/>
                    and:)</h1>
                <p id="abstract">Some in-source description of this method.</p>
                <pre id="declaration">
                    <code>
                        <span class="token-keyword">func</span>
                         <span class="token-identifier">someMethod</span>
                        (<span class="token-externalParam">with</span>
                         <span class="token-internalParam">first</span>
                        : <span class="token-typeIdentifier">Int</span>
                        , <span class="token-externalParam">and</span>
                         <span class="token-internalParam">second</span>
                        : <span class="token-typeIdentifier">String</span>
                        ) -&gt; <span class="token-typeIdentifier">Bool</span>
                    </code>
                </pre>
            </section>
            <section id="parameters">
                <h2>
                    <a href="#parameters">Parameters</a>
                </h2>
                <dl>
                    <dt>
                        <code>first</code>
                    </dt>
                    <dd>
                        <p>Description of the <code>first</code>
                             parameter.</p>
                    </dd>
                    <dt>
                        <code>second</code>
                    </dt>
                    <dd>
                        <p>Description of the <code>second</code>
                             parameter.</p>
                    </dd>
                </dl>
            </section>
            <section id="return-value">
                <h2>
                    <a href="#return-value">Return Value</a>
                </h2>
                <p>Description of the return value.</p>
            </section>
            <section>
                <h2 id="Discussion">
                    <a href="#Discussion">Discussion</a>
                </h2>
                <p>Further description of this method and how to use it.</p>
            </section>
        </article>
        </main></noscript>
            <div id="app"></div>
          </body>
        </html>
        """)
        
        XCTAssertEqual(try XCTUnwrap(String(data: fileSystem.contents(of: URL(fileURLWithPath: "/output-dir/documentation/ModuleName/SomeArticle/index.html")), encoding: .utf8)), """
        <html>
          <head>
            <meta charset="utf-8" />
            <link rel="icon" href="/favicon.ico" />
            <title>Some article</title>
            <script>var baseUrl = "/"</script>
          </head>
          <body>
            <noscript><main>
        <article>
            <div id="hero-article">
                <section>
                    <header>
                        <nav id="breadcrumbs">
                            <ul>
                                <li>Some article</li>
                            </ul>
                        </nav>
                        <span class="eyebrow">Article</span>
                    </header>
                    <h1>Some article</h1>
                    <p id="abstract">This is an article.</p>
                </section>
            </div>
            <section>
                <h2 id="Overview">
                    <a href="#Overview">Overview</a>
                </h2>
                <p>It explains how a developer can perform some task using this module.</p>
            </section>
        </article>
        </main></noscript>
            <div id="app"></div>
          </body>
        </html>
        """)
    }

}

private class TestOutputConsumer: ConvertOutputConsumer, ExternalNodeConsumer {
    func consume(renderNode: RenderNode) throws { }
    func consume(assetsInBundle bundle: DocumentationBundle) throws { }
    func consume(linkableElementSummaries: [LinkDestinationSummary]) throws { }
    func consume(indexingRecords: [IndexingRecord]) throws { }
    func consume(assets: [RenderReferenceType: [any RenderReference]]) throws { }
    func consume(benchmarks: Benchmark) throws { }
    func consume(documentationCoverageInfo: [CoverageDataEntry]) throws { }
    func consume(renderReferenceStore: RenderReferenceStore) throws { }
    func consume(buildMetadata: BuildMetadata) throws { }
    func consume(linkResolutionInformation: SerializableLinkResolutionInformation) throws { }
    func consume(externalRenderNode: ExternalRenderNode) throws { }
}
