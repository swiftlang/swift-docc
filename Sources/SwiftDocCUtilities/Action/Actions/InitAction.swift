/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import SwiftDocC

/// An action that generates an article-only documentation catalog from a template seed.
public struct InitAction: Action {
    
    enum Error: DescribedError {
        case catalogAlreadyExists, cannotCreate
        var errorDescription: String {
            switch self {
                case .catalogAlreadyExists: return "A documentation catalog with the same name already exists in the output directory."
                case .cannotCreate: return "Unable to generate the documentation catalog."
            }
        }
    }
    
    private let catalogOutputPath: String
    private let defaultDocumentationTitle: String
    private let documentationTitle: String
    private let catalogOutputPathPlaceholder: String
    private var templateLibraryPath: String
    private var templateTutorialBaseFolderPath: String
    private var templateCatalogBaseFolderPath: String
    private let includeTutorial: Bool
    private let diagnosticEngine: DiagnosticEngine
    
    private let logHandle: LogHandle
    // TODO: Refactor to properly get the DocC root
    let templatePath = (
        Bundle.main.bundleURL
        .deletingLastPathComponent() // docc
        .deletingLastPathComponent() // bin
        .deletingLastPathComponent() // .build
    ).path
    
    /// Creates a new Init action from the given parameters
    ///
    /// - Parameters:
    ///     - catalogOutputDirectory: The path to the directory where the catalog will be stored.
    ///     - documentationTitle: The title of the technology root.
    ///     - includeTutotial: The boolean that indicates if the tutorial template should be added to the otput catalog.
    public init(
        catalogOutputDirectory: String,
        documentationTitle: String,
        includeTutorial: Bool
    ) throws {
        self.documentationTitle = documentationTitle
        self.includeTutorial = includeTutorial
        self.diagnosticEngine = DiagnosticEngine(treatWarningsAsErrors: false)
        diagnosticEngine.filterLevel = .warning
        diagnosticEngine.add(DiagnosticConsoleWriter(formattingOptions: []))
        catalogOutputPath = "\(catalogOutputDirectory)/\(documentationTitle).docc"
        defaultDocumentationTitle = "Documentation"
        catalogOutputPathPlaceholder = "___CATALOG_OUTPUT_PATH___"
        templateLibraryPath = "\(templatePath)/Sources/SwiftDocCUtilities/TemplateLibrary"
        templateTutorialBaseFolderPath = "\(templateLibraryPath)/Tutorials/Tutorial"
        templateCatalogBaseFolderPath = "\(templateLibraryPath)/Init/___FILEBASENAME_INIT___.docc"
        logHandle = LogHandle.standardOutput
    }
    
    /// Generates a documentation catalog from a catalog template
    ///
    /// - Parameter logHandle: The file handle that the convert and preview actions will print debug messages to.
    public mutating func perform(logHandle: SwiftDocC.LogHandle) throws -> ActionResult {
        try initAction()
    }
                            
    func initAction() throws -> ActionResult {
        
        let fileManager = FileManager.default
        var initProblems: [Problem] = []
        
        defer {
            diagnosticEngine.emit(initProblems)
        }
        
        // Copy template and store it in the output path
        if fileManager.fileExists(atPath: catalogOutputPath) {
            initProblems.append(
                Problem(
                    diagnostic: Diagnostic(
                        severity: .error,
                        identifier: "org.swift.DocumentationCatalogAlreadyExists",
                        summary: Error.catalogAlreadyExists.errorDescription)
                )
            )
            throw Error.catalogAlreadyExists
        }
        
        do {
            try fileManager.copyItem(
                atPath: templateCatalogBaseFolderPath,
                toPath: catalogOutputPath
            )
            
            // Overwrite the top level article title
            var topLevelArticleContent = String(
                decoding: fileManager.contents(atPath: "\(catalogOutputPath)/\(defaultDocumentationTitle).md")!,
                as: UTF8.self
            )
            if (documentationTitle != defaultDocumentationTitle) {
                topLevelArticleContent = topLevelArticleContent.replacingOccurrences(of: "# \(defaultDocumentationTitle)", with: "# \(documentationTitle)")
                // Remove old template top-level article
                try fileManager.removeItem(atPath: "\(catalogOutputPath)/\(defaultDocumentationTitle).md")
            }
            topLevelArticleContent = topLevelArticleContent.replacingOccurrences(
                of: catalogOutputPathPlaceholder,
                with: catalogOutputPath
            )
            
            // Write the new top level article
            fileManager.createFile(
                atPath: "\(catalogOutputPath)/\(documentationTitle).md",
                contents: topLevelArticleContent.data(using: .utf8)!
            )
            
            // If the --include-tutorial flag is passed, append it to the output catalog
            if (includeTutorial) {
                try fileManager.copyItem(
                    atPath: templateTutorialBaseFolderPath,
                    toPath: "\(catalogOutputPath)/Tutorial"
                )
            }
        } catch {
            // If an error occurs remove the ouptut created
            if fileManager.fileExists(atPath: catalogOutputPath) {
                try FileManager.default.removeItem(atPath: catalogOutputPath)
            }
            initProblems.append(
                Problem(
                    diagnostic: Diagnostic(
                        severity: .error,
                        identifier: "org.swift.InitActionUnexpectedError",
                        summary: Error.cannotCreate.errorDescription
                    )
                )
            )
        }
        
        return ActionResult(
            didEncounterError: !diagnosticEngine.problems.isEmpty,
            outputs: [URL(string: catalogOutputPath)!]
        )
    }
    
}
