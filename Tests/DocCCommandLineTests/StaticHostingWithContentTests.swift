/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
import Foundation
@testable import SwiftDocC
@testable import DocCCommandLine
import DocCTestUtilities

class StaticHostingWithContentTests: XCTestCase {

    func testIncludesBasePathInPerPageIndexHTMLFile() async throws {
        let catalog = Folder(name: "Something.docc", content: [
            TextFile(name: "RootArticle.md", utf8Content: """
            # A single article
            
            This is a _formatted_ article that becomes the root page (because there is only one page).
            """),
            
            TextFile(name: "header.html", utf8Content: """
            <p>Some header content</p>
            """),
            TextFile(name: "footer.html", utf8Content: """
            <p>Some footer content</p>
            """),
        ])
        let htmlTemplateContent = """
        <html>
          <head>
            <meta charset="utf-8" />
            <link rel="icon" href="{{BASE_PATH}}/favicon.ico" />
            <title>Documentation</title>
          </head>
          <body>
            <noscript>
              <p>Some existing information inside the no script tag</p>
            </noscript>
            <div id="app"></div>
          </body>
        </html>
        """
        
        let fileSystem = try TestFileSystem(folders: [
            Folder(name: "path", content: [
                Folder(name: "to", content: [
                    catalog
                ])
            ]),
            Folder(name: "template", content: [
                TextFile(name: "index.html", utf8Content: htmlTemplateContent.replacingOccurrences(of: "{{BASE_PATH}}", with: "")),
                TextFile(name: "index-template.html", utf8Content: htmlTemplateContent),
            ]),
            Folder(name: "output-dir", content: [])
        ])
        
        let basePath = "some/test/base-path"
        
        for includeHTMLContent in [true, false] {
            
            var action = try ConvertAction(
                documentationBundleURL: URL(fileURLWithPath: "/path/to/\(catalog.name)"),
                outOfProcessResolver: nil,
                analyze: false,
                targetDirectory: URL(fileURLWithPath: "/output-dir"),
                htmlTemplateDirectory: URL(fileURLWithPath: "/template"),
                emitDigest: false,
                currentPlatforms: nil,
                buildIndex: false,
                fileManager: fileSystem,
                temporaryDirectory: URL(fileURLWithPath: "/tmp"),
                experimentalEnableCustomTemplates: true,
                transformForStaticHosting: true,
                includeContentInEachHTMLFile: includeHTMLContent,
                hostingBasePath: basePath
            )
            // The old `Indexer` type doesn't work with virtual file systems.
            action._completelySkipBuildingIndex = true
            
            _ = try await action.perform(logHandle: .none)
            
            // Because the TestOutputConsumer below, doesn't create any files, we only expect the HTML files in the output directory
            XCTAssertEqual(fileSystem.dump(subHierarchyFrom: "/output-dir"), """
            output-dir/
            ├─ data/
            │  ╰─ documentation/
            │     ╰─ rootarticle.json
            ├─ documentation/
            │  ╰─ rootarticle/
            │     ╰─ index.html
            ├─ downloads/
            │  ╰─ Something/
            ├─ images/
            │  ╰─ Something/
            ├─ index.html
            ├─ metadata.json
            ╰─ videos/
               ╰─ Something/
            """)
            
            let expectedTitleAndMetaContent = includeHTMLContent ? """
            <title>A single article</title>
            <meta content="This is a formatted article that becomes the root page (because there is only one page)." name="description"/>
            """ : "<title>Documentation</title>"
            
            let expectedNoScriptContent = includeHTMLContent ? """
            <article>
              <section>
                <ul>
                  <li>RootArticle</li>
                </ul>
                <p>
                Article</p>
                <h1>RootArticle</h1>
                <p>This is a <i> formatted</i> article that becomes the root page (because there is only one page).</p>
              </section>
            </article>
            """ : "<p>Some existing information inside the no script tag</p>"
            
            // The footer comes before the header to match the behavior of ConvertFileWritingConsumer.
            try assert(readHTML: fileSystem.contents(of: URL(fileURLWithPath: "/output-dir/documentation/rootarticle/index.html")), matches: """
            <html>
              <head>
                <meta charset="utf-8" />
                <link rel="icon" href="/some/test/base-path/favicon.ico" />
                \(expectedTitleAndMetaContent)
              </head>
              <body>
                <template id="custom-footer">
                  <p>Some footer content</p>
                </template>
                <template id="custom-header">
                  <p>Some header content</p>
                </template>
                <noscript>
                  \(expectedNoScriptContent)
                </noscript>
                <div id="app"></div>
              </body>
            </html>
            """)
        }
    }
}
