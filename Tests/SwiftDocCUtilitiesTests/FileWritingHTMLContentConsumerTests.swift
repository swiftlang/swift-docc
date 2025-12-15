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
            
            This is an _formatted_ article.
            
            @DeprecationSummary {
              Description of why this _article_ is deprecated.
            }
            
            ## Custom discussion
            
            It explains how a developer can perform some task using ``SomeClass`` in this module.
            
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
                makeSymbol(id: "some-protocol-id", kind: .protocol, pathComponents: ["SomeProtocol"], docComment: """
                Some in-source description of this protocol.
                """, declaration: [
                    .init(kind: .keyword,    spelling: "protocol",     preciseIdentifier: nil),
                    .init(kind: .text,       spelling: " ",            preciseIdentifier: nil),
                    .init(kind: .identifier, spelling: "SomeProtocol", preciseIdentifier: nil),
                ]),
                makeSymbol(
                    id: "some-method-id", kind: .method, pathComponents: ["SomeClass", "someMethod(with:and:)"],
                    docComment: """
                    Some in-source description of this method.
                    
                    Further description of this method and how to use it.
                    
                    @DeprecationSummary {
                      Some **formatted** description of why this method is deprecated.
                    }
                    
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
                .init(source: "some-method-id", target: "some-class-id",    kind: .memberOf,   targetFallback: nil),
                .init(source: "some-class-id",  target: "some-protocol-id", kind: .conformsTo, targetFallback: nil)
            ])),
            
            TextFile(name: "ModuleName.md", utf8Content: """
            # ``ModuleName``
            
            Some **formatted** description of this module
            
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
           ╰─ modulename/
              ├─ index.html
              ├─ somearticle/
              │  ╰─ index.html
              ├─ someclass/
              │  ├─ index.html
              │  ╰─ somemethod(with:and:)/
              │     ╰─ index.html
              ╰─ someprotocol/
                 ╰─ index.html
        """)
        
        try assert(readHTML: fileSystem.contents(of: URL(fileURLWithPath: "/output-dir/documentation/modulename/index.html")), matches: """
        <html>
          <head>
            <meta charset="utf-8" />
            <link rel="icon" href="/favicon.ico" />
            <title>ModuleName</title>
            <script>var baseUrl = "/"</script>
            <meta content="Some formatted description of this module" name="description"/>
          </head>
          <body>
            <noscript>
              <article>
                <section>
                  <ul>
                    <li>ModuleName</li>
                  </ul>
                  <p>Framework</p>
                  <h1>ModuleName</h1>
                  <p>Some <b>formatted</b> description of this module</p>
                </section>
                <h2>Topics</h2>
                <h3>Something custom</h3>
                <p>A custom <i>formatted</i> description of this topic section</p>
                <ul>
                  <li>
                    <a href="somearticle/index.html">
                      <p>Some article</p>
                      <p>This is an <i>formatted</i> article.</p>
                    </a>
                  </li>
                  <li>
                    <a href="someclass/index.html">
                      <code>class SomeClass</code>
                      <p>Some in-source description of this class.</p>
                    </a>
                  </li>
                </ul>
                <h3>Protocols</h3>
                <ul>
                  <li>
                    <a href="someprotocol/index.html">
                      <code>protocol SomeProtocol</code>
                      <p>Some in-source description of this protocol.</p>
                    </a>
                  </li>
                </ul>
              </article>
            </noscript>
            <div id="app"></div>
          </body>
        </html>
        """)
        
        try assert(readHTML: fileSystem.contents(of: URL(fileURLWithPath: "/output-dir/documentation/modulename/someclass/index.html")), matches: """
        <html>
          <head>
            <meta charset="utf-8" />
            <link rel="icon" href="/favicon.ico" />
            <title>SomeClass</title>
            <script>var baseUrl = "/"</script>
            <meta content="Some in-source description of this class." name="description"/>
          </head>
          <body>
            <noscript>
              <article>
                <section>
                  <ul>
                    <li>
                      <a href="../index.html">ModuleName</a>
                    </li>
                    <li>SomeClass</li>
                  </ul>
                  <p>Class</p>
                  <h1>SomeClass</h1>
                  <p>Some in-source description of this class.</p>
                  <pre>
                    <code>class SomeClass</code>
                  </pre>
                </section>
                <h2>Mentioned In</h2>
                <ul>
                  <li>
                    <a href="../somearticle/index.html">Some article</a>
                  </li>
                </ul>
                <h2>Topics</h2>
                <h3>Instance Methods</h3>
                <ul>
                  <li>
                    <a href="somemethod(with:and:)/index.html">
                      <code>func someMethod(with first: Int, and second: String) -&gt; Bool</code>
                      <p>Some in-source description of this method.</p>
                    </a>
                  </li>
                </ul>
                <h2>Relationships</h2>
                <h3>Conforms To</h3>
                <ul>
                  <li>
                    <a href="../someprotocol/index.html">
                      <code>SomeProtocol</code>
                    </a>
                  </li>
                </ul>
              </article>
            </noscript>
            <div id="app"></div>
          </body>
        </html>
        """)
        
        try assert(readHTML: fileSystem.contents(of: URL(fileURLWithPath: "/output-dir/documentation/modulename/someclass/somemethod(with:and:)/index.html")), matches: """
        <html>
          <head>
            <meta charset="utf-8" />
            <link rel="icon" href="/favicon.ico" />
            <title>someMethod(with:and:)</title>
            <script>var baseUrl = "/"</script>
            <meta content="Some in-source description of this method." name="description"/>
          </head>
          <body>
            <noscript>
              <article>
              <section>
                <ul>
                  <li>
                    <a href="../../index.html">ModuleName</a>
                  </li>
                  <li>
                    <a href="../index.html">SomeClass</a>
                  </li>
                  <li>someMethod(with:and:)</li>
                </ul>
                <p>Instance Method</p>
                <h1>someMethod(with:and:)</h1>
                <p>Some in-source description of this method.</p>
                <pre>
                  <code>func someMethod(with first: Int, and second: String) -&gt; Bool</code>
                </pre>
                <blockquote class="aside deprecated">
                  <p class="label">Deprecated</p>
                  <p>Some <b>formatted</b> description of why this method is deprecated.</p>
                </blockquote>
              </section>
              <h2>Parameters</h2>
              <dl>
                <dt>
                  <code>first</code>
                </dt>
                <dd>
                  <p>Description of the <code>first</code> parameter.</p>
                </dd>
                <dt>
                  <code>second</code>
                </dt>
                <dd>
                  <p>Description of the <code>second</code> parameter.</p>
                </dd>
              </dl>
              <h2>Return Value</h2>
              <p>Description of the return value.</p>
              <h2>Discussion</h2>
              <p>Further description of this method and how to use it.</p>
              <h2>See Also</h2>
              <h3>Related Documentation</h3>
              <ul>
                <li>
                  <a href="../../somearticle/index.html">
                    <p>Some article</p>
                    <p>This is an <i>formatted</i> article.</p>
                  </a>
                </li>
              </ul>
              </article>
            </noscript>
            <div id="app"></div>
          </body>
        </html>
        """)
        
        try assert(readHTML: fileSystem.contents(of: URL(fileURLWithPath: "/output-dir/documentation/modulename/somearticle/index.html")), matches: """
        <html>
          <head>
            <meta charset="utf-8" />
            <link rel="icon" href="/favicon.ico" />
            <title>Some article</title>
            <script>var baseUrl = "/"</script>
            <meta content="This is an formatted article." name="description"/>
          </head>
          <body>
            <noscript>
              <article>
                <section>
                  <ul>
                    <li>
                      <a href="../index.html">ModuleName</a>
                    </li>
                    <li>Some article</li>
                  </ul>
                  <p>Article</p>
                  <h1>Some article</h1>
                  <p>This is an <i>formatted</i> article.</p>
                  <blockquote class="aside deprecated">
                    <p class="label">Deprecated</p>
                    <p>Description of why this <i>article</i> is deprecated.</p>
                  </blockquote>
                </section>
                <h2>Custom discussion</h2>
                <p>It explains how a developer can perform some task using <a href="../someclass/index.html"><code>SomeClass</code></a> in this module.</p>
                <h3>Details</h3>
                <p>This subsection describes something more detailed.</p>
                <h2>See Also</h2>
                <h3>Related Documentation</h3>
                <ul>
                  <li>
                    <a href="../someclass/index.html">
                      <code>class SomeClass</code>
                      <p>Some in-source description of this class.</p>
                    </a>
                  </li>
                </ul>
              </article>
            </noscript>
            <div id="app"></div>
          </body>
        </html>
        """)
        
        try assert(readHTML: fileSystem.contents(of: URL(fileURLWithPath: "/output-dir/documentation/modulename/someprotocol/index.html")), matches: """
        <html>
          <head>
            <meta charset="utf-8" />
            <link rel="icon" href="/favicon.ico" />
            <title>SomeProtocol</title>
            <script>var baseUrl = "/"</script>
            <meta content="Some in-source description of this protocol." name="description"/>
          </head>
          <body>
            <noscript>
              <article>
                <section>
                  <ul>
                    <li>
                      <a href="../index.html">
                        ModuleName</a>
                      </li>
                    <li>
                    SomeProtocol</li>
                  </ul>
                  <p>Protocol</p>
                  <h1>SomeProtocol</h1>
                  <p>Some in-source description of this protocol.</p>
                  <pre>
                    <code>protocol SomeProtocol</code>
                  </pre>
                </section>
                <h2>Relationships</h2>
                <h3>Conforming Types</h3>
                <ul>
                  <li>
                    <a href="../someclass/index.html">
                      <code>SomeClass</code>
                    </a>
                  </li>
                </ul>
              </article>
            </noscript>
            <div id="app"></div>
          </body>
        </html>
        """)
    }

    func testAddsTagsToTemplateIfMissing() async throws {
        let catalog = Folder(name: "Something.docc", content: [
            TextFile(name: "RootArticle.md", utf8Content: """
            # A single article
            
            This is an _formatted_ article that becomes the root page (because there's only one page).
            """)
        ])
        
        for withTitleTag in [true, false] {
            for withNoScriptTag in [true, false] {
                let maybeTitleTag = withTitleTag ? "<title>Documentation</title>" : ""
                let maybeNoScriptTag = withNoScriptTag ? """
                  <noscript>
                    <p>Some existing information inside the no script tag</p>
                  </noscript>
                """ : ""
                
                let htmlTemplate = TextFile(name: "index.html", utf8Content: """
                <html>
                  <head>
                    <meta charset="utf-8" />
                    <link rel="icon" href="/favicon.ico" />
                    \(maybeTitleTag)
                  </head>
                  <body>
                  \(maybeNoScriptTag)
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
                   ╰─ rootarticle/
                      ╰─ index.html
                """)
                
                try assert(readHTML: fileSystem.contents(of: URL(fileURLWithPath: "/output-dir/documentation/rootarticle/index.html")), matches: """
                <html>
                  <head>
                    <meta charset="utf-8" />
                    <link rel="icon" href="/favicon.ico" />
                    <title>A single article</title>
                    <meta content="This is an formatted article that becomes the root page (because there’s only one page)." name="description"/>
                  </head>
                  <body>
                    <noscript>
                      <article>
                        <section>
                          <ul>
                            <li>RootArticle</li>
                          </ul>
                          <p>
                          Article</p>
                          <h1>RootArticle</h1>
                          <p>This is an <i> formatted</i> article that becomes the root page (because there’s only one page).</p>
                        </section>
                      </article>
                    </noscript>
                    <div id="app"></div>
                  </body>
                </html>
                """)
            }
        }
    }
}

// MARK: Helpers

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

func assert(readHTML: Data, matches expectedHTML: String, file: StaticString = #filePath, line: UInt = #line) {
    // XMLNode on macOS and Linux pretty print with different indentation.
    // To compare the XML structure without getting false positive failures because of indentation and other formatting differences,
    // we explicitly process each string into an easy-to-compare format.
    func formatForTestComparison(_ xmlString: String) -> String {
        // This is overly simplified and won't result in "pretty" XML for general use but sufficient for test content comparisons
        xmlString
            // Put each tag on its own line
            .replacingOccurrences(of: ">", with: ">\n")
            // Remove leading indentation
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
            // Explicitly escape a few HTML characters that appear in the test content
            .replacingOccurrences(of: "–", with: "&#x2013;") // en-dash
            .replacingOccurrences(of: "—", with: "&#x2014;") // em-dash
    }
    
    XCTAssertEqual(
        formatForTestComparison(String(decoding: readHTML, as: UTF8.self)),
        formatForTestComparison(expectedHTML),
        file: file,
        line: line
    )
}
