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
    
    /// Whether or not the context should the a ``PathHierarchyBasedLinkResolver`` to resolve links.
    static var shouldUseHierarchyBasedLinkResolver: Bool = {
        return UserDefaults.standard.bool(forKey: "DocCUseHierarchyBasedLinkResolver")
            || ProcessInfo.processInfo.environment["DOCC_USE_HIERARCHY_BASED_LINK_RESOLVER"] == "YES"
    }()
    
    /// Whether or not the context should set up a ``PathHierarchyBasedLinkResolver``.
    ///
    /// > Node: Check ``shouldUseHierarchyBasedLinkResolver`` to determine which implementation to use to resolve links.
    static var shouldSetUpHierarchyBasedLinkResolver: Bool {
        return shouldUseHierarchyBasedLinkResolver || isReportingEnabled
    }
    
    /// Whether or not the context should fully set up a ``DocumentationCacheBasedLinkResolver``.
    ///
    /// > Node: Check ``shouldUseHierarchyBasedLinkResolver`` to determine which implementation to use to resolve links.
    static var shouldFullySetUpCacheBasedLinkResolver: Bool {
        return !shouldUseHierarchyBasedLinkResolver || isReportingEnabled
    }
    
    /// Whether or not the context should report differences between the disambiguated paths created by ``PathHierarchyBasedLinkResolver`` and ``DocumentationCacheBasedLinkResolver``.
    static var shouldReportLinkResolutionPathMismatches: Bool = {
        return UserDefaults.standard.bool(forKey: "DocCReportLinkResolutionPathMismatches")
            || ProcessInfo.processInfo.environment["DOCC_REPORT_LINK_RESOLUTION_PATH_MISMATCHES"] == "YES"
    }()
    
    /// Whether or not the context should report links that failed to resolve using a ``PathHierarchyBasedLinkResolver`` but does resolve using a ``DocumentationCacheBasedLinkResolver``.
    static var shouldReportLinkResolutionResultMismatches: Bool = {
        return UserDefaults.standard.bool(forKey: "DocCReportLinkResolutionResultMismatches")
            || ProcessInfo.processInfo.environment["DOCC_REPORT_LINK_RESOLUTION_RESULT_MISMATCHES"] == "YES"
    }()
    
    private static var isReportingEnabled: Bool {
        return shouldReportLinkResolutionPathMismatches
            || shouldReportLinkResolutionResultMismatches
    }
}

/// A type that gathers differences between the two link resolution implementations.
///
/// > Note: This is a temporary report that will go away along with the ``DocumentationCacheBasedLinkResolver`` at some point in the future.
final class LinkResolutionMismatches {
    /// Gathered resolved reference paths that have different disambiguation in the two implementations.
    var pathsWithMismatchedDisambiguation: [String: String] = [:]
    
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
    var mismatchedLinksThatHierarchyBasedLinkResolverFailedToResolve = Set<FailedLinkInfo>()
    
    /// Links that resolved in the path hierarchy-based implementation but not the cache-based implementation.
    var mismatchedLinksThatCacheBasedLinkResolverFailedToResolve = Set<FailedLinkInfo>()
}
