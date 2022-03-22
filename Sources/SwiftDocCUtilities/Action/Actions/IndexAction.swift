/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import SwiftDocC

/// An action that creates an index of a documentation catalog.
public struct IndexAction: Action {
    enum Error: DescribedError {
        case doesNotContainCatalog(url: URL)
        var errorDescription: String {
            switch self {
            case .doesNotContainCatalog(let url):
                return "The directory at '\(url)' and its subdirectories do not contain at least one valid documentation catalog. A documentation catalog is a directory ending in `.docc`."
            }
        }
    }

    let rootURL: URL
    let outputURL: URL
    let catalogIdentifier: String

    var diagnosticEngine: DiagnosticEngine
    
    private var dataProvider: LocalFileSystemDataProvider!

    /// Initializes the action with the given validated options, creates or uses the given action workspace & context.
    public init(documentationCatalogURL: URL, outputURL: URL, catalogIdentifier: String, diagnosticEngine: DiagnosticEngine = .init()) throws
    {
        // Initialize the action context.
        self.rootURL = documentationCatalogURL
        self.outputURL = outputURL
        self.catalogIdentifier = catalogIdentifier

        self.diagnosticEngine = diagnosticEngine
        self.diagnosticEngine.add(DiagnosticConsoleWriter(formattingOptions: []))
    }
    
    @available(*, deprecated, renamed: "init(documentationCatalogURL:outputURL:catalogIdentifier:diagnosticEngine:)")
    public init(documentationBundleURL: URL, outputURL: URL, bundleIdentifier: String, diagnosticEngine: DiagnosticEngine = .init()) throws
    {
        self = try .init(documentationCatalogURL: documentationBundleURL, outputURL: outputURL, catalogIdentifier: bundleIdentifier, diagnosticEngine: diagnosticEngine)
    }
    
    /// Converts each eligable file from the source documentation catalog,
    /// saves the results in the given output alongside the template files.
    mutating public func perform(logHandle: LogHandle) throws -> ActionResult {
        let problems = try buildIndex()
        diagnosticEngine.emit(problems)
        
        return ActionResult(didEncounterError: !diagnosticEngine.problems.isEmpty, outputs: [outputURL])
    }
    
    mutating private func buildIndex() throws -> [Problem] {
        dataProvider = try LocalFileSystemDataProvider(rootURL: rootURL)
        let indexBuilder = NavigatorIndex.Builder(renderNodeProvider: FileSystemRenderNodeProvider(fileSystemProvider: dataProvider),
                                                  outputURL: outputURL,
                                                  catalogIdentifier: catalogIdentifier,
                                                  sortRootChildrenByName: true,
                                                  groupByLanguage: true)
        return indexBuilder.build()
    }
    
}
