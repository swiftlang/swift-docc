/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

/// A semantic version.
///
/// A version that follows the [Semantic Versioning](https://semver.org) specification.
public struct SemanticVersion: Codable, Equatable, Comparable, CustomStringConvertible {

    /// The major version number.
    ///
    /// For example, the `1` in `1.2.3`
    public var major: Int
    
    /// The minor version number.
    ///
    /// For example, the `2` in `1.2.3`
    public var minor: Int
    
    /// The patch version number.
    ///
    /// For example, the `3` in `1.2.3`
    public var patch: Int

    /// The optional prerelease version component, which may contain non-numeric characters.
    ///
    /// For example, the `4` in `1.2.3-4`.
    public var prerelease: String?

    /// Optional build metadata.
    public var buildMetadata: String?

    public init(major: Int, minor: Int, patch: Int, prerelease: String? = nil, buildMetadata: String? = nil) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.major = try container.decode(Int.self, forKey: .major)
        self.minor = try container.decodeIfPresent(Int.self, forKey: .minor) ?? 0
        self.patch = try container.decodeIfPresent(Int.self, forKey: .patch) ?? 0
        self.prerelease = try container.decodeIfPresent(String.self, forKey: .prerelease)
        self.buildMetadata = try container.decodeIfPresent(String.self, forKey: .buildMetadata)
    }

    // TODO: https://github.com/swiftlang/swift-docc/issues/970
    // Migrate all the code to use semantic versions, and not version triplets.
    /// Create a semantic version from a version triplet.
    init(versionTriplet: VersionTriplet) {
        self.major = versionTriplet.major
        self.minor = versionTriplet.minor
        self.patch = versionTriplet.patch
    }

    /// Compare one semantic version with another.
    ///
    /// - Parameters:
    ///   - lhs: A version to compare.
    ///   - rhs: Another version to compare.
    ///
    /// - Returns: a Boolean value that indicates whether the first version is less than the second version.
    public static func < (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        if lhs.major != rhs.major { return lhs.major < rhs.major }
        if lhs.minor != rhs.minor { return lhs.minor < rhs.minor }
        if lhs.patch != rhs.patch { return lhs.patch < rhs.patch }
        // Note: don't compare the values of prerelease, even if it is
        // present in both semantic versions.
        return false // The version are equal
    }

    public var description: String {
        var result = "\(major).\(minor).\(patch)"
        if let prerelease {
            result += "-\(prerelease)"
        }
        if let buildMetadata {
            result += "+\(buildMetadata)"
        }
        return result
    }
}

// Diffable conformance
extension SemanticVersion: RenderJSONDiffable {
    /// Returns the differences between this SemanticVersion and the given one.
    func difference(from other: SemanticVersion, at path: CodablePath) -> JSONPatchDifferences {
        var diffBuilder = DifferenceBuilder(current: self, other: other, basePath: path)

        diffBuilder.addDifferences(atKeyPath: \.major, forKey: CodingKeys.major)
        diffBuilder.addDifferences(atKeyPath: \.minor, forKey: CodingKeys.minor)
        diffBuilder.addDifferences(atKeyPath: \.patch, forKey: CodingKeys.patch)

        return diffBuilder.differences
    }
}
