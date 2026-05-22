/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

#if canImport(FoundationXML)
// TODO: Consider other HTML rendering options as a future improvement (rdar://165755530)
import FoundationXML
import FoundationEssentials
#else
import Foundation
#endif

private import DocCHTML

extension HTMLRenderer {
    /// Wraps the unique rendered documentation content and its metadata into a full-page document.
    ///
    /// - Parameters:
    ///   - mainContent: The unique rendered documentation content for this page.
    ///   - metadata: The title and plain text description to use as metadata for this page.
    ///   - reference: The reference that the content and metadata is associated with.
    /// - Returns: A full-page static HTML document.
    static func makeFullPage(
        mainContent: XMLNode,
        metadata: (title: String, description: String?),
        for reference: ResolvedTopicReference,
        customHeader: XMLNode? = nil,
        customFooter: XMLNode? = nil
    ) -> XMLDocument {
        // Use relative paths to shared assets like a style sheet or favicon.
        let pathPrefixToArchiveRoot = String(repeating: "../", count: reference.url.pathComponents.count - 1)
        
        let head = XMLNode.element(named: "head", children: [
            .element(named: "meta", attributes: ["charset": "utf-8"]),
            .element(named: "meta", attributes: [
                "name": "viewport",
                "content": "width=device-width,initial-scale=1,viewport-fit=cover",
            ]),
            // FIXME: Add relative favicon links (rdar://177705447 (Include favicon images in the static HTML output))
            .element(named: "link", attributes: [
                "rel": "stylesheet",
                "href": "\(pathPrefixToArchiveRoot)reference.css",
            ]),
            .element(named: "title", children: [.text(metadata.title)])
        ])
        if let description = metadata.description {
            head.addChild(.element(named: "meta", attributes: [
                "name": "description",
                "content": description,
            ]))
        }
        
        // The full page body consists of 5 elements, in order;
        let body = XMLNode.element(named: "body")
        // 1. An optional custom header
        if let customHeader {
            body.addChild(customHeader)
        }
        
        // 2. The default header
        body.addChild(.element(named: "header", children: [
            // FIXME: Make this a button that toggles the navigator sidebar (rdar://177705101)
            // This is blocked by the sidebar requiring RenderNode input
            .element(named: "h2", children: [.text("Documentation")]),
            
            // FIXME: Support switching between language representations of the page (rdar://177705327)
            // The rough idea is to use <select> & <option> elements (when there are multiple languages)
            // and to add some very minimal JavaScript to modify the display of the "swift-only" and "occ-only" CSS classes based on that selection.
            .element(named: "span", children: [.text("Language: Swift")])
        ]))
        
        // 3. The unique documentation content for this page
        body.addChild(mainContent)
        
        // 4. The default footer
        body.addChild(.element(named: "footer", children: [
            // FIXME: Interacting with this radio group doesn't change the page's color scheme (rdar://177705056)
            .element(named: "fieldset", children: [
                .element(named: "legend", children: [.text("Select a color scheme preference")]),
                
                .element(named: "label", children: [
                    .element(named: "input", attributes: ["type": "radio", "value": "light"]),
                    .text("Light"),
                ]),
                .element(named: "label", children: [
                    .element(named: "input", attributes: ["type": "radio", "value": "dark"]),
                    .text("Dark"),
                ]),
                .element(named: "label", children: [
                    .element(named: "input", attributes: ["type": "radio", "value": "auto", "checked": "true"]),
                    .text("Auto"),
                ]),
            ], attributes: ["role": "radiogroup"])
        ]))
        
        // 5. An optional custom footer
        if let customFooter {
            body.addChild(customFooter)
        }
        
        // Specify the "html" doctype for the document
        let documentTypeDefinition = XMLDTD()
        documentTypeDefinition.name = "html"
        let page = XMLDocument(rootElement: .element(named: "html", children: [head, body], attributes: ["lang": "en-US"]))
        page.documentContentKind = .html
        page.dtd = documentTypeDefinition
        
        return page
    }
}
