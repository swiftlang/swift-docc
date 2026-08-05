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

import SwiftDocC
private import DocCHTML

// I'm not convinced that this is the best long-term design for HTML as a primary output format.
// It currently exist because the consumers are created in the DocCCommandLine target but the core logic is in SwiftDocC.
// There might be a different internal abstraction where we don't need this type at all. (rdar://177867282)
struct FullPageHTMLContentConsumer: HTMLContentConsumer {
    let _isPrimaryOutputFormat = true
    
    private let customHeader: XMLNode?
    private let customFooter: XMLNode?
    private let prettyPrint: Bool
    
    // FIXME: Extract the file writing (and directory creation) functionality from this RenderNode (JSON) specific type.
    private let fileWriter: JSONEncodingRenderNodeWriter
    
    init(
        targetFolder: URL,
        fileManager: some FileManagerProtocol,
        prettyPrint: Bool,
        customHeader: URL?,
        customFooter: URL?
    ) throws {
        (self.customHeader, self.customFooter) = try HTMLRenderer.prepareForFullPage(customHeader: customHeader, customFooter: customFooter, fileManager: fileManager)
        self.prettyPrint = prettyPrint
        
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
        let page = HTMLRenderer.makeFullPage(mainContent: mainContent, metadata: metadata, for: reference, customHeader: customHeader, customFooter: customFooter)
        
        let htmlData = HTMLFormatter.format(page, options: prettyPrint ? .prettyPrint : [])
        
        let relativeFilePath = NodeURLGenerator.fileSafeReferencePath(reference, lowercased: true) + "/index.html"
        try fileWriter.write(htmlData, toFileSafePath: relativeFilePath)
    }
}
