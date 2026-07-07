/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Testing
#if canImport(FoundationXML)
// TODO: Consider other HTML rendering options as a future improvement (rdar://165755530)
import FoundationXML
import FoundationEssentials
#else
import Foundation
#endif
import DocCHTML
@testable import SwiftDocC
import DocCTestUtilities

struct HTMLRenderFullPageTests {
    private let reference = ResolvedTopicReference(bundleID: "com.example", path: "/documentation/ModuleName/SomePage/someMethod(with:and:)", fragment: nil, sourceLanguage: .swift)
    
    @Test
    func includesMainContentInFullPage() async throws {
        let mainContent = XMLNode.element(named: "article", children: [
            .element(named: "p", children: [
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
            <meta content="Some description" name="description">
          </head>
          <body>
            <header>
              <h2>Documentation</h2>
              <span>Language: Swift</span>
            </header>
            <main>
              <article>
                <p>Some documentation</p>
              </article>
            </main>
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
        let customHeader = XMLNode.element(named: "header", children: [
            .text("A custom header")
        ])
        let customFooter = XMLNode.element(named: "footer", children: [
            .text("A custom footer")
        ])
        
        // Render the page a few times in parallel to verify that the custom header/footer nodes can be "reused".
        [1,2,3].concurrentPerform { _ in    
            let mainContent = XMLNode.element(named: "article", children: [
                .element(named: "p", children: [
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
              </head>
              <body>
                <header>A custom header</header>
                <header>
                  <h2>Documentation</h2>
                  <span>Language: Swift</span>
                </header>
                <main>
                  <article>
                    <p>Some documentation</p>
                  </article>
                </main>
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
}

private extension XMLNode {
    func rendered(sourceLocation: Testing.SourceLocation = #_sourceLocation) -> String {
        guard let htmlNode = HTMLNode(from: self) else {
            Issue.record("Failed to convert node \(self.xmlString(options: .nodeCompactEmptyElement)) to HTML node", sourceLocation: sourceLocation)
            return ""
        }
        
        return String(decoding: HTMLFormatter.format(htmlNode, options: .prettyPrint), as: UTF8.self)
    }
}


func assert(_ document: XMLDocument, matches expected: String, sourceLocation: SourceLocation = #_sourceLocation) {
    #expect(document.rootElement()!.rendered(sourceLocation: sourceLocation) == expected, sourceLocation: sourceLocation)
}
