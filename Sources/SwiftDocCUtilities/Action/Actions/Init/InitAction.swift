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
    
    private let catalogOutputURL: URL
    private let documentationTitle: String
    private let catalogTemplate: CatalogTemplateKind
    private let includeTutorial: Bool
    private let diagnosticEngine: DiagnosticEngine = DiagnosticEngine(treatWarningsAsErrors: false)
    
    /// Creates a new Init action from the given parameters.
    ///
    /// - Parameters:
    ///     - catalogOutputDirectory: The URL to the directory where the catalog will be stored.
    ///     - documentationTitle: The title of the technology root.
    ///     - catalogTemplate: The template used to initialize the catalog.
    ///     - includeTutorial: The boolean that indicates if the tutorial template should be added to the output catalog.
    public init(
        catalogOutputDirectory: URL,
        documentationTitle: String,
        catalogTemplate: CatalogTemplateKind,
        includeTutorial: Bool
    ) throws {
        self.documentationTitle = documentationTitle
        self.includeTutorial = includeTutorial
        self.catalogTemplate = catalogTemplate
        catalogOutputURL = catalogOutputDirectory.appendingPathComponent("\(documentationTitle).docc")
    }
    
    /// Generates a documentation catalog from a catalog template.
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
            diagnosticEngine.flush()
        }
        
        do {
            try fileManager.createDirectory(at: catalogOutputURL, withIntermediateDirectories: false)
            let documentationCatalog = try CatalogTemplateFactory.createDocumentationCatalog(catalogTemplate, catalogTitle: documentationTitle)
            try CatalogTemplateFactory.constructCatalog(documentationCatalog, outputURL: catalogOutputURL)
            print(
                """
                A new documentation catalog has been generated at \(catalogOutputURL.path)
                whith the following structure:
                
                """,
                to: &logHandle
            )
            
            // Recursevely print the content of the generated documentation catalog.
            let resourceKeys = Set<URLResourceKey>([.nameKey, .isDirectoryKey])
            let directoryEnumerator = fileManager.enumerator(at: catalogOutputURL, includingPropertiesForKeys: Array(resourceKeys), options: .skipsHiddenFiles)!
            var fileURLs: [URL] = []
            for case let fileURL as URL in directoryEnumerator {
                fileURLs.append(fileURL.relative(to: catalogOutputURL)!)
            }
            fileURLs.forEach {
                print(
                    """
                    - \($0.path)
                    """,
                    to: &logHandle
                )
            }
            
        } catch CocoaError.fileWriteFileExists {
            initProblems.append(
                Problem(
                    diagnostic: Diagnostic(
                        severity: .error,
                        identifier: "org.swift.DocumentationCatalogAlreadyExists",
                        summary: Error.catalogAlreadyExists.errorDescription)
                )
            )
            throw Error.catalogAlreadyExists
        } catch {
            // If an error occurs remove the output created
            if fileManager.fileExists(atPath: catalogOutputURL.path) {
                try FileManager.default.removeItem(atPath: catalogOutputURL.path)
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
            outputs: [catalogOutputURL]
        )
    }
    
}


