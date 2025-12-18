/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2025 Apple Inc. and the Swift project authors
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

import SwiftDocC
import DocCHTML

struct FileWritingHTMLContentConsumer: HTMLContentConsumer {
    var targetFolder: URL
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
            // TODO: If the template doesn't already contain a <noscript> element, add one to the start of the <body> element
            // TODO: If the template doesn't already contain a <title> element, add one to the end of the <head> element
            contentReplacementRange     = noScriptStart ..< noScriptEnd
            titleReplacementRange       = titleStart    ..< titleEnd
            descriptionReplacementRange = beforeHeadEnd ..< beforeHeadEnd
            
            assert(titleReplacementRange.upperBound       < descriptionReplacementRange.lowerBound, "The title replacement range should be before the description replacement range")
            assert(descriptionReplacementRange.upperBound < contentReplacementRange.lowerBound,     "The description replacement range should be before the content replacement range")
        }
        
        func makeContent(
            content: XMLNode,
            title: String,
            plainDescription: String?,
            prettyPrint: Bool
        ) -> String {
            var copy = original
            // Replace the content in reverse order so that the earlier ranges remain valid.
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
    private let fileWriter: JSONEncodingRenderNodeWriter
    
    init(
        targetFolder: URL,
        fileManager: some FileManagerProtocol,
        htmlTemplate: URL,
        prettyPrintOutput: Bool = shouldPrettyPrintOutputJSON
    ) throws {
        self.targetFolder = targetFolder
        self.fileManager = fileManager
        self.htmlTemplate = try HTMLTemplate(data: fileManager.contents(of: htmlTemplate))
        self.prettyPrintOutput = prettyPrintOutput
        self.fileWriter = JSONEncodingRenderNodeWriter(
            targetFolder: targetFolder,
            fileManager: fileManager,
            transformForStaticHostingIndexHTML: nil
        )
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
        
        let relativeFilePath = NodeURLGenerator.fileSafeReferencePath(reference, lowercased: true) + "/index.html"
        try fileWriter.write(Data(htmlString.utf8), toFileSafePath: relativeFilePath)
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
