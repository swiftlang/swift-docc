/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import SwiftDocC

extension ConvertAction {
    
    /// An index builder to be used when performing a ``ConvertAction``.
    ///
    /// Add render nodes to the navigation index by passing them to ``index(_:)``;
    /// finally call ``finalize()`` to write the index on disk.
    /// > Warning: Call ``finalize()`` at most once.
    /// > Note: The index is always created on disk in the given output folder.
    class Indexer {
        /// A list of problems encountered during indexing.
        private var problems = [Problem]()
        
        /// The count of nodes indexed.
        private var nodeCount = 0
        
        /// An index builder that creates the navigation index on disk.
        private var indexBuilder: Synchronized<NavigatorIndex.Builder>!
        
        /// Creates an indexer that asynchronously indexes nodes and creates the index file on disk.
        /// - Parameters:
        ///   - outputURL: The target directory to create the index file.
        ///   - bundleIdentifier: The identifier of the bundle being indexed.
        init(outputURL: URL, bundleIdentifier: String) throws {
            let indexURL = outputURL.appendingPathComponent("index", isDirectory: true)
            indexBuilder = Synchronized<NavigatorIndex.Builder>(
                NavigatorIndex.Builder(renderNodeProvider: nil,
                    outputURL: indexURL,
                    bundleIdentifier: bundleIdentifier,
                    sortRootChildrenByName: true,
                    groupByLanguage: true
                )
            )
            indexBuilder.sync({ $0.setup() })
        }

        /// Indexes the given render node and collects any encountered problems.
        /// - Parameter renderNode: A ``RenderNode`` value.
        func index(_ renderNode: RenderNode) {
            // Synchronously index the render node.
            indexBuilder.sync({
                do {
                    try $0.index(renderNode: renderNode)
                    nodeCount += 1
                } catch {
                    self.problems.append(error.problem(source: renderNode.identifier.url,
                                                  severity: .warning,
                                                  summaryPrefix: "RenderNode indexing process failed"))
                }
            })
        }
        
        /// Finalizes the index and writes it on disk.
        /// - Returns: Returns a list of problems if any were encountered during indexing.
        func finalize(emitJSON: Bool, emitLMDB: Bool) -> [Problem] {
            indexBuilder.sync { indexBuilder in
                indexBuilder.finalize(
                    estimatedCount: nodeCount,
                    emitJSONRepresentation: emitJSON,
                    emitLMDBRepresentation: emitLMDB
                )
            }
            return problems
        }
        
        /// Returns a string representation of the index hierarchy.
        func dumpTree() -> String? {
            return indexBuilder!.sync({ $0.navigatorIndex?.navigatorTree.root.dumpTree() })
        }
    }
}

fileprivate extension Error {
    
    /// Returns a problem from an `Error`.
    func problem(source: URL, severity: DiagnosticSeverity, summaryPrefix: String = "") -> Problem {
        let diagnostic = Diagnostic(source: source,
                                         severity: severity,
                                         range: nil,
                                         identifier: "org.swift.docc.index",
                                         summary: "\(summaryPrefix) \(localizedDescription)")
        return Problem(diagnostic: diagnostic, possibleSolutions: [])
    }
}
