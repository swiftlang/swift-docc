/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A semantic version-number triplet with major, minor, and patch components.
public struct VersionTriplet: Equatable, Comparable {
    /// Returns a Boolean value that indicates whether the first version is less than the second version.
    ///
    /// - Parameters:
    ///   - lhs: A version to compare.
    ///   - rhs: Another version to compare.
    public static func < (lhs: VersionTriplet, rhs: VersionTriplet) -> Bool {
        if lhs.major != rhs.major { return lhs.major < rhs.major }
        if lhs.minor != rhs.minor { return lhs.minor < rhs.minor }
        if lhs.patch != rhs.patch { return lhs.patch < rhs.patch }
        return false // The version are equal
    }
    
    /// The major component, for example, "1" in "1.2.3".
    let major: Int
    /// The minor component, for example, "2" in "1.2.3".
    let minor: Int
    /// The patch component, for example, "3" in "1.2.3".
    let patch: Int
    
    /// Creates a new version triplet with the given major, minor, and patch components.
    /// - Parameters:
    ///   - major: The major component.
    ///   - minor: The minor component.
    ///   - patch: The patch component.
    public init(_ major: Int, _ minor: Int, _ patch: Int) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }
}

/// A pair of a version number and beta information for a platform.
///
/// ## Topics
/// ### Semantic Versions
/// - ``VersionTriplet``
/// - ``Version``
public struct PlatformVersion: Equatable {
    /// The version number for the platform.
    public let version: VersionTriplet
    /// If `true`, this is a beta version.
    public let beta: Bool
    
    /// Creates a new version and beta pair for a platform.
    /// - Parameters:
    ///   - version: The version number for the platform.
    ///   - beta:  If the platform is considered in beta.
    public init(_ version: VersionTriplet, beta: Bool) {
        self.version = version
        self.beta = beta
    }
}

/// External metadata injected into the documentation compiler, for example via command line arguments.
public struct ExternalMetadata {
    /// The current version and beta information for platforms that may be encountered while processing symbol graph files.
    ///
    /// If the version that a symbol was introduced for a given platform (as indicated by the availability information in the symbol graph file) matches the
    /// current version for that platform (as indicated by this metadata) and the current version is in beta, then that symbol is also considered in beta.
    public var currentPlatforms: [String: PlatformVersion]?
    
    /// If `true`, inherited symbols retain their original docs.
    public var inheritDocs = false

    /// If `true`, there is no source bundle on disk and the inputs were passed via command line parameters.
    public var isGeneratedBundle = false
    
    /// The granularity of diagnostics to emit via the engine.
    ///
    /// > Note: This setting is set by the convert command.
    public var diagnosticLevel: DiagnosticSeverity = .warning
}
