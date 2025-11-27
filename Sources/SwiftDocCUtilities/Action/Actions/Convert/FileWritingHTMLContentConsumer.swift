/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import SwiftDocC

struct FileWritingHTMLContentConsumer: HTMLContentConsumer {
    var targetFolder: URL
    var bundleRootFolder: URL?
    var fileManager: any FileManagerProtocol
    var prettyPrintOutput: Bool
    
    private struct HTMLTemplate {
        var beforeTitle: String
        var fromTitleToNoScript: String
        var afterNoScript: String
        
        init(data: Data) throws {
            let content = String(decoding: data, as: UTF8.self)
            
            // FIXME: If the template doesn't already contain a <noscript> tag, add one to the start of the <body>
            let noScriptStart = content.utf8.firstRange(of: "<noscript>".utf8)!.upperBound
            let noScriptEnd   = content.utf8.firstRange(of: "</noscript>".utf8)!.lowerBound
            
            let prefix = content[..<noScriptStart]
            
            // FIXME: If the template doesn't already contain a <title> tag, add one to the end of the <head>
            let titleStart = content.utf8.firstRange(of: "<title>".utf8)!.upperBound
            let titleEnd   = content.utf8.firstRange(of: "</title>".utf8)!.lowerBound
            
            // ???: Should we parse the content with XMLParser instead? If so, what do we do if it's not valid XHTML?
            
            beforeTitle         = String( prefix[..<titleStart] )
            fromTitleToNoScript = String( prefix[titleEnd...] )
            afterNoScript       = String( content[noScriptEnd...] )
        }
        
        func makeContent(
            content: XMLNode,
            title: String,
            plainDescription _: String?, // FIXME: Insert the description in the <head>
            prettyPrint: Bool
        ) -> String {
            beforeTitle + title + fromTitleToNoScript + content.rendered(prettyPrinted: prettyPrint) + afterNoScript
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
