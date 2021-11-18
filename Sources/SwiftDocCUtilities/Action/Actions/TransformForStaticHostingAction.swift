/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import SwiftDocC

/// An action that emits a static hostable website from a DocC Archive.
struct TransformForStaticHostingAction: Action {
    
    let rootURL: URL
    let outputURL: URL
    let staticHostingBasePath: String?
    let outputIsExternal: Bool
    let htmlTemplateDirectory: URL

    let fileManager: FileManagerProtocol
    
    var diagnosticEngine: DiagnosticEngine
    
    /// Initializes the action with the given validated options, creates or uses the given action workspace & context.
    init(documentationBundleURL: URL,
         outputURL:URL?,
         staticHostingBasePath: String?,
         htmlTemplateDirectory: URL,
         fileManager: FileManagerProtocol = FileManager.default,
         diagnosticEngine: DiagnosticEngine = .init()) throws
    {
        // Initialize the action context.
        self.rootURL = documentationBundleURL
        self.outputURL = outputURL ?? documentationBundleURL
        self.outputIsExternal = outputURL != nil
        self.staticHostingBasePath = staticHostingBasePath
        self.htmlTemplateDirectory = htmlTemplateDirectory
        self.fileManager = fileManager
        self.diagnosticEngine = diagnosticEngine
        self.diagnosticEngine.add(DiagnosticConsoleWriter(formattingOptions: []))
    }
    
    /// Converts each eligable file from the source archive,
    /// saves the results in the given output  folder.
    mutating func perform(logHandle: LogHandle) throws -> ActionResult {
        try emit()
        return ActionResult(didEncounterError: false, outputs: [outputURL])
    }
    
    mutating private func emit() throws  {
        

        // If the emit is to create the static hostable content outside of the source archive
        // then the output folder needs to be set up and the archive data copied
        // to the new folder.
        if outputIsExternal {
            
            try setupOutputDirectory(outputURL: outputURL)

            // Copy the appropriate folders from the archive.
            // We will do it item as we want to preserve anything intentionally left in the output URL by `setupOutputDirectory`
            for sourceItem in try fileManager.contentsOfDirectory(at: rootURL, includingPropertiesForKeys: [], options:[.skipsHiddenFiles]) {
                let targetItem = outputURL.appendingPathComponent(sourceItem.lastPathComponent)
                try fileManager.copyItem(at: sourceItem, to: targetItem)
            }
        }

        // Copy the HTML template to the output folder.
        var excludedFiles = [HTMLTemplate.templateFileName.rawValue]

        if outputIsExternal {
            excludedFiles.append(HTMLTemplate.indexFileName.rawValue)
        }

        for content in try fileManager.contentsOfDirectory(atPath: htmlTemplateDirectory.path) {

            guard !excludedFiles.contains(content) else { continue }

            let source = htmlTemplateDirectory.appendingPathComponent(content)
            let target = outputURL.appendingPathComponent(content)
            if fileManager.fileExists(atPath: target.path){
                try fileManager.removeItem(at: target)
            }
            try fileManager.copyItem(at: source, to: target)
        }

        // Create a StaticHostableTransformer targeted at the archive data folder
        let dataProvider = try LocalFileSystemDataProvider(rootURL: rootURL.appendingPathComponent("data"))
        let transformer = try StaticHostableTransformer(dataProvider: dataProvider, fileManager: fileManager, outputURL: outputURL, htmlTemplate: htmlTemplateDirectory, staticHostingBasePath: staticHostingBasePath)
        try transformer.transform()
        
    }
    
    /// Create ouput directory or empty its contents if it already exists.
    private func setupOutputDirectory(outputURL: URL) throws {
        
        var isDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: outputURL.path, isDirectory: &isDirectory), isDirectory.boolValue {
            let contents = try fileManager.contentsOfDirectory(at: outputURL, includingPropertiesForKeys: [], options: [.skipsHiddenFiles])
            for content in contents {
                try fileManager.removeItem(at: content)
            }
        } else {
            try fileManager.createDirectory(at: outputURL, withIntermediateDirectories: false, attributes: [:])
        }
    }
}
