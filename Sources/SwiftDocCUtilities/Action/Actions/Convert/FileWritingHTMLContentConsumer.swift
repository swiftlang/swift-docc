/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import SwiftDocC
import DocCHTML

struct FileWritingHTMLContentConsumer: HTMLContentConsumer {
    var targetFolder: URL
    var bundleRootFolder: URL?
    var fileManager: any FileManagerProtocol
    var prettyPrintOutput: Bool
    
    private struct HTMLTemplate {
        var original: String
        var contentReplacementRange:     Range<String.Index>
        var titleReplacementRange:       Range<String.Index>
        var descriptionReplacementRange: Range<String.Index>
        
        init(data: Data) throws {
            let content = String(decoding: data, as: UTF8.self)
            
            // ???: Should we parse the content with XMLParser instead? If so, what do we do if it's not valid XHTML?
            let noScriptStart = content.utf8.firstRange(of:  "<noscript>".utf8)!.upperBound
            let noScriptEnd   = content.utf8.firstRange(of: "</noscript>".utf8)!.lowerBound
            
            let titleStart = content.utf8.firstRange(of:  "<title>".utf8)!.upperBound
            let titleEnd   = content.utf8.firstRange(of: "</title>".utf8)!.lowerBound
            
            let beforeHeadEnd = content.utf8.firstRange(of: "</head>".utf8)!.lowerBound
            
            original = content
            // FIXME: If the template doesn't already contain a <noscript> tag, add one to the start of the <body>
            // FIXME: If the template doesn't already contain a <title> tag, add one to the end of the <head>
            contentReplacementRange     = noScriptStart ..< noScriptEnd
            titleReplacementRange       = titleStart    ..< titleEnd
            descriptionReplacementRange = beforeHeadEnd ..< beforeHeadEnd
        }
        
        func makeContent(
            content: XMLNode,
            title: String,
            plainDescription: String?,
            prettyPrint: Bool
        ) -> String {
            var copy = original
            copy.replaceSubrange(contentReplacementRange, with: content.rendered(prettyPrinted: prettyPrint))
            if let plainDescription {
                let metaDescription = XMLNode.element(named: "meta", attributes: ["name": "description", "content": plainDescription])
                copy.replaceSubrange(descriptionReplacementRange, with: metaDescription.rendered(prettyPrinted: prettyPrint))
            }
            copy.replaceSubrange(titleReplacementRange,   with: title)
            
            return copy
        }
    }
    private var htmlTemplate: HTMLTemplate
    
    init(
        targetFolder: URL,
        bundleRootFolder: URL? = nil,
        fileManager: some FileManagerProtocol,
        htmlTemplate: URL,
        prettyPrintOutput: Bool = shouldPrettyPrintOutputJSON
    ) throws {
        self.targetFolder = targetFolder
        self.bundleRootFolder = bundleRootFolder
        self.fileManager = fileManager
        self.htmlTemplate = try HTMLTemplate(data: fileManager.contents(of: htmlTemplate))
        self.prettyPrintOutput = prettyPrintOutput
    }
    
    func consume(
        mainContent: XMLNode,
        metadata: (title: String, description: String?),
        forPage reference: ResolvedTopicReference
    ) throws {
        let htmlString = htmlTemplate.makeContent(
            content: mainContent,
            title: metadata.title,
            plainDescription: metadata.description,
            prettyPrint: prettyPrintOutput
        )
        
        let url = targetFolder.appendingPathComponent(reference.path)
        try? fileManager.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
        try fileManager.createFile(at: url.appendingPathComponent("index.html"), contents: Data(htmlString.utf8), options: .atomic)
    }
}

private extension XMLNode {
    func rendered(prettyPrinted: Bool) -> String {
        if prettyPrinted {
            xmlString(options: [.nodePrettyPrint, .nodeCompactEmptyElement])
        } else {
            xmlString(options: .nodeCompactEmptyElement)
        }
    }
}
