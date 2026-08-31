/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

#if canImport(FoundationXML)
// TODO: Consider other HTML rendering options as a future improvement (rdar://165755530)
// XML nodes are still used to parse the raw HTML for the header and footer files.
private import FoundationXML
#else
package import class Foundation.XMLElement
#endif
package import struct Foundation.URL

package import DocCHTML

package extension HTMLRenderer {
    /// Wraps the unique rendered documentation content and its metadata into a full-page document.
    ///
    /// - Parameters:
    ///   - mainContent: The unique rendered documentation content for this page.
    ///   - metadata: The title and plain text description to use as metadata for this page.
    ///   - reference: The reference that the content and metadata is associated with.
    /// - Returns: A full-page static HTML document.
    static func makeFullPage(
        mainContent: HTMLNode,
        metadata: (title: String, description: String?),
        for reference: ResolvedTopicReference,
        customHeader: HTMLNode? = nil,
        customFooter: HTMLNode? = nil
    ) -> HTMLNode {
        // Use relative paths to shared assets like a style sheet or favicon.
        let pathPrefixToArchiveRoot = String(repeating: "../", count: reference.url.pathComponents.count - 1)
        
        var headElements: [HTMLNode] = [
            meta(.charSet),
            meta(
                .content("width=device-width,initial-scale=1,viewport-fit=cover"),
                .name("viewport"),
            ),
            // FIXME: Add relative favicon links (rdar://177705447 (Include favicon images in the static HTML output))
            link(
                .href("\(pathPrefixToArchiveRoot)reference.css"),
                .rel(.stylesheet),
            ),
            title(text: metadata.title),
        ]
        if let description = metadata.description {
            headElements.append(meta(
                .content(description),
                .name("description"),
            ))
        }
        
        // The full page body consists of 5 elements, in order;
        var bodyElements: [HTMLNode] = []
        // 1. An optional custom header
        if let customHeader {
            bodyElements.append(customHeader)
        }
        
        // 2. The default header
        bodyElements.append(header(contents: [
            // FIXME: Make this a button that toggles the navigator sidebar (rdar://177705101)
            // This is blocked by the sidebar requiring RenderNode input
            h2(contents: [.text("Documentation")]),
            
            // FIXME: Support switching between language representations of the page (rdar://177705327)
            // The rough idea is to use <select> & <option> elements (when there are multiple languages)
            // and to add some very minimal JavaScript to modify the display of the "swift-only" and "occ-only" CSS classes based on that selection.
            span(contents: [.text("Language: Swift")]),
        ]))
        
        // 3. The unique documentation content for this page
        bodyElements.append(main(contents: [mainContent]))
        
        // 4. The default footer
        bodyElements.append(footer(contents: [
            // FIXME: Interacting with this radio group doesn't change the page's color scheme (rdar://177705056)
            fieldSet(attributes: [.role(.radioGroup)], contents: [
                legend(contents: [.text("Select a color scheme preference")]),
                
                label(contents: [
                    input(          .name("color-scheme"), .type("radio"), .value("light")),
                    .text("Light"),
                ]),
                label(contents: [
                    input(          .name("color-scheme"), .type("radio"), .value("dark")),
                    .text("Dark"),
                ]),
                label(contents: [
                    input(.checked, .name("color-scheme"), .type("radio"), .value("auto")),
                    .text("Auto"),
                ]),
            ])
        ]))
        
        // 5. An optional custom footer
        if let customFooter {
            bodyElements.append(customFooter)
        }
        
        return html(attributes: [.lang("en-US")], contents: [
            head(contents: consume headElements),
            body(contents: consume bodyElements),
        ])
    }
    
    /// Prepares the provided custom header and footer files to be included in the full-page structure.
    ///
    /// - Parameters:
    ///   - customHeader: A custom HTML file that the renderer will include as a header in the full-page output.
    ///   - customFooter: A custom HTML file that the renderer will include as a footer in the full-page output.
    ///   - fileManager: The file manager that the HTML renderer uses to read the custom header and footer files.
    /// - Returns: The parsed custom header and parsed custom footer, ready to be included in the full-page output.
    static func prepareForFullPage(
        customHeader: URL?,
        customFooter: URL?,
        fileManager: some FileManagerProtocol
    ) throws -> (customHeader: HTMLNode?, customFooter: HTMLNode?) {
        func parse(contentsOf url: URL) throws -> HTMLNode? {
            let content = String(decoding: try fileManager.contents(of: url), as: UTF8.self)
            let xmlElement = try XMLElement(xmlString: content)
            return HTMLNode(from: xmlElement)
        }
        
        return (
            customHeader: try customHeader.flatMap(parse(contentsOf:)),
            customFooter: try customFooter.flatMap(parse(contentsOf:))
        )
    }
}
