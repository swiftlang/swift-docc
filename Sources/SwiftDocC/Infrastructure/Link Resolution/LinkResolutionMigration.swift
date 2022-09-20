/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A scope of configurations for how the documentation context should resolve links while migrating from one implementation to another.
///
/// If any reporting is enabled, the documentation context will setup both link resolver to compare them.
///
///> Note: This is a temporary configuration that will go away along with the ``DocumentationCacheBasedLinkResolver`` at some point in the future.
enum LinkResolutionMigrationConfiguration {
    
    // MARK: Configuration
    
    /// Whether or not the context should the a ``PathHierarchyBasedLinkResolver`` to resolve links.
    static var shouldUseHierarchyBasedLinkResolver: Bool = {
        return UserDefaults.standard.bool(forKey: "DocCUseHierarchyBasedLinkResolver")
            || ProcessInfo.processInfo.environment["DOCC_USE_HIERARCHY_BASED_LINK_RESOLVER"] == "YES"
    }()
    
    /// Whether or not the context should report differences between the disambiguated paths created by ``PathHierarchyBasedLinkResolver`` and ``DocumentationCacheBasedLinkResolver``.
    ///
    /// What mismatches can be reported depend on the value of ``shouldUseHierarchyBasedLinkResolver``:
    /// - When the cache based resolved is used to resolve links both mismatched symbol paths and mismatched link resolution reports will be reported.
    /// - When the path hierarchy based resolved is used to resolve links only mismatched symbol paths will be reported.
    static var shouldReportLinkResolutionMismatches: Bool = {
        return UserDefaults.standard.bool(forKey: "DocCReportLinkResolutionMismatches")
            || ProcessInfo.processInfo.environment["DOCC_REPORT_LINK_RESOLUTION_MISMATCHES"] == "YES"
    }()
    
    // MARK: Derived conditions
    
    /// Whether or not the context should set up a ``PathHierarchyBasedLinkResolver``.
    ///
    /// > Node: Check ``shouldUseHierarchyBasedLinkResolver`` to determine which implementation to use to resolve links.
    static var shouldSetUpHierarchyBasedLinkResolver: Bool {
        return shouldUseHierarchyBasedLinkResolver || shouldReportLinkResolutionMismatches
    }
    
    /// Whether or not to report mismatches in link resolution results between the two implementations.
    static var shouldReportLinkResolutionResultMismatches: Bool {
        return shouldReportLinkResolutionMismatches && !shouldUseHierarchyBasedLinkResolver
    }
    
    /// Whether or not to report mismatches in symbol path disambiguation between the two implementations.
    static var shouldReportLinkResolutionPathMismatches: Bool {
        return shouldReportLinkResolutionMismatches
    }
}

// MARK: Gathering mismatches

/// A type that gathers differences between the two link resolution implementations.
///
/// > Note: This is a temporary report that will go away along with the ``DocumentationCacheBasedLinkResolver`` at some point in the future.
final class LinkResolutionMismatches {
    /// Gathered resolved reference paths that have different disambiguation in the two implementations.
    var pathsWithMismatchedDisambiguation: [String: String] = [:]
    
    /// Gathered resolved reference paths that are missing from the path hierarchy-based implementation.
    var missingPathsInHierarchyBasedLinkResolver: [String] = []
    /// Gathered resolved reference paths that are missing from the documentation cache-based implementation.
    var missingPathsInCacheBasedLinkResolver: [String] = []
    
    /// Information about the inputs for a link that resolved in one implementation but not the other.
    struct FailedLinkInfo: Hashable {
        /// The path, and optional fragment, of the unresolved reference.
        let path: String
        /// The path, and optional fragment, of the parent reference that the link was resolved relative to.
        let parent: String
        /// Whether or not the link was resolved as a symbol link.
        let asSymbolLink: Bool
    }

    /// Links that resolved in the cache-based implementation but not the path hierarchy-based implementation
    var mismatchedLinksThatHierarchyBasedLinkResolverFailedToResolve: Synchronized<Set<FailedLinkInfo>> = .init([])
    
    /// Links that resolved in the path hierarchy-based implementation but not the cache-based implementation.
    var mismatchedLinksThatCacheBasedLinkResolverFailedToResolve: Synchronized<Set<FailedLinkInfo>> = .init([])
}

