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
        let catalog = Folder(name: "unit-test.docc", content: [
            JSONFile(name: "ModuleName.symbols.json", content: makeSymbolGraph(moduleName: "ModuleName", symbols: [
                makeSymbol(id: "some-symbol-id", kind: .class, pathComponents: ["SomeClass"], docComment: """
                Some in-source description of this class
                """, otherMixins: [
                    SymbolGraph.Symbol.DeclarationFragments.init(declarationFragments: [
                        .init(kind: .keyword,    spelling: "class",     preciseIdentifier: nil),
                        .init(kind: .text,       spelling: " ",         preciseIdentifier: nil),
                        .init(kind: .identifier, spelling: "SomeClass", preciseIdentifier: nil),
                    ])
                ])
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
        XCTAssertEqual(fileSystem.dump(subHierarchyFrom: "/output"), """
        output-dir/
        ╰─ documentation/
           ╰─ ModuleName/
              ├─ SomeClass/
              │  ╰─ index.html
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
                                <li>
                                    <span class="swift-only">ModuleName</span>
                                </li>
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
                    <p>Some in-source description of this class</p>
                </div>
            </section>
        </article>
        </main></noscript>
            <div id="app"></div>
          </body>
        </html>
        """)
        
        // FIXME: This output contains some unexpected duplication for the declaration.
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
                            <li>
                                <span class="swift-only">SomeClass</span>
                            </li>
                        </ul>
                    </nav>
                    <span class="eyebrow">Class</span>
                </header>
                <h1>Some<wbr/>
                    Class</h1>
                <p id="abstract">Some in-source description of this class</p>
                <pre id="declaration">
                    <code>
                        <span class="token-keyword">class</span>
                         <span class="token-identifier">SomeClass</span>
                    </code>
                </pre>
                <pre class="swift-only">
                    <code>
                        <span class="token-keyword">class</span>
                        <span class="token-text"> </span>
                        <span class="token-identifier">SomeClass</span>
                    </code>
                </pre>
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
