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
              ╰─ someclass/
                 ├─ index.html
                 ╰─ somemethod(with:and:)/
                    ╰─ index.html
        """)
        
        try assert(readHTML: fileSystem.contents(of: URL(fileURLWithPath: "/output-dir/documentation/modulename/index.html")), matches: """
        <html>
          <head>
            <meta charset="utf-8" />
            <link rel="icon" href="/favicon.ico" />
            <title>ModuleName</title>
            <script>var baseUrl = "/"</script>
          <meta content="Some formatted description of this module" name="description"/></head>
          <body>
            <noscript>
              <article>
                <section>
                  <h1>ModuleName</h1>
                  <p>Some <b>formatted</b> description of this module</p>
                </section>
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
          <meta content="Some in-source description of this class." name="description"/></head>
          <body>
            <noscript>
              <article>
                <section>
                  <h1>SomeClass</h1>
                  <p>Some in-source description of this class.</p>
                </section>
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
          <meta content="Some in-source description of this method." name="description"/></head>
          <body>
            <noscript>
              <article>
                <section>
                  <h1>someMethod(with:and:)</h1>
                  <p>Some in-source description of this method.</p>
                </section>
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
          <meta content="This is an formatted article." name="description"/></head>
          <body>
            <noscript>
              <article>
                <section>
                  <h1>Some article</h1>
                  <p>This is an <i>formatted</i> article.</p>
                </section>
              </article>
            </noscript>
            <div id="app"></div>
          </body>
        </html>
        """)
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

private func assert(readHTML: Data, matches expectedHTML: String, file: StaticString = #filePath, line: UInt = #line) {
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
