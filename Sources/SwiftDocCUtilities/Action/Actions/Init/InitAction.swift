/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import SwiftDocC

/// An action that generates a documentation catalog from a template seed.
public struct InitAction: AsyncAction {

    enum Error: DescribedError {
        case catalogAlreadyExists
        var errorDescription: String {
            switch self {
                case .catalogAlreadyExists: return "A documentation catalog with the same name already exists in the output directory."
            }
        }
    }
    
    private var fileManager: FileManagerProtocol
    private let catalogOutputURL: URL
    private let catalogTemplateKind: CatalogTemplateKind
    private let documentationTitle: String
    
    /// Creates a new Init action from the given parameters.
    ///
    /// - Parameters:
    ///     - catalogOutputDirectory: The URL to the directory where the catalog will be stored.
    ///     - documentationTitle: The title of the used for the top-level root file.
    ///     - catalogTemplate: The template used to initialize the catalog.
    ///     - fileManager: A file persistence manager.
    init(
        catalogOutputDirectory: URL,
        documentationTitle: String,
        catalogTemplate: CatalogTemplateKind,
        fileManager: FileManagerProtocol
    ) throws {
        self.catalogOutputURL = catalogOutputDirectory
        self.documentationTitle = documentationTitle
        self.catalogTemplateKind = catalogTemplate
        self.fileManager = fileManager
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
        // Note: This public initializer recalls the internal initializer
        // and exists separately because the FileManagerProtocol type
        // we use to enable mocking in tests is internal to this framework.
        try self.init(
            catalogOutputDirectory: catalogOutputDirectory.appendingPathComponent("\(documentationTitle).docc"),
            documentationTitle: documentationTitle,
            catalogTemplate: catalogTemplate,
            fileManager: FileManager.default
        )
    }
    
    /// Generates a documentation catalog from a catalog template.
    ///
    /// - Parameter logHandle: The file handle that the convert and preview actions will print debug messages to.
    public func perform(logHandle: inout LogHandle) async throws -> ActionResult {
        let diagnosticEngine: DiagnosticEngine = DiagnosticEngine(treatWarningsAsErrors: false)
        diagnosticEngine.filterLevel = .warning
        diagnosticEngine.add(DiagnosticConsoleWriter(formattingOptions: []))
        var logHandle = logHandle
        var directoryURLsList = [URL]()
        var resourceDocumentationLink: String {
            switch catalogTemplateKind {
            case .articleOnly:
                return "https://www.swift.org/documentation/docc/"
            case .tutorial:
                return "https://www.swift.org/documentation/docc/tutorial-syntax"
            }
        }
        
        defer {
            diagnosticEngine.flush()
        }
        
        do {
            // Create the directory where the catalog will be initialized.
            try fileManager.createDirectory(
                at: catalogOutputURL,
                withIntermediateDirectories: false,
                attributes: nil
            )
        } catch CocoaError.fileWriteFileExists {
            diagnosticEngine.emit(
                Problem(
                    diagnostic: Diagnostic(
                        severity: .error,
                        identifier: "org.swift.DocumentationCatalogAlreadyExists",
                        summary: Error.catalogAlreadyExists.errorDescription
                    )
                )
            )
            return ActionResult(
                didEncounterError: !diagnosticEngine.problems.isEmpty,
                outputs: []
            )
        }
        
        do {
            // Create a catalog template using the options passed through the CLI.
            let catalogTemplate = try CatalogTemplate(catalogTemplateKind, title: documentationTitle)
            // Store the catalog on disk.
            for (relativePath, content) in catalogTemplate.files {
                // Generate the directories for file storage
                // by adding the article path to the output URL and
                // excluding the file name.
                let fileURL = catalogOutputURL.appendingPathComponent(relativePath)
                try fileManager.createDirectory(
                    at: fileURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true,
                    attributes: nil
                )
                // Generate the article file at the specified URL path.
                try fileManager.createFile(at: fileURL, contents: Data(content.utf8))
                directoryURLsList.append(fileURL.relative(to: catalogOutputURL)!)
            }
            // Write additional directiories defined in the catalog.
            // Ex. `Resources`
            for relativePath in catalogTemplate.additionalDirectories {
                let directoryURL = catalogOutputURL.appendingPathComponent(relativePath)
                try fileManager.createDirectory(
                    at: directoryURL,
                    withIntermediateDirectories: true,
                    attributes: nil
                )
                directoryURLsList.append(directoryURL.relative(to: catalogOutputURL)!)
            }
            print(
                """
                A new documentation catalog has been generated at \(catalogOutputURL.path) with the following structure:
                
                \(directoryURLsList.map {
                    """
                    - \($0)
                    """
                }.joined(separator: "\n"))
                
                To preview it, run the command:
                    docc preview \(catalogOutputURL.path)
                
                For additional resources on how to get started with DocC, please refer to \(resourceDocumentationLink).
                """,
                to: &logHandle
            )
        } catch {
            // If an error occurs, delete the generated output.
            if fileManager.fileExists(atPath: catalogOutputURL.path) {
                try fileManager.removeItem(at: catalogOutputURL)
            }
            diagnosticEngine.emit(
                Problem(
                    diagnostic: Diagnostic(
                        severity: .error,
                        identifier: "org.swift.InitActionUnexpectedError",
                        summary: error.localizedDescription
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


