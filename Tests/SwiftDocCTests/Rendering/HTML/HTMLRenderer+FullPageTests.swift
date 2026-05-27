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
            <article>
              <p>Some documentation</p>
            </article>
            <footer>
              <fieldset role="radiogroup">
                <legend>Select a color scheme preference</legend>
                <label>
                  <input name="color-scheme" type="radio" value="light">
                  Light</label>
              <label>
                <input name="color-scheme" type="radio" value="dark">
                Dark</label>
              <label>
                <input checked name="color-scheme" type="radio" value="auto">
                Auto</label>
              </fieldset>
            </footer>
          </body>
        </html>
        """)
    }
    
    @Test
    func includesCustomHeaderAndFooterInFullPage() async throws {
        let mainContent = XMLNode.element(named: "article", children: [
            .element(named: "p", children: [
                .text("Some documentation")
            ])
        ])
        
        let customHeader = XMLNode.element(named: "header", children: [
            .text("A custom header")
        ])
        let customFooter = XMLNode.element(named: "footer", children: [
            .text("A custom footer")
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
            <article>
              <p>Some documentation</p>
            </article>
            <footer>
              <fieldset role="radiogroup">
                <legend>Select a color scheme preference</legend>
                <label>
                  <input name="color-scheme" type="radio" value="light">
                  Light</label>
              <label>
                <input name="color-scheme" type="radio" value="dark">
                Dark</label>
              <label>
                <input checked name="color-scheme" type="radio" value="auto">
                Auto</label>
              </fieldset>
            </footer>
            <footer>A custom footer</footer>
          </body>
        </html>
        """)
    }
}

// This workaround is modified from the similar code in FileWritingHTMLContentConsumerTests.swift
func assert(_ html: XMLDocument, matches expectedHTML: String, sourceLocation: SourceLocation = #_sourceLocation) {
    // XMLNode on macOS and Linux pretty print with different indentation.
    // To compare the XML structure without getting false positive failures because of indentation and other formatting differences,
    // we explicitly process each string into an easy-to-compare format.
    func formatForTestComparison(_ xmlString: String) -> String {
        // This is overly simplified and won't result in "pretty" XML for general use but sufficient for test content comparisons
        xmlString
            // Workaround document type differences
            .replacingOccurrences(of: #"<?xml version="1.0" encoding="utf-8" standalone="no"?>"#, with: "")
            .replacingOccurrences(of: #"<!DOCTYPE html PUBLIC "" "">"#, with: "<!DOCTYPE html>")
            // Put each tag on its own line
            .replacingOccurrences(of: ">", with: ">\n")
            // Allow some meta tags to encode as void elements rather than self-closing elements
            .replacingOccurrences(of: "\">", with: "\"/>")
            // Remove leading indentation
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
            // Explicitly escape a few HTML characters that appear in the test content
            .replacingOccurrences(of: "–", with: "&#x2013;") // en-dash
            .replacingOccurrences(of: "—", with: "&#x2014;") // em-dash
            // Shorten empty string attribute values
            .replacingOccurrences(of: #"="""#, with: "")
    }
    
    let actualHTML: String = html.xmlString(options: .nodeCompactEmptyElement)
    #expect(formatForTestComparison(actualHTML) == formatForTestComparison(expectedHTML), sourceLocation: sourceLocation)
}
