/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2023 Apple Inc. and the Swift project authors
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
    private let documentationTitle: String
    private let catalogOutputPathPlaceholder: String = "___CATALOG_OUTPUT_PATH___"
    private let documentationTitlePlaceholder: String = "___DOCUMENTATION_TITLE___"
    private let templateCatalogBaseFolderPath: String = Bundle.module.url(
        forResource: "___FILEBASENAME_INIT___", withExtension: "docc", subdirectory: "TemplateLibrary/Init"
    )!.path
    private let templateTutorialBaseFolderPath: String = Bundle.module.url(
        forResource: "Tutorial", withExtension: "", subdirectory: "TemplateLibrary/Tutorials"
    )!.path
    private let includeTutorial: Bool
    private let diagnosticEngine: DiagnosticEngine = DiagnosticEngine(treatWarningsAsErrors: false)
    
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
        catalogOutputPath = "\(catalogOutputDirectory)/\(documentationTitle).docc"
    }
    
    /// Generates a documentation catalog from a catalog template
    ///
    /// - Parameter logHandle: The file handle that the convert and preview actions will print debug messages to.
    public mutating func perform(logHandle: SwiftDocC.LogHandle) throws -> ActionResult {
        try initAction()
    }
                            
    func initAction() throws -> ActionResult {
        
        let fileManager = FileManager.default
        var logHandle: LogHandle = .standardError
        var initProblems: [Problem] = []
        diagnosticEngine.filterLevel = .warning
        diagnosticEngine.add(DiagnosticConsoleWriter(formattingOptions: []))
        
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
                decoding: fileManager.contents(atPath: "\(catalogOutputPath)/\(documentationTitlePlaceholder).md")!,
                as: UTF8.self
            )
            // Replace the documentation title placeholder with the title given by the user
            topLevelArticleContent = topLevelArticleContent.replacingOccurrences(
                of: documentationTitlePlaceholder,
                with: documentationTitle
            )
            // Remove old template top-level article
            try fileManager.removeItem(atPath: "\(catalogOutputPath)/\(documentationTitlePlaceholder).md")
            
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
            
            print(
                """
                A new documentation catalog has been generated at \(catalogOutputPath).
                """,
                to: &logHandle
            )
            
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
