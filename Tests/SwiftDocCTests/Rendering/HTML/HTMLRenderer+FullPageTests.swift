/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Testing
import DocCHTML
@testable import SwiftDocC
import DocCTestUtilities
import DocCCommon

struct HTMLRenderFullPageTests {
    private let reference = ResolvedTopicReference(bundleID: "com.example", path: "/documentation/ModuleName/SomePage/someMethod(with:and:)", fragment: nil, sourceLanguage: .swift)
    
    @Test
    func includesMainContentInFullPage() async throws {
        let mainContent = article(contents: [
            p(contents: [
                .text("Some documentation")
            ])
        ])
        
        let fullPage = HTMLRenderer.makeFullPage(
            mainContent: mainContent,
            metadata: (title: "Some title", description: "Some description"),
            for: reference
        )
        
        assert(fullPage, matches: """
        <!DOCTYPE html>
        <html lang="en-US">
          <head>
            <meta charset="utf-8">
            <meta content="width=device-width,initial-scale=1,viewport-fit=cover" name="viewport">
            <link href="../../../../reference.css" rel="stylesheet">
            <title>Some title</title>
            <script src="../../../../navigator.js" defer></script>
            <meta content="Some description" name="description">
          </head>
          <body>
            <header>
              <h2>Documentation</h2>
              <span>Language: Swift</span>
            </header>
            <div class="full-width-container">
              <main>
                <article>
                  <p>Some documentation</p>
                </article>
              </main>
            </div>
            <footer>
              <fieldset role="radiogroup">
                <legend>Select a color scheme preference</legend>
                <label>
                  <input name="color-scheme" type="radio" value="light">
                  Light
                </label>
                <label>
                  <input name="color-scheme" type="radio" value="dark">
                  Dark
                </label>
                <label>
                  <input checked name="color-scheme" type="radio" value="auto">
                  Auto
                </label>
              </fieldset>
            </footer>
          </body>
        </html>
        """)
    }
    
    @Test
    func includesCustomHeaderAndFooterInFullPage() async throws {
        let customHeader = header(contents: [
            .text("A custom header")
        ])
        let customFooter = footer(contents: [
            .text("A custom footer")
        ])
        
        // Render the page a few times in parallel to verify that the custom header/footer nodes can be "reused".
        [1,2,3].concurrentPerform { _ in    
            let mainContent = article(contents: [
                p(contents: [
                    .text("Some documentation")
                ])
            ])
            
            let fullPage = HTMLRenderer.makeFullPage(
                mainContent: mainContent,
                metadata: (title: "Some title", nil),
                for: reference,
                customHeader: customHeader,
                customFooter: customFooter
            )
            
            assert(fullPage, matches: """
            <!DOCTYPE html>
            <html lang="en-US">
              <head>
                <meta charset="utf-8">
                <meta content="width=device-width,initial-scale=1,viewport-fit=cover" name="viewport">
                <link href="../../../../reference.css" rel="stylesheet">
                <title>Some title</title>
                <script src="../../../../navigator.js" defer></script>
              </head>
              <body>
                <header>A custom header</header>
                <header>
                  <h2>Documentation</h2>
                  <span>Language: Swift</span>
                </header>
                <div class="full-width-container">
                  <main>
                    <article>
                      <p>Some documentation</p>
                    </article>
                  </main>
                </div>
                <footer>
                  <fieldset role="radiogroup">
                    <legend>Select a color scheme preference</legend>
                    <label>
                      <input name="color-scheme" type="radio" value="light">
                      Light
                    </label>
                    <label>
                      <input name="color-scheme" type="radio" value="dark">
                      Dark
                    </label>
                    <label>
                      <input checked name="color-scheme" type="radio" value="auto">
                      Auto
                    </label>
                  </fieldset>
                </footer>
                <footer>A custom footer</footer>
              </body>
            </html>
            """)
        }
    }
    
    @Test
    func includesCustomScriptsAtEndOfFullPageBody() async throws {
        let fullPage = HTMLRenderer.makeFullPage(
            mainContent: article(contents: []),
            metadata: (title: "Some title", description: nil),
            for: reference,
            customScripts: [
                .init(name: "local-script"),
                .init(name: "async-local-script.js", async: true),
                .init(url: "https://example.com/external-script.js", type: "module", integrity: "sha384-abc"),
            ]
        )
        
        let formattedPage = String(decoding: HTMLFormatter.format(fullPage, options: .prettyPrint), as: UTF8.self)
        #expect(formattedPage.contains("""
            </footer>
            <script src="../../../../custom-scripts/local-script.js"></script>
            <script async src="../../../../custom-scripts/async-local-script.js"></script>
            <script crossorigin="anonymous" integrity="sha384-abc" src="https://example.com/external-script.js" type="module"></script>
          </body>
        """))
    }
    
    @Test
    func preparesCustomScriptsFromFile() async throws {
        let fileSystem = try TestFileSystem(folders: [
            Folder(name: "path", content: [
                TextFile(name: "custom-scripts.json", utf8Content: """
                [
                    { "name": "local-script", "run": "on-navigate" },
                    { "url": "https://example.com/external-script.js", "integrity": "sha384-abc" },
                    { "url": "https://example.com/invalid.js", "name": "invalid" },
                    { "async": true }
                ]
                """),
            ]),
        ])
        
        let customScripts = try HTMLRenderer.prepareForFullPage(
            customHeader: nil,
            customFooter: nil,
            customScripts: URL(fileURLWithPath: "/path/custom-scripts.json"),
            fileManager: fileSystem
        ).customScripts
        // Custom scripts without exactly one of a `url` or a `name` are skipped.
        #expect(customScripts == [
            .init(name: "local-script"),
            .init(url: "https://example.com/external-script.js", integrity: "sha384-abc"),
        ])
        
        #expect(try HTMLRenderer.prepareForFullPage(customHeader: nil, customFooter: nil, fileManager: fileSystem).customScripts.isEmpty)
    }
}

func assert(_ page: HTMLNode, matches expected: String, sourceLocation: SourceLocation = #_sourceLocation) {
    #expect(String(decoding: HTMLFormatter.format(page, options: .prettyPrint), as: UTF8.self) == expected, sourceLocation: sourceLocation)
}
