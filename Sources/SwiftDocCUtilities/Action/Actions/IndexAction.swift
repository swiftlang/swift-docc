/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import SwiftDocC

/// An action that creates an index of a documentation bundle.
public struct IndexAction: Action {
    enum Error: DescribedError {
        case doesNotContainBundle(url: URL)
        var errorDescription: String {
            switch self {
            case .doesNotContainBundle(let url):
                return "The directory at '\(url)' and its subdirectories do not contain at least one valid documentation bundle. A documentation bundle is a directory ending in `.docc`."
            }
        }
    }

    let rootURL: URL
    let outputURL: URL
    let bundleIdentifier: String

    var diagnosticEngine: DiagnosticEngine
    
    private var dataProvider: LocalFileSystemDataProvider!

    /// Initializes the action with the given validated options, creates or uses the given action workspace & context.
    public init(documentationBundleURL: URL, outputURL:URL, bundleIdentifier: String, diagnosticEngine: DiagnosticEngine = .init()) throws
    {
        // Initialize the action context.
        self.rootURL = documentationBundleURL
        self.outputURL = outputURL
        self.bundleIdentifier = bundleIdentifier

        self.diagnosticEngine = diagnosticEngine
        self.diagnosticEngine.add(DiagnosticConsoleWriter(formattingOptions: []))
    }
    
    /// Converts each eligable file from the source documentation bundle,
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
                                                  bundleIdentifier: bundleIdentifier,
                                                  sortRootChildrenByName: true,
                                                  groupByLanguage: true)
        return indexBuilder.build()
    }
    
}
