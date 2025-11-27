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
            
            ## Custom discussion
            
            It explains how a developer can perform some task using this module.
            
            ### Details
            
            This subsection describes something more detailed.
            
            ## See Also
            
            - ``SomeClass``
            """),
            
            JSONFile(name: "ModuleName.symbols.json", content: makeSymbolGraph(moduleName: "ModuleName", symbols: [
                makeSymbol(id: "some-class-id", kind: .class, pathComponents: ["SomeClass"], docComment: """
                Some in-source description of this class.
                """, declaration: [
                    .init(kind: .keyword,    spelling: "class",     preciseIdentifier: nil),
                    .init(kind: .text,       spelling: " ",         preciseIdentifier: nil),
                    .init(kind: .identifier, spelling: "SomeClass", preciseIdentifier: nil),
                ]),
                makeSymbol(
                    id: "some-method-id", kind: .method, pathComponents: ["SomeClass", "someMethod(with:and:)"],
                    docComment: """
                    Some in-source description of this method.
                    
                    Further description of this method and how to use it.
                    
                    - Parameters: 
                      - first:  Description of the `first` parameter.
                      - second: Description of the `second` parameter.
                    - Returns:  Description of the return value.
                    
                    ## See Also
                    
                    - <doc:SomeArticle>
                    """,
                    signature: .init(
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
                    ),
                    declaration: [
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
                    ]
                )
            ], relationships: [
                .init(source: "some-method-id", target: "some-class-id", kind: .memberOf, targetFallback: nil)
            ])),
            
            TextFile(name: "ModuleName.md", utf8Content: """
            # ``ModuleName``
            
            Some description of this module
            
            ## Topics
            
            ### Something custom
            
            A custom _formatted_ description of this topic section
            
            - <doc:SomeArticle>
            - ``SomeClass``
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
        
        let (inputs, dataProvider) = try DocumentationContext.InputsProvider(fileManager: fileSystem)
            .inputsAndDataProvider(startingPoint: URL(fileURLWithPath: "/path/to/\(catalog.name)"), options: .init())
        
        let context = try await DocumentationContext(bundle: inputs, dataProvider: dataProvider, configuration: .init())
        
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
          <meta content="Some description of this module" name="description"/></head>
          <body>
            <noscript><main>
        <article>
            <div id="hero-module">
                <section>
                    <nav id="breadcrumbs">
                        <ul>
                            <li>ModuleName</li>
                        </ul>
                    </nav>
                    <p id="eyebrow">Framework</p>
                    <h1>Module<wbr/>
                        Name</h1>
                    <p id="abstract">Some description of this module</p>
                </section>
            </div>
            <section id="topics">
                <h2>
                    <a href="#topics">Topics</a>
                </h2>
                <h3 id="something-custom">
                    <a href="#something-custom">Something custom</a>
                </h3>
                <p>A custom <i>formatted</i>
                     description of this topic section</p>
                <ul>
                    <li>
                        <a href="../SomeArticle/index.html">Some article<p>This is an article.</p>
                        </a>
                    </li>
                    <li>
                        <a href="../SomeClass/index.html">
                            <code>
                                <span class="decorator">class </span>
                                <span class="identifier">Some<wbr/>
                                    Class</span>
                            </code>
                            <p>Some in-source description of this class.</p>
                        </a>
                    </li>
                </ul>
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
          <meta content="Some in-source description of this class." name="description"/></head>
          <body>
            <noscript><main>
        <article>
            <section>
                <nav id="breadcrumbs">
                    <ul>
                        <li>
                            <a href="../../index.html">ModuleName</a>
                        </li>
                        <li>SomeClass</li>
                    </ul>
                </nav>
                <p id="eyebrow">Class</p>
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
            <hr/>
            <section id="topics">
                <h2>
                    <a href="#topics">Topics</a>
                </h2>
                <h3 id="instance-methods">
                    <a href="#instance-methods">Instance Methods</a>
                </h3>
                <ul>
                    <li>
                        <a href="../someMethod(with:and:)/index.html">
                            <code>
                                <span class="decorator">func </span>
                                <span class="identifier">some<wbr/>
                                    Method</span>
                                <span class="decorator">(</span>
                                <span class="identifier">with</span>
                                <span class="decorator"> first:<wbr/>
                                     Int, </span>
                                <span class="identifier">and</span>
                                <span class="decorator"> second:<wbr/>
                                     String)<wbr/>
                                     -&gt;<wbr/>
                                     Bool</span>
                            </code>
                            <p>Some in-source description of this method.</p>
                        </a>
                    </li>
                </ul>
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
          <meta content="Some in-source description of this method." name="description"/></head>
          <body>
            <noscript><main>
        <article>
            <section>
                <nav id="breadcrumbs">
                    <ul>
                        <li>
                            <a href="../../../index.html">ModuleName</a>
                        </li>
                        <li>
                            <a href="../../index.html">SomeClass</a>
                        </li>
                        <li>someMethod(with:and:)</li>
                    </ul>
                </nav>
                <p id="eyebrow">Instance Method</p>
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
            <hr/>
            <section id="discussion">
                <h2>
                    <a href="#discussion">Discussion</a>
                </h2>
                <p>Further description of this method and how to use it.</p>
            </section>
            <hr/>
            <section id="see-also">
                <h2>
                    <a href="#see-also">See Also</a>
                </h2>
                <h3 id="related-documentation">
                    <a href="#related-documentation">Related Documentation</a>
                </h3>
                <ul>
                    <li>
                        <a href="../../../SomeArticle/index.html">Some article<p>This is an article.</p>
                        </a>
                    </li>
                </ul>
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
          <meta content="This is an article." name="description"/></head>
          <body>
            <noscript><main>
        <article>
            <div id="hero-article">
                <section>
                    <nav id="breadcrumbs">
                        <ul>
                            <li>
                                <a href="../../index.html">ModuleName</a>
                            </li>
                            <li>Some article</li>
                        </ul>
                    </nav>
                    <p id="eyebrow">Article</p>
                    <h1>Some article</h1>
                    <p id="abstract">This is an article.</p>
                </section>
            </div>
            <section id="custom-discussion">
                <h2>
                    <a href="#custom-discussion">Custom discussion</a>
                </h2>
                <p>It explains how a developer can perform some task using this module.</p>
                <h3 id="details">
                    <a href="#details">Details</a>
                </h3>
                <p>This subsection describes something more detailed.</p>
            </section>
            <hr/>
            <section id="see-also">
                <h2>
                    <a href="#see-also">See Also</a>
                </h2>
                <h3 id="related-documentation">
                    <a href="#related-documentation">Related Documentation</a>
                </h3>
                <ul>
                    <li>
                        <a href="../../SomeClass/index.html">
                            <code>
                                <span class="decorator">class </span>
                                <span class="identifier">Some<wbr/>
                                    Class</span>
                            </code>
                            <p>Some in-source description of this class.</p>
                        </a>
                    </li>
                </ul>
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