// MARK: Reporting mismatches

extension LinkResolutionMismatches {
    /// Prints the gathered mismatches
    ///
    /// > Note: If ``LinkResolutionMigrationConfiguration/shouldReportLinkResolutionPathMismatches`` is ``false`` this won't print anything.
    func reportGatheredMismatchesIfEnabled() {
        guard LinkResolutionMigrationConfiguration.shouldReportLinkResolutionPathMismatches else { return }
        let prefix = "[HierarchyBasedLinkResolutionDiff]"
        
        if pathsWithMismatchedDisambiguation.isEmpty {
            print("\(prefix) All symbol paths have the same disambiguation suffixes in both link resolver implementations.")
        } else {
            print("\(prefix) The following symbol paths have the different disambiguation across the two link resolver implementations:")
            let columnWidth = max(40, (pathsWithMismatchedDisambiguation.keys.map { $0.count } + ["path hierarchy implementation".count]).max()!)
            print("\("Path hierarchy implementation".padding(toLength: columnWidth, withPad: " ", startingAt: 0)) | Documentation cache implementation")
            print("\(String(repeating: "-", count: columnWidth))-+-\(String(repeating: "-", count: columnWidth))")
            for (hierarchyBasedPath, mainCacheBasedPath) in pathsWithMismatchedDisambiguation.sorted(by: \.key) {
                print("\(hierarchyBasedPath.padding(toLength: columnWidth, withPad: " ", startingAt: 0)) | \(mainCacheBasedPath)")
            }
        }
        
        if !missingPathsInHierarchyBasedLinkResolver.isEmpty {
            let missingPaths = missingPathsInHierarchyBasedLinkResolver.sorted()
            print("\(prefix) The following symbol paths exist in the cache-based link resolver but is missing in the path hierarchy-based link resolver:\n\(missingPaths.joined(separator: "\n"))")
        }
        if !missingPathsInCacheBasedLinkResolver.isEmpty {
            let missingPaths = missingPathsInCacheBasedLinkResolver.sorted()
            print("\(prefix) The following symbol paths exist in the path hierarchy-based link resolver but is missing in the cache-based link resolver:\n\(missingPaths.joined(separator: "\n"))")
        }
        
        guard !LinkResolutionMigrationConfiguration.shouldUseHierarchyBasedLinkResolver else {
            // Results can only be reported when the documentation cache based implementation is used to resolve links
            return
        }

        let mismatchedFailedCacheResults = mismatchedLinksThatCacheBasedLinkResolverFailedToResolve.sync({ $0 })
        let mismatchedFailedHierarchyResults = mismatchedLinksThatHierarchyBasedLinkResolverFailedToResolve.sync({ $0 })
        
        if mismatchedFailedCacheResults.isEmpty && mismatchedFailedHierarchyResults.isEmpty {
            print("\(prefix) Both link resolver implementations succeeded and failed to resolve the same links.")
        } else {
            if !mismatchedFailedCacheResults.isEmpty {
                print("\(prefix) The following links failed to resolve in the documentation cache implementation but succeeded in the path hierarchy implementation:")
                
                let firstColumnWidth = mismatchedFailedCacheResults.map { $0.path.count }.max()! + 2 // 2 extra for the quotes
                for result in mismatchedFailedCacheResults {
                    print("\(result.path.singleQuoted.padding(toLength: firstColumnWidth, withPad: " ", startingAt: 0))   relative to   \(result.parent.singleQuoted)   \(result.asSymbolLink ? "(symbol link)" : "")")
                }
            }
            
            if !mismatchedFailedHierarchyResults.isEmpty {
                print("\(prefix) The following links failed to resolve in the path hierarchy implementation but succeeded in the documentation cache implementation:")
                
                let firstColumnWidth = mismatchedFailedHierarchyResults.map { $0.path.count }.max()! + 2 // 2 extra for the quotes
                for result in mismatchedFailedHierarchyResults {
                    print("\(result.path.singleQuoted.padding(toLength: firstColumnWidth, withPad: " ", startingAt: 0))   relative to   \(result.parent.singleQuoted)   \(result.asSymbolLink ? "(symbol link)" : "")")
                }
            }
        }
    }
}
