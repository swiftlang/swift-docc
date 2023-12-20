/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2023 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import SwiftDocC

/// An action that generates a documentation catalog from a template seed.
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
    private let catalogTemplateKind: CatalogTemplateKind
    private let diagnosticEngine: DiagnosticEngine = DiagnosticEngine(treatWarningsAsErrors: false)
    private let documentationTitle: String
    private var resourceDocumentationLink: String {
        switch catalogTemplateKind {
        case .articleOnly:
            return "https://www.swift.org/documentation/docc/"
        case .tutorial:
            return "https://www.swift.org/documentation/docc/tutorial-syntax"
        }
    }
    
    /// Creates a new Init action from the given parameters.
    ///
    /// - Parameters:
    ///     - catalogOutputDirectory: The URL to the directory where the catalog will be stored.
    ///     - documentationTitle: The title of the used for the top-level root file.
    ///     - catalogTemplate: The template used to initialize the catalog.
    public init(
        catalogOutputDirectory: URL,
        documentationTitle: String,
        catalogTemplate: CatalogTemplateKind
    ) throws {
        self.documentationTitle = documentationTitle
        self.catalogTemplateKind = catalogTemplate
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
            // Create the directory where the catalog will be initialized.
            try fileManager.createDirectory(at: catalogOutputURL, withIntermediateDirectories: false)
        } catch CocoaError.fileWriteFileExists {
            initProblems.append(
                Problem(
                    diagnostic: Diagnostic(
                        severity: .error,
                        identifier: "org.swift.DocumentationCatalogAlreadyExists",
                        summary: Error.catalogAlreadyExists.errorDescription
                    )
                )
            )
            throw Error.catalogAlreadyExists
        }
        
        do {
            // Create a catalog template using the options passed through the CLI.
            let catalogTemplate = try CatalogTemplateKind.generate(catalogTemplateKind, catalogTitle: documentationTitle)
            // Store the catalog on disk.
            try catalogTemplate.write(to: catalogOutputURL)
        } catch {
            // If an error occurs, delete the generated output.
            if fileManager.fileExists(atPath: catalogOutputURL.path) {
                try FileManager.default.removeItem(atPath: catalogOutputURL.path)
            }
            initProblems.append(
                Problem(
                    diagnostic: Diagnostic(
                        severity: .error,
                        identifier: "org.swift.InitActionUnexpectedError",
                        summary: error.localizedDescription
                    )
                )
            )
            throw error
        }
        
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
        
        print(
            """
            
            For additional resources on how to get started with DocC, please refer to \(resourceDocumentationLink).
            """,
            to: &logHandle
        )
        
        return ActionResult(
            didEncounterError: !diagnosticEngine.problems.isEmpty,
            outputs: [catalogOutputURL]
        )
    }
    
}


