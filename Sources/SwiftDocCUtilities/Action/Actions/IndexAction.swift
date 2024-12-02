/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import SwiftDocC

/// An action that creates an index of a documentation bundle.
public struct IndexAction: AsyncAction {
    let rootURL: URL
    let outputURL: URL
    let bundleIdentifier: String

    var diagnosticEngine: DiagnosticEngine

    /// Initializes the action with the given validated options, creates or uses the given action workspace & context.
    public init(documentationBundleURL: URL, outputURL: URL, bundleIdentifier: String, diagnosticEngine: DiagnosticEngine = .init()) throws {
        // Initialize the action context.
        self.rootURL = documentationBundleURL
        self.outputURL = outputURL
        self.bundleIdentifier = bundleIdentifier

        self.diagnosticEngine = diagnosticEngine
        self.diagnosticEngine.add(DiagnosticConsoleWriter(formattingOptions: [], baseURL: documentationBundleURL))
    }
    
    /// Converts each eligible file from the source documentation bundle,
    /// saves the results in the given output alongside the template files.
    public func perform(logHandle: inout LogHandle) async throws -> ActionResult {
        let problems = try buildIndex()
        diagnosticEngine.emit(problems)
        
        return ActionResult(didEncounterError: !diagnosticEngine.problems.isEmpty, outputs: [outputURL])
    }
    
    private func buildIndex() throws -> [Problem] {
        let renderNodeProvider = FileManagerRenderNodeProvider(fileManager: FileManager.default, startingPoint: rootURL)
        let indexBuilder = NavigatorIndex.Builder(renderNodeProvider: renderNodeProvider,
                                                  outputURL: outputURL,
                                                  bundleIdentifier: bundleIdentifier,
                                                  sortRootChildrenByName: true,
                                                  groupByLanguage: true)
        return indexBuilder.build()
    }
    
}
