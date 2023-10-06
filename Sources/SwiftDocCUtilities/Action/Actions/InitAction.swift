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
    private let catalogTemplate: String
    private let includeTutorial: Bool
    private let diagnosticEngine: DiagnosticEngine = DiagnosticEngine(treatWarningsAsErrors: false)
    
    /// Creates a new Init action from the given parameters
    ///
    /// - Parameters:
    ///     - catalogOutputDirectory: The path to the directory where the catalog will be stored.
    ///     - documentationTitle: The title of the technology root.
    ///     - catalogTemplate: The template used to initialize the catalog.
    ///     - includeTutotial: The boolean that indicates if the tutorial template should be added to the otput catalog.
    public init(
        catalogOutputDirectory: String,
        documentationTitle: String,
        catalogTemplate: String,
        includeTutorial: Bool
    ) throws {
        self.documentationTitle = documentationTitle
        self.includeTutorial = includeTutorial
        self.catalogTemplate = catalogTemplate
        catalogOutputPath = "\(catalogOutputDirectory)/\(documentationTitle).docc"
    }
    
    /// Generates a documentation catalog from a catalog template
    ///
    /// - Parameter logHandle: The file handle that the convert and preview actions will print debug messages to.
    public mutating func perform(logHandle: SwiftDocC.LogHandle) throws -> ActionResult {
        try initAction()
    }
                            
    func initAction() throws -> ActionResult {
        
        let catalogOutputURL = URL(fileURLWithPath: catalogOutputPath)
        let fileManager = FileManager.default
        var logHandle: LogHandle = .standardError
        var initProblems: [Problem] = []
        diagnosticEngine.filterLevel = .warning
        diagnosticEngine.add(DiagnosticConsoleWriter(formattingOptions: []))
        
        defer {
            diagnosticEngine.emit(initProblems)
        }
        
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
            try fileManager.createDirectory(at: catalogOutputURL, withIntermediateDirectories: false)
            let catalogTemplateFactory = CatalogTemplateFactory()
            let documentationCatalog = try catalogTemplateFactory.createDocumentationCatalog(catalogTemplate, catalogTitle: documentationTitle)
            try catalogTemplateFactory.constructCatalog(documentationCatalog, outputPath: catalogOutputPath)
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
